# 大文件规范（怎么读 / 怎么改）

> 面向 Agent 与人类。仓库里有若干 400~1300 行的文件，整读既吃上下文，也容易在局部改动时
> 漏掉共享契约。本文定义阈值、阅读协议、修改协议与目录分级；`AGENTS.md` 只保留铁律并指向这里。
>
> 阈值是可执行的：`python3 tools/outline.py lint`。

## 0. 三句话

1. 400 行以上不整读：先 `map` 定位、`outline` 看结构、`sym` 取函数。
2. 改共享函数前先查调用方：`refs`（本文件内）/ `callers`（跨文件）。
3. 生成物只改生成器：`data/**/*.tres`、`assets/**`、`.import` 都不手改。

## 1. 阈值

| 对象 | 黄线：先看结构 | 红线：禁止整读 |
| --- | --- | --- |
| 文件 | ≥ 400 行 | ≥ 800 行 |
| 函数 | ≥ 80 行 | ≥ 120 行 |
| 顶部 `##` 说明 | ≥ 200 行的 .gd 必须有 | — |

统计范围是自研代码：`tools/`、`src/`、`tests/`、`scenes/`、`data/`。
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

所有子命令**默认精简**（`outline` 只列入口函数 + 大函数、场景只列根 + 直接子节点，`map` 只列最大的 25 个）。要展开用 `--full`，也可单独控制：`outline --funcs all|none`、`--nodes all`、`--doc N`。

阅读升级规则（什么时候才允许读得更多）：

- `outline` 的用途 + 段名 + 函数签名已经够判断 → 停在这里。
- 要看控制流 / 数据流 → `sym` 取那一个函数；≥120 行的函数是红线，先想清楚为什么非读不可。
- `refs` / `callers` 指出调用点落在某个大函数里 → 只 `sym` 那个大函数，不要升级到整文件。
- 只有"文件级契约不明"时才考虑整读；这时先补 `refs` + `grep`，通常就够了。

## 3. 怎么改：动手前 3 问，动手后 2 步

动手前：

1. **它在哪个调度里？** 用 `refs FILE NAME` 找调用者。
   例：`_check_mine` 的调用者是 `_process`（相位机），不是 `_run_checks`——放错地方 = 检查永远不跑。
2. **谁是调用方？** 改共享函数（`clear` / `from_dict` / `use_tool` 这类）先跑 `callers` + `grep`，
   只看一个文件必漏；改完再扫一遍 `src/ tools/ tests/`。
3. **有没有隐性契约？**
   - 生成物：`assets/**`、`data/**/*.tres`、`.import` → 改生成器（`tools/art|audio|generate_*`）后重跑 `build_assets.sh`。
   - 存档：`to_dict/from_dict` 加字段要给旧档兜底（缺 key 用默认值）；核心系统还要在 `Main._bind_dependencies()` 注册 `SaveSection`。
   - 场景：`scenes/**/*.tscn` 改完用 `outline` 复查节点树与 `parent` 路径。
   - 文案：新增汉字必须重跑 `build_assets.sh`，否则像素字体缺字。

动手后：

1. 跑对应测试：规则 / 数据 → `./tools/check.sh unit`；交互 / 场景 → `./tools/check.sh smoke`；全量 → `./tools/check.sh`。
2. 契约变了 → 再跑一次 `callers` / `grep`，确认没有遗漏调用方。

## 4. 目录分级

| 区域 | 分级 | 说明 |
| --- | --- | --- |
| `tools/` | 黄 | 生成器 + 冒烟测试；已按本规范拆分：`tools/smoke/`（基座 + 4 个域检查器）、`tools/sample/`（基座 + 13 个域构建器），两个根脚本都 <160 行 |
| `src/world/` | 黄 | `flora_field.gd` 600 行：格子状态权威 + 存档对象 + 共享 `clear()` |
| `src/farm/` | 黄 | `farm_grid.gd` 514、`livestock_manager.gd` 339 |
| `src/npc/` | 黄 | `npc.gd` 582：日程 / 寻路 / 交互混在一起 |
| `src/autoload/` | 黄 | `audio_manager.gd` 476、`database.gd` 412；Autoload 在 `-s` 脚本里不可用 |
| `src/player/` | 黄 | `player.gd` 473 |
| `tests/unit/` | 绿偏黄 | 普遍 < 300 行；`test_assets.gd` 402 行是"文档 ↔ 测试"同步点，改美术规范必改它 |
| `scenes/world/` | 黄 | `twon.tscn` 552、`farm.tscn` 399：节点树，用 `outline` 看 |
| `src/core/` `src/services/` `src/data/` `src/events/` | 绿 | 普遍 < 300 行，可正常阅读 |
| `addons/gdUnit4/**` | 豁免 | 第三方，别读别改 |
| `reports/**` `target/**` `.godot/**` `assets/**` | 豁免 | 生成物 |

当前快照（由 `lint` 生成，会随代码变化）：

- 红线（≥800 行）：无。拆分后最大的自研文件是 `tools/art/generate_houses.gd` 754 行。
- 黄线（400~799 行）：13 个，集中在 `tools/art/generate_*.gd`、`src/world/flora_field.gd`、`src/npc/npc.gd`、`src/farm/farm_grid.gd`、`src/autoload/*`、`src/player/player.gd`、`tests/unit/test_assets.gd`、`tools/outline.py`；跑 `python3 tools/outline.py lint` 看当前名单。

## 5. 需要特别注意的文件

| 文件 | 为什么特别注意 | 读 / 改姿势 |
| --- | --- | --- |
| `tools/smoke_test.gd` + `tools/smoke/` | 根脚本只留生命周期与相位机（151 行），域检查器继承 `smoke_base.gd`；状态由 `share_state_from()` 分发，断言计数共用一个 `Report` | 加检查项：农场 → 根 `_run_checks()`；别的图 → 对应相位；公共工具加在 `smoke_base.gd`，别新建域间调用 |
| `tools/generate_sample_data.gd` + `tools/sample/` | 入口只按依赖顺序调用各域 `build()`（48 行）；它生成 `data/**/*.tres`，手改会被下次重跑覆盖 | 改数据 = 改对应的 `tools/sample/build_*.gd`，再重跑；公共写盘工具在 `sample_base.gd` |
| `src/world/flora_field.gd` | 状态权威 + 存档 + 被 `FarmInteractor` / 冒烟测试 / 生成器调用 | 改 `clear()` 之类共享方法前 `callers` + `grep` |
| `src/autoload/database.gd` | 每个数据域要动 10+ 处样板（dir 常量 / 字典 / get / has / require / total / validate_all / reload） | 加数据域时按现有域逐项对齐，别漏 `validate_all` |
| `src/autoload/audio_manager.gd` | Autoload：`-s` 脚本里不能引用全局名 | 要测就跑场景（`smoke_test.tscn`） |
| `scenes/world/twon.tscn` `scenes/world/farm.tscn` | 节点树 + `parent` 路径，手改易错位 | 先用 `outline` 看层级；改完再 `outline` 复查 |
| `tests/unit/test_assets.gd` | 美术 / 音频规范的可执行版本 | 改生成器或规范时同步改它 |
| `reports/**` | 自动生成的测试报告（几百个 HTML），体积噪声 | 已在 `.gitignore`；不要读、不要提交，看控制台或 `.tmp/` 日志就够 |
| `tools/outline.py` | 规范工具本身，也在变大 | 它超过 800 行那天就按 `parse / render / cli` 拆开 |

## 6. 别制造新的大文件

- 新文件顶部写 `##` 说明（这是 `outline` / `map` 的唯一"用途"来源）。
- 单个函数 ≤ 80 行；超了就抽子函数或抽到规则类（`XxxRules` / `XxxGrowth` 这类纯静态函数）。
- 入口型大文件（被多处调用 / 自带一套调度）在顶部 `##` 里写「调度地图」：
  谁调用我、我的子步骤挂在哪。例子见 `tools/smoke_test.gd`：
  `outline` 第一屏就能看到「农场检查在 `_run_checks()`，跨图巡游在 `_process()` 相位机」，不用读 `_process`。
- 参考案例（已拆）：`tools/smoke_test.gd` 1268 → 151 行 + `tools/smoke/`；`tools/generate_sample_data.gd` 1144 → 48 行 + `tools/sample/`。
  拆法是「移动函数 + 继承公共基座」，逻辑零改动，靠 `check.sh` 验证。
- 出现以下信号就拆分：
  - 文件里已有 3 个以上 `# ---- 分节`；
  - 打开文件要滚动才能找到目标函数；
  - 同一个文件因为两件不相关的事被改（如"矿洞视觉"和"存档格式"）。
- 拆法优先按域：规则（纯静态） / 状态（`RefCounted`） / 视图（`Node`） / 数据（`Resource`）；
  保留原 `class_name` 与公开 API 转发，避免一次性大重构。

## 7. 工具速查

```bash
python3 tools/outline.py map                    # 行数 + 用途总表
python3 tools/outline.py lint                   # 阈值体检（--strict 有红线时非 0）
python3 tools/outline.py outline <文件/目录>     # 结构大纲（精简；--full 展开）
python3 tools/outline.py map --full             # 全部文件索引（默认只列最大的 25 个）
python3 tools/outline.py sym <文件> <函数名>     # 只看一个函数
python3 tools/outline.py refs <文件> <函数名>    # 本文件内调用者 / 被调用
python3 tools/outline.py callers <函数名>        # 跨文件调用点
python3 tools/outline.py grep <模式> [路径]      # 带行号搜索
```

## 8. 豁免与例外

- 第三方（`addons/**`）与生成物（`assets/**`、`reports/**`、`.godot/**`、`target/**`）不适用本文。
- 确实需要突破阈值时（例如生成器天然是一个大 `_build_*` 序列）：
  1. 顶部 `##` 里写清"为什么大 + 怎么安全阅读"；
  2. 给关键函数补 `##` 说明，让 `outline` 输出自带导航；
  3. 在 PR / 提交信息里说明不拆的理由。

## 9. 让规范生效

- `./tools/check.sh` 会跑一次 `lint`（不阻断，缺 python3 时自动跳过）。
- CI 想硬性拦截时用 `python3 tools/outline.py lint --strict`（有红线文件 / 红线函数才非 0）。

