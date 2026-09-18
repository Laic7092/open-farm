extends SceneTree
## 像素中文字体生成器 → [code]assets/fonts/pixel_cjk.png[/code] + [code]pixel_cjk.fnt[/code]
##
## [b]为什么不用现成的 TTF[/b]：项目要的是"像素风"，而系统里的中文矢量字体
## 在小字号下必然带抗锯齿（灰边），整数放大后就是一团糊。
## 本脚本用 [TextServer] 把中文字体在 [constant GLYPH_SIZE] 像素下
## [b]关闭抗锯齿[/b] 地栅格化，再打包成位图字体（BMFont 的 `.fnt` + PNG 图集）。
## 产出是纯像素的、可 diff 的、且不依赖运行环境有没有中文字体。
##
## [b]为什么只收子集[/b]：全量 CJK 有 2 万多个字形，图集要几十 MB。
## 这里只扫 [code]assets/i18n[/code] 下全部 [code]*.csv[/code] 的翻译表，只收集真正会被显示的
## 字符（通常几百个）。不再扫 [code].gd[/code] / [code].tscn[/code] 全文，
## 避免注释与报错文本污染字形子集；新增文案必须先登记进翻译表，再重跑一次。
## [code]tests/unit/test_assets.gd[/code] 会检查翻译表有没有漏字。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_font.gd
## # 指定源字体（优先级最高）
## OPEN_FARM_FONT_SRC=/path/to/font.ttf godot --headless --path . \
##     -s res://tools/art/generate_font.gd
## [/codeblock]

const Layout := preload("res://src/art/atlas_layout.gd")
const Art := preload("res://tools/art/art_lib.gd")

## 字形边长（像素）。12 是中文像素字体的经典字号，正好是 16 像素瓦片的 3/4。
const GLYPH_SIZE: int = 12
## 图集里每个字形之间留的透明间隔，避免采样时相邻字形互相"渗色"。
const PADDING: int = 1

const OUTPUT_FNT: String = "res://assets/fonts/pixel_cjk.fnt"
const OUTPUT_PNG: String = "res://assets/fonts/pixel_cjk.png"

## 收集字符时只扫翻译表；所有会显示的文本都必须先登记进 assets/i18n/*.csv。
const SCAN_DIRS: Array[String] = [
	"res://assets/i18n",
]
const SCAN_EXTENSIONS: Array[String] = ["csv", "tscn", "tres", "gd", "json"]

## 无论项目里有没有用到都一定要有的字符：ASCII + 常用中英标点 + 数字符号。
## 少了它们，玩家名字、金额、英文界面就会出现方块。
const EXTRA_CHARACTERS: String = (
	" !\"#$%&'()*+,-./0123456789:;<=>?@"
	+ "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`"
	+ "abcdefghijklmnopqrstuvwxyz{|}~"
	+ "　、。〈〉《》「」『』【】〔〕〖〗！＂＃＄％＆＇（）＊＋，－．／"
	+ "０１２３４５６７８９：；＜＝＞？＠［＼］＾＿｀｛｜｝～"
	+ "·—…‰′″℃×÷±°§"
	+ "年月日时分秒春夏秋冬第１年"
)

## 源字体候选路径：优先"为屏幕小字号设计"的黑体，其次通用无衬线。
##
## 之所以包含 WSL 挂载的 Windows 字体目录，是因为很多开发机就跑在 WSL 里、
## Linux 侧根本没装 CJK 字体。
const FONT_CANDIDATES: Array[String] = [
	# 屏幕黑体（12 像素下最清晰）
	"/mnt/c/Windows/Fonts/simhei.ttf",
	"C:/Windows/Fonts/simhei.ttf",
	"/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
	"/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
	# 通用无衬线 CJK
	"/mnt/c/Windows/Fonts/msyh.ttc",
	"C:/Windows/Fonts/msyh.ttc",
	"/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
	"/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc",
	"/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
	"/usr/share/fonts/truetype/arphic/uming.ttc",
	# macOS
	"/System/Library/Fonts/PingFang.ttc",
	"/System/Library/Fonts/STHeiti Light.ttc",
]


func _initialize() -> void:
	var codes := _collect_codes()
	print("待生成字符：%d 个（其中 CJK %d 个）" % [codes.size(), _count_cjk(codes)])

	var source := _find_source_font()
	if source.is_empty():
		push_warning(
			"未找到可用的中文字体，跳过像素字体生成（继续使用上次产出的 %s）。"
			% OUTPUT_FNT
			+ " 可安装 fonts-noto-cjk，或用 OPEN_FARM_FONT_SRC 指定字体文件。"
		)
		quit(0)
		return
	print("源字体：", source)

	var ts := TextServerManager.get_primary_interface()
	var rid := ts.create_font()
	ts.font_set_data(rid, FileAccess.get_file_as_bytes(source))
	# 像素风的关键三件套：关抗锯齿、关次像素定位、开启整像素对齐的 hinting。
	ts.font_set_antialiasing(rid, TextServer.FONT_ANTIALIASING_NONE)
	ts.font_set_subpixel_positioning(rid, TextServer.SUBPIXEL_POSITIONING_DISABLED)
	ts.font_set_hinting(rid, TextServer.HINTING_NORMAL)
	ts.font_set_allow_system_fallback(rid, false)
	ts.font_set_multichannel_signed_distance_field(rid, false)

	var ascent := int(ceilf(ts.font_get_ascent(rid, GLYPH_SIZE)))
	var descent := int(ceilf(ts.font_get_descent(rid, GLYPH_SIZE)))
	var entries := _rasterize(ts, rid, codes, ascent)

	ts.free_rid(rid)

	if entries.is_empty():
		push_error("没有栅格化出任何字形，放弃写入。")
		quit(1)
		return

	_write_font(entries, ascent, descent)
	quit()


# ---------------------------------------------------------------- 字符集

## 扫描项目里的文本文件 + 固定字符表，得到需要生成的字形集合。
func _collect_codes() -> Array[int]:
	var seen: Dictionary[int, bool] = {}
	for character: String in EXTRA_CHARACTERS:
		seen[character.unicode_at(0)] = true

	for directory: String in SCAN_DIRS:
		_scan_dir(directory, seen)

	var codes: Array[int] = []
	for code: int in seen:
		codes.append(code)
	codes.sort()
	return codes


func _scan_dir(path: String, seen: Dictionary[int, bool]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		var clean: String = file_name.trim_suffix(".remap")
		if not SCAN_EXTENSIONS.has(clean.get_extension().to_lower()):
			continue
		_collect_from_file(path.path_join(clean), seen)
	for sub: String in dir.get_directories():
		if sub.begins_with("."):
			continue
		_scan_dir(path.path_join(sub), seen)


func _collect_from_file(path: String, seen: Dictionary[int, bool]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		# 控制字符与 BOM 不进字体。
		if code < 0x20 or code == 0xFEFF:
			continue
		seen[code] = true


func _count_cjk(codes: Array[int]) -> int:
	var total: int = 0
	for code: int in codes:
		if code > 0x2E80:
			total += 1
	return total


# ---------------------------------------------------------------- 栅格化

## 把每个字符渲染成一张小位图，返回 [code]{code, data, width, height, xoffset, yoffset, advance}[/code]。
##
## [b]为什么要手动把 [param ascent] 加进 yoffset[/b]：
## Godot 用 BMFont 建出来的 [FontFile]，行内基线在 TextServer 侧取不到 ascent，
## 结果是"基线贴在行顶"——所有文字整体上移大约一个字高
## （表现是 HUD 第一行被屏幕顶边裁掉、标题文字盖到面板外面）。
## 把 ascent 预先折进每个字形的 yoffset，等价于把基线自己补回来；
## 而且因为 yoffset 与字号同比缩放，放大字号时依然对齐。
func _rasterize(ts: TextServer, rid: RID, codes: Array[int], ascent: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var missing := PackedStringArray()
	var size_vector := Vector2i(GLYPH_SIZE, 0)

	for code: int in codes:
		var glyph: int = ts.font_get_glyph_index(rid, GLYPH_SIZE, code, 0)
		if glyph == 0:
			# 空格之类的"无字形但有宽度"的字符要保留，否则排版会塌。
			if code == 0x20:
				entries.append({
					"code": code, "data": PackedByteArray(), "width": 0, "height": 0,
					"xoffset": 0, "yoffset": 0, "advance": GLYPH_SIZE / 2,
				})
			else:
				missing.append(char(code))
			continue

		ts.font_render_glyph(rid, size_vector, glyph)
		var uv := ts.font_get_glyph_uv_rect(rid, size_vector, glyph)
		var texture_index := ts.font_get_glyph_texture_idx(rid, size_vector, glyph)
		var texture := ts.font_get_texture_image(rid, size_vector, texture_index)
		var offset := ts.font_get_glyph_offset(rid, size_vector, glyph)
		var advance := int(roundf(ts.font_get_glyph_advance(rid, GLYPH_SIZE, glyph).x))
		var width: int = int(roundf(uv.size.x))
		var height: int = int(roundf(uv.size.y))

		if texture == null or width <= 0 or height <= 0:
			entries.append({
				"code": code, "data": PackedByteArray(), "width": 0, "height": 0,
				"xoffset": 0, "yoffset": 0, "advance": advance,
			})
			continue

		var region := Rect2i(
			Vector2i(int(floorf(uv.position.x)), int(floorf(uv.position.y))),
			Vector2i(width, height)
		)
		var sub := texture.get_region(region)
		sub.convert(Image.FORMAT_RGBA8)

		entries.append({
			"code": code,
			"data": sub.get_data(),
			"width": width,
			"height": height,
			"xoffset": int(roundf(offset.x)),
			"yoffset": int(roundf(offset.y)) + ascent,
			"advance": advance,
		})

	if not missing.is_empty():
		push_warning(
			"源字体缺少 %d 个字符，将回退到系统字体：%s"
			% [missing.size(), "".join(missing).substr(0, 120)]
		)
	return entries


# ---------------------------------------------------------------- 打包与写出

func _write_font(entries: Array[Dictionary], ascent: int, descent: int) -> void:
	# 1) 量出格子尺寸：字形宽度可能超过字号（斜体 / 手写体的伸出部分）。
	var cell_width: int = GLYPH_SIZE
	var cell_height: int = GLYPH_SIZE
	for entry: Dictionary in entries:
		cell_width = maxi(cell_width, int(entry["width"]))
		cell_height = maxi(cell_height, int(entry["height"]))
	cell_width += PADDING * 2
	cell_height += PADDING * 2

	var columns: int = maxi(int(ceil(sqrt(float(entries.size() + 1)))), 1)
	var rows: int = int(ceil(float(entries.size() + 1) / float(columns)))
	var atlas_width: int = columns * cell_width
	var atlas_height: int = rows * cell_height

	# 2) 逐字形写进图集数据（白色 + alpha，标签颜色靠 modulate 上色）。
	#    第 0 格保留为全透明，给"有宽度没字形"的字符（空格）当占位。
	var atlas := PackedByteArray()
	atlas.resize(atlas_width * atlas_height * 4)

	var placed: Array[Dictionary] = []
	var index: int = 1
	for entry: Dictionary in entries:
		var grid_x: int = index % columns
		var grid_y: int = index / columns
		index += 1

		var origin := Vector2i(grid_x * cell_width + PADDING, grid_y * cell_height + PADDING)
		var width: int = int(entry["width"])
		var height: int = int(entry["height"])
		if width > 0 and height > 0:
			_blit_into(atlas, atlas_width, origin, entry["data"], width, height)
		else:
			# 空字形指向第 0 格（全透明）。
			origin = Vector2i(PADDING, PADDING)
		placed.append({
			"code": int(entry["code"]),
			"x": origin.x, "y": origin.y,
			"width": width, "height": height,
			"xoffset": int(entry["xoffset"]),
			"yoffset": int(entry["yoffset"]),
			"advance": int(entry["advance"]),
		})

	var image := Image.create_from_data(
		atlas_width, atlas_height, false, Image.FORMAT_RGBA8, atlas
	)
	if not Art.save_png(image, OUTPUT_PNG):
		return

	# 3) 写 BMFont 文本描述。用文本而不是二进制，是为了让"字体改了哪几个字"
	#    在 git diff 里看得见。
	var file := FileAccess.open(OUTPUT_FNT, FileAccess.WRITE)
	if file == null:
		push_error("无法写入 %s" % OUTPUT_FNT)
		return
	file.store_line(
		'info face="open-farm-pixel" size=%d bold=0 italic=0 charset="" unicode=1 '
		% GLYPH_SIZE
		+ "stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=0,0 outline=0"
	)
	file.store_line(
		"common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 "
		% [ascent + descent, ascent, atlas_width, atlas_height]
		+ "alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0"
	)
	file.store_line('page id=0 file="%s"' % OUTPUT_PNG.get_file())
	file.store_line("chars count=%d" % placed.size())
	for glyph: Dictionary in placed:
		file.store_line(
			"char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15"
			% [
				glyph["code"], glyph["x"], glyph["y"], glyph["width"], glyph["height"],
				glyph["xoffset"], glyph["yoffset"], glyph["advance"],
			]
		)
	file.close()
	print("  → ", OUTPUT_FNT, "  字形 %d 个，图集 %d×%d" % [placed.size(), atlas_width, atlas_height])


## 把一张小位图的 alpha 通道阈值化后写进图集。
##
## 阈值化是"像素风"的最后一道保险：即使某个源字形带了残留灰边，
## 也只会得到全透明或全白两种像素。
func _blit_into(
	atlas: PackedByteArray, atlas_width: int, origin: Vector2i, data: PackedByteArray,
	width: int, height: int
) -> void:
	for y in height:
		for x in width:
			var source_index: int = (y * width + x) * 4
			if data[source_index + 3] < 128:
				continue
			var target_index: int = ((origin.y + y) * atlas_width + origin.x + x) * 4
			atlas[target_index] = 255
			atlas[target_index + 1] = 255
			atlas[target_index + 2] = 255
			atlas[target_index + 3] = 255


# ---------------------------------------------------------------- 源字体

func _find_source_font() -> String:
	var override := OS.get_environment("OPEN_FARM_FONT_SRC")
	if not override.is_empty() and FileAccess.file_exists(override):
		return override
	for path: String in FONT_CANDIDATES:
		if FileAccess.file_exists(path):
			return path
	return ""
