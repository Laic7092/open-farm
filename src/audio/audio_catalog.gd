class_name AudioCatalog
extends RefCounted
## 音频资源目录：生成器与运行时共用的"事实来源"。
##
## 与美术的 [code]src/art/palette.gd[/code] / [code]src/art/atlas_layout.gd[/code] 同一思路：
## [b]仓库里不放手工音频素材[/b]，每一个采样点都由 [code]tools/audio/*.gd[/code] 合成。
## 生成器按这里的 id 写出 [code]assets/audio/**[/code]，运行时按同样的 id 加载播放，
## 于是"改了文件名却忘了改播放代码"在结构上不可能发生。
##
## 音频格式统一为 [b]22050 Hz / 16 bit / 单声道 PCM[/b]：
## 采样率够做芯片音色，体积又足够小；单声道省一半空间，也符合复古气质。

## 采样率（Hz）。生成器写 WAV 与运行时读取都以此为准。
const SAMPLE_RATE: int = 22050
## 位深（目前只生成 16 bit PCM）。
const BITS_PER_SAMPLE: int = 16
## 声道数（单声道）。
const CHANNELS: int = 1

## 生成物目录。
const SFX_DIR: String = "res://assets/audio/sfx"
const BGM_DIR: String = "res://assets/audio/bgm"

# ---------------------------------------------------------------- BGM 曲目

## 标题页：慢速、明亮，像清晨。
const BGM_TITLE := &"title"
## 农场白天：轻快、有打击乐。
const BGM_FARM := &"farm"
## 小镇白天：热闹、跳跃。
const BGM_TOWN := &"town"
## 夜间（任何地图）：稀疏、安静的小调。
const BGM_NIGHT := &"night"
## 钓鱼：放缓的池塘小调，抛竿后接管世界曲目。
const BGM_FISHING := &"fishing"

## 全部 BGM 曲目（顺序 = 生成顺序）。
const BGM_TRACKS: Array[StringName] = [BGM_TITLE, BGM_FARM, BGM_TOWN, BGM_NIGHT, BGM_FISHING]

# ---------------------------------------------------------------- 音效

const SFX_UI_MOVE := &"ui_move"
const SFX_UI_CONFIRM := &"ui_confirm"
const SFX_UI_CANCEL := &"ui_cancel"
const SFX_UI_OPEN := &"ui_open"
const SFX_UI_CLOSE := &"ui_close"
const SFX_NOTIFY := &"notify"
const SFX_TOOL_SWING := &"tool_swing"
const SFX_TILL := &"till"
const SFX_WATER := &"water"
const SFX_PLANT := &"plant"
const SFX_HARVEST := &"harvest"
const SFX_CHOP := &"chop"
const SFX_COIN := &"coin"
const SFX_ITEM_GET := &"item_get"
const SFX_DIALOGUE := &"dialogue"
const SFX_ANIMAL_HAPPY := &"animal_happy"
const SFX_ANIMAL_EAT := &"animal_eat"
const SFX_MATURE := &"mature"
const SFX_SAVE := &"save"
const SFX_LOAD := &"load"
const SFX_FOOTSTEP_GRASS := &"footstep_grass"
const SFX_FOOTSTEP_PATH := &"footstep_path"
const SFX_STAMINA_DEPLETED := &"stamina_depleted"
const SFX_TRANSITION := &"transition"
const SFX_ERROR := &"error"
const SFX_MORNING := &"morning"
const SFX_FISH_CAST := &"fish_cast"
const SFX_FISH_BITE := &"fish_bite"
const SFX_FISH_CATCH := &"fish_catch"
const SFX_FISH_CHARGE := &"fish_charge"
const SFX_FISH_FIGHT := &"fish_fight"
const SFX_FISH_REEL := &"fish_reel"
const SFX_FISH_LINE_BREAK := &"fish_line_break"

## 全部音效（顺序 = 生成顺序）。
const SFX_ALL: Array[StringName] = [
	SFX_UI_MOVE,
	SFX_UI_CONFIRM,
	SFX_UI_CANCEL,
	SFX_UI_OPEN,
	SFX_UI_CLOSE,
	SFX_NOTIFY,
	SFX_TOOL_SWING,
	SFX_TILL,
	SFX_WATER,
	SFX_PLANT,
	SFX_HARVEST,
	SFX_CHOP,
	SFX_COIN,
	SFX_ITEM_GET,
	SFX_DIALOGUE,
	SFX_ANIMAL_HAPPY,
	SFX_ANIMAL_EAT,
	SFX_MATURE,
	SFX_SAVE,
	SFX_LOAD,
	SFX_FOOTSTEP_GRASS,
	SFX_FOOTSTEP_PATH,
	SFX_STAMINA_DEPLETED,
	SFX_TRANSITION,
	SFX_ERROR,
	SFX_MORNING,
	SFX_FISH_CAST,
	SFX_FISH_BITE,
	SFX_FISH_CATCH,
	SFX_FISH_CHARGE,
	SFX_FISH_FIGHT,
	SFX_FISH_REEL,
	SFX_FISH_LINE_BREAK,
]


# ---------------------------------------------------------------- 路径

## 某个 BGM 曲目的 WAV 路径（不含导入后的资源，[code]ResourceLoader[/code] 同样吃这个路径）。
static func bgm_path(id: StringName) -> String:
	return "%s/%s.wav" % [BGM_DIR, id]


## 某个音效的 WAV 路径。
static func sfx_path(id: StringName) -> String:
	return "%s/%s.wav" % [SFX_DIR, id]


## 根据 &"bgm"/&"sfx" 类别取路径，便于生成器与测试统一遍历。
static func path_for(kind: StringName, id: StringName) -> String:
	return bgm_path(id) if kind == &"bgm" else sfx_path(id)


## 全部 BGM id 的副本（防止调用方误改常量数组）。
static func bgm_ids() -> Array[StringName]:
	return BGM_TRACKS.duplicate()


## 全部音效 id 的副本。
static func sfx_ids() -> Array[StringName]:
	return SFX_ALL.duplicate()
