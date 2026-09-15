# 音频资源规范：和美术一样，由脚本合成

> 一句话规则：**仓库里的每一个采样点都必须能由 `tools/audio/*.gd` 重新合成。**
> 手工放进来的 WAV / MP3 / OGG，一律视为违规。

这是 [美术资源规范](art_pipeline.md) 的姊妹篇。美术解决"像素从哪来"，这里解决"声音从哪来"：
在没有作曲、没有音源库的骨架阶段，用代码把 BGM 与音效**合成**出来。

---

## 1. 为什么

| | 手工音频 | 脚本合成 |
| --- | --- | --- |
| 改动成本 | 打开 DAW，重新导出，可能覆盖错文件 | 改一个音符 / 音色常量，重跑生成器 |
| 可审查性 | 二进制，git diff 只能看到"文件变了" | 代码 diff 就是听感 diff |
| 可复现性 | 依赖某个人手里的工程文件 | 任何人 clone 后跑一次得到逐采样相同的 WAV |
| 一致性 | 每段声音各做各的，音量靠耳朵 | 格式、响度、音色全部集中在 `tools/audio/synth.gd` |

和美术的取舍完全一样：**把素材变成可维护的工程资产**。
区别只在于"像素"换成了"波形"。

---

## 2. 目录与职责

```
src/audio/
└── audio_catalog.gd            ← 全部音频 id 与路径（生成器与运行时共用的事实来源）

tools/audio/
├── synth.gd                    ← 合成基座：波形 / 包络 / 噪声 / 滑音 / 鼓组 / WAV 写出
├── generate_sfx.gd             ← 26 个音效（UI、农活、经济、动物、存档、脚步、系统）
└── generate_bgm.gd             ← 4 首 BGM（标题 / 农场 / 小镇 / 夜晚）

src/audio/scene_audio.gd        ← 场景音频节点（标题页 / Main 各挂一个，见 §5）
assets/audio/sfx/*.wav          ← 生成物（提交进仓库）
assets/audio/bgm/*.wav          ← 生成物（提交进仓库）
tests/unit/test_audio.gd        ← 规范的可执行版本
```

运行时**只认 `AudioCatalog` 里的 id**，生成器也按同一批 id 写文件，
所以"改了文件名却忘了改播放代码"在结构上不可能发生。

---

## 3. 硬性规则

### 3.1 格式统一：22050 Hz / 16 bit / 单声道 PCM

采样率够做芯片音色，体积又足够小；单声道省一半空间，也符合复古气质。
常量只在 `AudioCatalog.SAMPLE_RATE` 与 `Synth.SR` 各写一次，
测试会把落盘结果和它对齐。

### 3.2 声音只能来自 `tools/audio/synth.gd` 的原语

生成器里不允许直接拼 PCM 字节，只能用 `Synth` 提供的
`tone` / `sweep` / `noise_burst` / `kick` / `snare` / `hat` / `melody` / `chord_sequence` / `arpeggio`。
需要新音色时先在基座里加一个有名字的原语，而不是在某个音效函数里手搓循环。

### 3.3 生成必须确定性：噪声用位置哈希，不用 `RandomNumberGenerator`

```gdscript
# ❌ 每次重跑都得到不同的噪声，git 里全是无意义的二进制 diff
if rng.randf() < 0.2: ...

# ✅ 同样的采样位置永远得到同样的值
Synth.noise_at(index, salt)
```

判断标准同样是：**连跑两次 `./tools/build_assets.sh`，`git status` 必须是干净的。**

### 3.4 BGM 写循环块，音效不写

BGM 的 WAV 带一个标准 `smpl` 循环块，Godot 导入时按"从 WAV 检测循环"处理，
运行时不额外配置就能无缝循环；音效则不带，避免误循环。
曲子在渲染时会多留一段尾巴，然后把尾巴**绕回开头**再截成正好一整圈，
接缝处再做极短的淡化——所以首尾相接听不出断点。

### 3.5 生成物提交，脚本是唯一来源

规则与美术一致（见 [art_pipeline.md §3.5](art_pipeline.md#35-生成物提交脚本是唯一来源)）：
生成出来的 WAV 与 `.import` 都提交进仓库，供 CI 与玩家直接使用，但**永不手改**。

---

## 4. 怎么跑

```bash
./tools/build_assets.sh          # 全部重跑（含音频；每条命令都有 60s 超时，不会卡住）
```

单独跑某一个生成器也可以（例如只调了一首曲子）：

```bash
timeout 60 ./godot --headless --path . --quit-after 3 -s res://tools/audio/generate_bgm.gd
timeout 60 ./godot --headless --path . --import
```

> **加了新音频怎么办？** 在 `AudioCatalog` 里加 id → 在对应生成器里写配方 →
> 重跑 `build_assets.sh` → 需要时在场景里的 `SceneAudio` 接一个事件。

---

## 5. 运行时怎么响

音频没有全局 Autoload：**每个需要声音的场景挂一个 `SceneAudio` 节点**
（`src/audio/scene_audio.gd`），在 `.tscn` 里用导出字段声明自己听起来是什么样。

| 场景 | 节点 | 声明 |
| --- | --- | --- |
| 标题页 | `scenes/title/title_screen.tscn` 的 `SceneAudio` | `bgm_track = "title"`、`autoplay_bgm`、`listen_ui_sfx` |
| 游戏主场景 | `scenes/main/main.tscn` 的 `SceneAudio` | `follow_world_bgm`、`listen_ui_sfx`、`listen_gameplay_sfx`、`drive_footsteps` |

`SceneAudio` 只负责播放：BGM 交叉淡入淡出、音效声部池、脚步、两条总线
（`Master → BGM / SFX`）与 `user://audio_settings.cfg`。它不写死"哪个世界放哪首"，
而是读当前 `WorldScene` 的导出字段：

| `WorldScene` 字段 | 作用 |
| --- | --- |
| `bgm_track` | 这张地图白天放什么 |
| `bgm_night_track` | 夜里放什么（18:00 ~ 次日 06:00，与 `DayNight` 同一份定义） |
| `footstep_sfx` | 这张地图的脚步音（草地 / 石板） |

于是"加一张地图"= 在场景里填字段，音频代码一行不用改；进 / 出地图由
`EventBus.world_entered` 触发切曲，脚步按"玩家走过的距离"触发，都不侵入移动状态机。
玩法 / UI 代码照旧只发既有事件（翻地、浇水、收获、买卖、对话、存读档、
`ui_sound_requested`……），由所在场景的 `SceneAudio` 订阅：标题页订阅 UI 音效，
主场景订阅玩法 + UI + 存读档 + 场景过渡。同一个动作触发的"专属音效"之后，
紧跟的通用提示音会在 140ms 内被抑制，避免"收一次菜响两声"。

> 音量滑杆：`PauseMenu` 由 `UiRoot.bind_audio()` 拿到主场景的 `SceneAudio`，
> 只改 `BGM` / `SFX` 总线音量，并写回 `user://audio_settings.cfg`。

---

## 6. 修改与扩展音频

音频同样由脚本合成，调整听感 = 改代码后重跑：

1. 新音色先在 `tools/audio/synth.gd` 里加一个有名字的原语。
2. 在 `tools/audio/generate_sfx.gd` / `generate_bgm.gd` 里写配方；
   新音频的 id 与路径加到 `src/audio/audio_catalog.gd`。
3. 跑 `./tools/build_assets.sh`，再跑 `./tools/check.sh`。

生成物（WAV / `.import`）会被重新覆盖，**不要手改**。
因为运行时只认 `AudioCatalog` 的 id 与路径，这些改动都不会波及玩法代码。

---

## 7. 规范如何被强制

`tests/unit/test_audio.gd` 把上面的规则变成断言：

- 目录里声明的每个 id 都有对应 WAV；
- WAV 真的是 22050 Hz / 16 bit / 单声道 PCM（直接解析文件头，不依赖导入）；
- BGM 带 `smpl` 循环块、音效不带；导出的 BGM 流确实处于循环状态；
- 音效长度不超过 1.2 秒；
- 运行时 `BGM` / `SFX` 总线存在，音量滑杆真的改到总线上。

`tools/smoke_test.gd` 还会在真的跑起来之后确认
"进农场换农场曲、进小镇换小镇曲、音量可调、播放不报错"。
漏生成、改错格式、忘了接线都会在测试阶段变红。
