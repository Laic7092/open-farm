# 大文件规范（怎么读 / 怎么改）

> 仓库里有若干数百到上千行的文件，整读既吃上下文，也容易在局部改动时漏掉共享契约。
> 三句核心：400 行以上先看结构、不整读；改共享函数前先查调用方；生成物只改生成器。
> 阈值可执行：`python3 tools/outline.py lint`。

## 1. 阈值

| 对象 | 黄线：先看结构 | 红线：禁止整读 |
| --- | --- | --- |
| 文件 | ≥ 400 行 | ≥ 800 行 |
| 函数 | ≥ 80 行 | ≥ 120 行 |
| 顶部 `##` 说明 | ≥ 200 行的 .gd 必须有 | — |

统计范围是自研代码 `tools/ src/ tests/ scenes/ data/`；
`addons/`、`.godot/`、`reports/`、`target/`、`assets/` 豁免（第三方 / 生成物）。

## 2. 怎么读：定位 → 结构 → 局部

| 想干什么 | 用什么 |
| --- | --- |
| 不知道改哪个文件 | `map`（行数 + 用途总表）、`grep`（关键词） |
| 知道文件但不想整读 | `outline`（用途 / 段 / 常量 / 函数签名 + 行号） |
| 只看一个函数 | `sym FILE NAME`（名字支持正则） |
| 只找一个字符串 | `grep PATTERN PATH`（带行号，不整读） |
| 想知道谁调用谁 | `refs FILE NAME`（本文件）、`callers NAME`（跨文件） |
| 场景 / 资源文件 | `outline scenes/world/twon.tscn` → 节点树 + 挂的脚本 |

所有子命令默认精简（`outline` 只列入口函数 + 大函数，场景只列根 + 直接子节点，`map` 只列最大的 25 个）；
展开用 `--full`，也可 `outline --funcs all|none`、`--nodes all`、`--doc N`。

```bash
python3 tools/outline.py map                          # 全仓索引：行数 + 用途
python3 tools/outline.py outline tools/smoke_test.gd  # 用途 / 段 / 常量 / 函数签名与行号
python3 tools/outline.py sym tools/smoke_test.gd _check_twon    # 只取这一个函数体
python3 tools/outline.py refs tools/smoke_test.gd _check_mine   # 本文件内：谁调用它 / 它调用谁
python3 tools/outline.py callers clear src/ tools/ tests/       # 跨文件：谁调用了它（改共享函数前必查）
python3 tools/outline.py grep register_day_hook src/            # 带行号搜，不用整读
python3 tools/outline.py lint                         # 大文件体检（--strict 有红线时非 0）
```

阅读升级规则：

- `outline` 的用途 + 段名 + 函数签名够判断 → 停在这里。
- 要看控制流 / 数据流 → `sym` 取那一个函数；≥120 行的函数是红线，先想清楚为什么非读不可。
- `refs` / `callers` 指出调用点落在某个大函数里 → 只 `sym` 那个大函数，不要升级到整文件。
- 只有「文件级契约不明」时才考虑整读；这时先补 `refs` + `grep`，通常就够了。

## 3. 怎么改：动手前 3 问，动手后 2 步

动手前：

1. **它在哪个调度里？** 用 `refs FILE NAME` 找调用者。
   例：`_check_mine` 的调用者是 `_process`（相位机），不是 `_run_checks`——放错地方 = 检查永远不跑。
2. **谁是调用方？** 改共享函数（`clear` / `from_dict` / `use_tool` 这类）先跑 `callers` + `grep`，
   只看一个文件必漏；改完再扫一遍 `src/ tools/ tests/`。
3. **有没有隐性契约？**
   - 生成物：`assets/**`、`data/**/*.tres`、`.import` → 改生成器后重跑 `build_assets.sh`。
   - 存档：`to_dict/from_dict` 加字段要给旧档兜底（缺 key 用默认值）；核心系统要在 `Main._bind_dependencies()` 注册 `SaveSection`。
   - 场景：`scenes/**/*.tscn` 改完用 `outline` 复查节点树与 `parent` 路径。
   - 文案：新增汉字必须重跑 `build_assets.sh`，否则像素字体缺字。

动手后：

1. 跑对应测试：规则 / 数据 → `./tools/check.sh unit`；交互 / 场景 → `./tools/check.sh smoke`；全量 → `./tools/check.sh`。
2. 契约变了 → 再跑一次 `callers` / `grep`，确认没有遗漏调用方。

## 4. 需要特别注意的文件

| 文件 | 为什么特别注意 | 读 / 改姿势 |
| --- | --- | --- |
| `tools/smoke_test.gd` + `tools/smoke/` | 根脚本只留生命周期与相位机，域检查器继承 `smoke_base.gd`；状态由 `share_state_from()` 分发，断言计数共用一个 `Report` | 加检查项：农场 → 根 `_run_checks()`；别的图 → 对应相位；公共工具加在 `smoke_base.gd`，别新建域间调用 |
| `tools/generate_sample_data.gd` + `tools/sample/` | 入口只按依赖顺序调用各域 `build()`；它生成 `data/**/*.tres`，手改会被下次重跑覆盖 | 改数据 = 改对应的 `tools/sample/build_*.gd`，再重跑；公共写盘工具在 `sample_base.gd` |
| `src/world/flora_field.gd` | 状态权威 + 存档 + 被 `FarmInteractor` / 冒烟测试 / 生成器调用 | 改 `clear()` 之类共享方法前 `callers` + `grep` |
| `src/autoload/database.gd` | 每个数据域要动 10+ 处样板（dir 常量 / 字典 / get / has / require / total / validate_all / reload） | 加数据域时按现有域逐项对齐，别漏 `validate_all` |
| `src/audio/scene_audio.gd` | 场景音频节点：靠导出字段决定订阅哪些事件 / 跟不跟世界曲目 | 改字段前先看 `scenes/main/main.tscn` 与 `scenes/title/title_screen.tscn` 的接线 |
| `scenes/world/twon.tscn` `scenes/world/farm.tscn` | 节点树 + `parent` 路径，手改易错位 | 先用 `outline` 看层级；改完再 `outline` 复查 |
| `tests/unit/test_assets.gd` | 美术 / 音频规范的可执行版本 | 改生成器或规范时同步改它 |
| `reports/**` | 自动生成的测试报告（几百个 HTML），体积噪声 | 已在 `.gitignore`；不要读、不要提交，看控制台或 `.tmp/` 日志就够 |
| `tools/outline.py` | 规范工具本身，也在变大 | 它超过 800 行那天就按 `parse / render / cli` 拆开 |

## 5. 别制造新的大文件

- 新文件顶部写 `##` 说明（`outline` / `map` 的唯一「用途」来源）。
- 单个函数 ≤ 80 行；超了就抽子函数或抽到纯静态规则类（`XxxRules` / `XxxGrowth`）。
- 入口型大文件在顶部 `##` 里写「调度地图」：谁调用我、子步骤挂在哪。例：`smoke_test.gd` 第一屏就能看到
  「农场检查在 `_run_checks()`，跨图巡游在 `_process()` 相位机」。
- 出现以下信号就拆分：
  - 文件里已有 3 个以上 `# ---- 分节`；
  - 打开文件要滚动才能找到目标函数；
  - 同一个文件因为两件不相关的事被改（如「矿洞视觉」和「存档格式」）。
- 拆法优先按域：规则（纯静态）/ 状态（`RefCounted`）/ 视图（`Node`）/ 数据（`Resource`）；
  保留原 `class_name` 与公开 API 转发，避免一次性大重构。

## 6. 豁免与例外

- 第三方（`addons/**`）与生成物（`assets/**`、`reports/**`、`.godot/**`、`target/**`）不适用本文。
- 确实需要突破阈值时（例如生成器天然是一个大 `_build_*` 序列）：
  1. 顶部 `##` 里写清「为什么大 + 怎么安全阅读」；
  2. 给关键函数补 `##` 说明，让 `outline` 输出自带导航；
  3. 在 PR / 提交信息里说明不拆的理由。

## 7. 让规范生效

- `./tools/check.sh` 会跑一次 `lint`（不阻断，缺 python3 时自动跳过）。
- CI 想硬性拦截时用 `python3 tools/outline.py lint --strict`（有红线文件 / 红线函数才非 0）。

