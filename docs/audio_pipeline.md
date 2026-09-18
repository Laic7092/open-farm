# 音频资源规范

> 仓库里的每个采样点都必须能由 `tools/audio/*.gd` 重新合成；手工放进来的 WAV / MP3 / OGG 一律违规。
> 与 [美术资源规范](art_pipeline.md) 同源：那边管像素，这边管波形。

## 1. 目录与职责

| 路径 | 职责 |
| --- | --- |
| `src/audio/audio_catalog.gd` | 全部音频 id 与路径（生成器与运行时共用的事实来源） |
| `src/audio/scene_audio.gd` | 场景音频节点（标题页 / Main 各挂一个，见 §4） |
| `tools/audio/synth.gd` | 合成基座：波形 / 包络 / 噪声 / 滑音 / 鼓组 / WAV 写出 |
| `tools/audio/generate_sfx.gd` | 音效配方（UI、农活、经济、动物、钓鱼、存档、脚步、系统） |
| `tools/audio/generate_bgm.gd` | BGM 配方（标题 / 农场 / 小镇 / 夜晚 / 钓鱼） |
| `assets/audio/{sfx,bgm}/*.wav` | 生成物（提交进仓库） |
| `tests/unit/test_audio.gd` | 规范的可执行版本 |

运行时**只认 `AudioCatalog` 的 id**，生成器按同一批 id 写文件，「改了文件名却忘了改播放代码」在结构上不可能发生。

## 2. 硬性规则

### 2.1 格式统一：22050 Hz / 16 bit / 单声道 PCM

常量只在 `AudioCatalog.SAMPLE_RATE` 与 `Synth.SR` 各写一次，测试把落盘结果与它对齐。

### 2.2 声音只能来自 `tools/audio/synth.gd` 的原语

生成器里不允许直接拼 PCM 字节，只能用 `Synth` 的
`tone` / `sweep` / `noise_burst` / `kick` / `snare` / `hat` / `melody` / `chord_sequence` / `arpeggio`。
新音色先在基座里加一个有名字的原语，而不是在某个音效函数里手搓循环。

### 2.3 生成必须确定性：噪声用位置哈希，不用 `RandomNumberGenerator`

```gdscript
# ❌ if rng.randf() < 0.2: ...
# ✅ Synth.noise_at(index, salt)
```

判据同美术：**连跑两次 `./tools/build_assets.sh`，`git status` 必须干净。**

### 2.4 BGM 写循环块，音效不写

BGM 的 WAV 带标准 `smpl` 循环块，Godot 导入按「从 WAV 检测循环」处理，运行时不额外配置即可无缝循环；音效不带，避免误循环。
渲染时多留一段尾巴并**绕回开头**截成正好一整圈，接缝处做极短淡化——首尾相接听不出断点。

### 2.5 生成物提交，永不手改

同美术：WAV 与 `.import` 都提交，供 CI 与玩家直接用；改动走生成器后重跑 `build_assets.sh`。

## 3. 怎么跑

```bash
./tools/build_assets.sh          # 全部重跑（含音频；每条命令都有 60s 超时）
```

单跑一个生成器（例：只调一首曲子）：

```bash
timeout 60 ./godot --headless --path . --quit-after 3 -s res://tools/audio/generate_bgm.gd
timeout 60 ./godot --headless --path . --import
```

新增音频：`AudioCatalog` 加 id → 对应生成器写配方 → 重跑 `build_assets.sh` → 需要时在场景的 `SceneAudio` 接事件。

## 4. 运行时接线

音频没有全局 Autoload：每个需要声音的场景挂一个 `SceneAudio`，在 `.tscn` 里用导出字段声明自己听起来是什么样。

| 场景 | 声明 |
| --- | --- |
| 标题页 `title_screen.tscn` | `bgm_track = "title"`、`autoplay_bgm`、`listen_ui_sfx` |
| 主场景 `main.tscn` | `follow_world_bgm`、`listen_ui_sfx`、`listen_gameplay_sfx`、`drive_footsteps` |

`SceneAudio` 只负责播放（BGM 交叉淡入淡出、音效声部池、脚步、`Master → BGM / SFX` 两条总线、`user://audio_settings.cfg`），
不写死「哪个世界放哪首」，而是读当前 `WorldScene` 的导出字段：

| `WorldScene` 字段 | 作用 |
| --- | --- |
| `bgm_track` | 白天放什么 |
| `bgm_night_track` | 夜里放什么（18:00 ~ 次日 06:00，与 `DayNight` 同一定义） |
| `footstep_sfx` | 脚步音（草地 / 石板） |

于是「加一张地图」= 场景里填字段，音频代码零改动。进 / 出地图由 `EventBus.world_entered` 触发切曲，脚步按玩家走过的距离触发。
玩法 / UI 只发既有事件（翻地、浇水、收获、买卖、对话、存读档、`ui_sound_requested`……），由所在场景的 `SceneAudio` 订阅；
同一动作的「专属音效」后，紧跟的通用提示音在 140ms 内被抑制，避免「收一次菜响两声」。
音量滑杆由 `UiRoot.bind_audio()` 把主场景的 `SceneAudio` 交给 `PauseMenu`，只改 `BGM` / `SFX` 总线音量并写回设置文件。

### 4.1 临时接管 BGM（钓鱼）

钓鱼需要一段专属曲目（`BGM_FISHING`），但它不是地图属性，所以 `SceneAudio` 提供
`push_bgm_override(track_id)` / `pop_bgm_override()` 一对接口：抛竿（`fish_cast`）时接管，
一次垂钓结束（`fish_ended`）时还原世界声明的曲目。接管期间 `_refresh_world_bgm()` 会直接返回，
于是小时变化 / 进图不会把钓鱼曲抢回去。拉扯中的收线节拍（`fish_reel_tick`）反复触发 `fish_reel`，
断线（`NOTIFY_FISH_ESCAPED`）单独走 `fish_line_break`。

## 5. 规范如何被强制

`tests/unit/test_audio.gd` 把规则变成断言（`./tools/check.sh` 执行）：每个 id 都有 WAV；WAV 是 22050 Hz / 16 bit / 单声道 PCM
（直接解析文件头）；BGM 带 `smpl` 循环块、音效不带且导出流确实循环；音效 ≤ 1.2 秒；`BGM` / `SFX` 总线存在且滑杆真的改到总线上。
`tools/smoke_test.tscn` 再确认「进农场换农场曲、进小镇换小镇曲、音量可调、播放不报错」。

