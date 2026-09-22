# UI 布局与响应式模型

> 本文只写"读代码看不出来"的约束。玩法见 README，数值见 data/**/*.tres，
> 美术格子见 src/art/atlas_layout.gd，单点设计读脚本顶部 `##`。

## 一句话

**尺寸只有两个来源**：运行时的 src/ui/ui_layout.gd（令牌 + 纯函数）与生成的主题
（tools/generate_resources.gd 从 UiLayout / ArtPalette 组装类型变体）。
场景（.tscn）只声明**结构**与**主题角色**（theme_type_variation），不再写裸数字。

## 分层

| 层 | 文件 | 职责 |
| --- | --- | --- |
| 令牌 | src/ui/ui_layout.gd（UiLayout） | 边距 / 间距 / 字号 / 最小尺寸 / 比例上限；纯静态函数负责响应式计算 |
| 主题 | tools/generate_resources.gd → assets/themes/game_theme.tres | 把令牌与调色板组装成类型变体（ModalPanel / TitleLabel / HudSlot …） |
| 外壳 | scenes/ui/modal_shell.tscn + src/ui/modal_shell.gd | 模态统一排版：遮罩 + 居中面板 + 标题 / 正文 / 说明 / 提示；按视口、安全区、UI 缩放重排 |
| 宿主 | src/ui/ui_root.gd | 模态栈与暂停；窗口尺寸变化时把安全区换算成虚拟边距并广播 |

## 约定

1. **不写裸数字**：.tscn 里禁止 theme_override_colors/、theme_override_font_sizes/、
   custom_minimum_size；模态场景还禁止 offset_ 与任何 theme_override_。
   由 tests/unit/test_ui_layout.gd 守卫。
2. **新样式先进主题变体**：要改"按钮 / 标题 / 面板长什么样"，改
   tools/generate_resources.gd 后重跑 ./tools/build_assets.sh，不手改 .tres。
3. **模态一律用 ModalShell**：场景实例化它，脚本在 _ready() 里
   shell.set_title(...) / shell.set_status(控件) / shell.set_body(控件)。
   内容控件声明在模态场景根部（编辑器里看着是平级），运行时被收编进外壳——
   因为 Godot 的"可编辑子节点"只在编辑器存在，运行时 instantiate() 会丢掉。
4. **缩放统一约定**：每个会缩放的界面订阅 EventBus.ui.ui_scale_changed 并自己实现
   apply_ui_scale(value)；放大只朝屏幕内侧长（pivot 由 UiLayout.grow_pivot 决定）。
5. **安全区**：UiRoot 在窗口尺寸变化时调用 UiLayout.safe_insets() 并广播
   EventBus.ui.safe_insets_changed；HUD / 触控 / 模态 / 对话据此让位。
6. **窄屏**：UiLayout.is_compact()（宽高比 < 1.6）时 HUD 隐藏顶部提示行，避免与
   左上状态卡重叠。

## 多分辨率策略

基准画布 640×360（project.godot 的 viewport），stretch=canvas_items +
aspect=expand：超宽 / 4:3 时虚拟画布自行扩展，界面靠锚点与比例夹取适配。

- 模态面板：UiLayout.modal_size() = 视口 × PANEL_RATIO，再被内容最小尺寸与
  PANEL_MIN / PANEL_MAX 夹取，并除以 UI 缩放（放大后仍不出屏）。
- 贴边界面：锚点 + grow_* 决定放大方向；安全区作为额外边距。
- 竖屏：由 src/ui/rotate_overlay.gd 拦截，不在本模型内。
- 最小窗口：640×360（project.godot 的 window/size/min_*）。

## 测试

tests/unit/test_ui_layout.gd：令牌纯函数（分辨率矩阵 / 安全区换算 / 断点 / pivot）
+ 硬编码门禁 + 每个模态的外壳接线 + 模态跟随 UI 缩放，以及一组**几何断言**：

- 每个模态在 640×360 ~ 2560×1080 都被夹在视口内且不小于内容最小尺寸；
- 触控打开时面板落在摇杆与 ABXY 之间的安全带；
- HUD 左上状态卡与顶部提示行不重叠、都在屏内；
- 钓鱼拉扯水槽让开右下 ABXY。

下限是 project.godot 的最小窗口 640×360；更小的窗口不在支持范围（内容会溢出）。
