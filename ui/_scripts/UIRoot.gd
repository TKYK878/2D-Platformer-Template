@tool
extends Control
class_name UIRoot

# 一整套 UI（HUD、暫停選單、過關畫面、標題畫面）的根節點：範本場景的最上層就是它。
# 依欄位建一份 Theme 套在自己身上，底下所有零件的字型、字的大小、配色自動跟著變，學員不用碰 Theme 編輯器。
# 編輯器裡改欄位馬上看得到。遊戲開始時如果不在 CanvasLayer 底下（例如直接拖進關卡），會自己移進一個，
# 才會固定在畫面上、不跟著鏡頭跑。暫停選單、過關畫面在遊戲暫停時也照樣能動。
# 標題畫面自己就是一個場景（設為主場景），不放進關卡；遊戲名稱、主視覺、一行小字可以填欄位，也可以直接改範本裡的字和圖。

## 這是哪一種畫面（範本已經選好，不用改）
@export_enum("HUD", "暫停選單", "過關畫面", "標題畫面") var kind: int = KIND_HUD:
	set(value):
		kind = value
		_apply_process_mode()
		_apply_theme()
		notify_property_list_changed()
## 這一整套 UI 用的字型，從檔案系統把字型檔拖進來；空白用專案預設的像素字
@export var font: Font:
	set(value):
		font = value
		_apply_theme()
## 字的大小：像素字只能放大成原本的整數倍，不然會糊或高低不齊
@export_enum("原本大小 12:12", "2 倍 24:24", "3 倍 36:36", "4 倍 48:48") var font_size: int = 12:
	set(value):
		font_size = value
		_apply_theme()
## 配色：字、底色、按鈕、條的顏色一起換；標題畫面多一個「跟主視覺配」，從主視覺的圖自動配顏色；
## 其他畫面多一個「跟標題一樣」，用主場景（標題畫面）的配色，整套 UI 統一
@export_enum("預設", "暗色", "亮色", "復古綠", "糖果", "海洋", "森林", "夕陽", "黑白", "萬聖節", "自訂", "跟主視覺配", "跟標題一樣") var palette: int = PALETTE_DEFAULT:
	set(value):
		if value == PALETTE_CUSTOM and palette == PALETTE_ART:
			_copy_art_to_custom()
		palette = value
		if is_inside_tree():
			_refresh_art_colors()
		set_process(Engine.is_editor_hint() and palette == PALETTE_TITLE)
		_apply_theme()
		notify_property_list_changed()
		update_configuration_warnings()
## 風格：按鈕、條、底框的形狀（像素復古＝方角、乾淨極簡＝細外框、可愛圓角＝圓角加厚底邊、木牌＝木紋加釘子、
## 科幻＝切角亮線、漫畫＝粗黑框加硬陰影、復古遊戲機＝雙線框），顏色照 palette
@export_enum("像素復古", "乾淨極簡", "可愛圓角", "木牌", "科幻", "漫畫", "復古遊戲機") var style: int = STYLE_PIXEL:
	set(value):
		style = value
		_apply_theme()
## HUD 蓋在遊戲畫面上，背景花的時候字會看不清楚：字加外框（字外面一圈描邊）；只有 HUD 有這一格。
## 範本裡的 Panel 是底框，不要底框就把 Panel 的 Self Modulate 透明度拉到 0，或把 Rows 拖出來、刪掉 Panel
@export_enum("無", "字加外框") var hud_background: int = HUD_BG_OUTLINE:
	set(value):
		hud_background = value
		_apply_theme()

@export_group("自訂配色")
## 字的顏色（palette 選「自訂」才用到）：點色塊用滑鼠選
@export var text_color: Color = Color("f0ece0"):
	set(value):
		text_color = value
		_on_custom_color_changed()
## 底框的顏色，拉低 A（透明度）可以看到後面的遊戲畫面
@export var panel_color: Color = Color("2a2440e6"):
	set(value):
		panel_color = value
		_on_custom_color_changed()
## 按鈕的顏色（滑鼠移上去、按下去的顏色自動變亮變暗）
@export var button_color: Color = Color("4a3f6e"):
	set(value):
		button_color = value
		_on_custom_color_changed()
## 亮色：條、拉桿、底框外框、按鈕被選到時的顏色
@export var accent_color: Color = Color("ffb84a"):
	set(value):
		accent_color = value
		_on_custom_color_changed()

@export_group("跟主視覺配")
## 底框要深色還是淺色：自動（看主視覺整體是亮是暗）、深底（淺色的字）、淺底（深色的字）
@export_enum("自動", "深底", "淺底") var tone: int = 0:
	set(value):
		tone = value
		_on_art_changed()
## 按鈕和亮色用主視覺裡哪個顏色：最多的、第二多的、第三多的（圖裡顏色不夠多時會一樣）
@export_enum("最多的顏色", "第二多的顏色", "第三多的顏色") var main_color: int = 0:
	set(value):
		main_color = value
		_on_art_changed()
# 從主視覺算好的 4 個顏色（字、底框、按鈕、亮色），編輯器裡算好存進場景檔，遊戲中直接用（不用每次重讀圖）
@export_storage var art_colors: PackedColorArray = PackedColorArray()

@export_group("標題畫面")
## 遊戲名稱（這一格可以打字）：填了就蓋掉範本裡 GameName 的字；空白就用範本裡原本的字
@export var game_name: String = "":
	set(value):
		game_name = value
		_apply_title()
## 主視覺：從檔案系統把圖片拖進來，填了就換掉範本裡 KeyArt 的圖；空白就用範本裡原本的圖
@export var key_art: Texture2D:
	set(value):
		key_art = value
		_apply_title()
		_on_art_changed()
## 一行小字，例如「跳過 100 根尖刺，你做得到嗎？」（這一格可以打字）：填了就蓋掉範本裡 Hook 的字；空白就用範本裡原本的字
@export var hook: String = "":
	set(value):
		hook = value
		_apply_title()
## 標題畫面的背景音樂：從檔案系統把 .ogg／.mp3／.wav 拖進來（建議放在 _my/ 底下）；空白就不播。按「開始遊戲」換關時自動淡出
@export var music: AudioStream
## 背景音樂的音量，1 是原本的大小
@export_range(0.0, 1.0) var music_volume: float = 0.6

@export_group("按鈕音效")
## 按下這個畫面裡的按鈕時播什麼音效；選「自訂」可以放自己的音檔。個別按鈕（MenuAction）想不一樣可以自己選
@export_enum("無", "嗶", "金幣", "撿東西", "跳躍", "落地", "雷射", "自訂") var press_sound: int = SOUND_NONE:
	set(value):
		press_sound = value
		notify_property_list_changed()
		update_configuration_warnings()
## 自己的按下音效：從檔案系統把 .wav／.ogg／.mp3 拖進來
@export var custom_press_sound: AudioStream:
	set(value):
		custom_press_sound = value
		update_configuration_warnings()
## 選到按鈕時（滑鼠移上去、用鍵盤或手把切換）播什麼音效；選「自訂」可以放自己的音檔
@export_enum("無", "嗶", "金幣", "撿東西", "跳躍", "落地", "雷射", "自訂") var select_sound: int = SOUND_NONE:
	set(value):
		select_sound = value
		notify_property_list_changed()
		update_configuration_warnings()
## 自己的選到音效：從檔案系統把 .wav／.ogg／.mp3 拖進來
@export var custom_select_sound: AudioStream:
	set(value):
		custom_select_sound = value
		update_configuration_warnings()
## 按鈕音效的音量，1 是原本的大小
@export_range(0.0, 1.0) var sound_volume: float = 0.8

const KIND_HUD := 0
const KIND_PAUSE_MENU := 1
const KIND_CLEAR_SCREEN := 2
const KIND_TITLE := 3

const PALETTE_DEFAULT := 0
const PALETTE_CUSTOM := 10
const PALETTE_ART := 11
const PALETTE_TITLE := 12
# 測試用：「跟標題一樣」改看這個場景，不看專案的主場景（空字串＝看主場景）
static var title_scene_override := ""
# 「跟標題一樣」讀到的標題配色（所有畫面共用，遊戲中讀一次；編輯器裡每秒重讀，標題改了跟著變）
static var _title_cache := {}
static var _title_cache_problem := ""
static var _title_cache_time := -1
# 「跟標題一樣」上一次套用的顏色，編輯器裡比對標題有沒有改
var _applied_title_colors := {}
# 標題音樂的播放器和淡入淡出（沒放音樂就是 null）
var _music_player: AudioStreamPlayer = null
var _music_tween: Tween = null
# 這個時間（毫秒）以前選到按鈕不播音效：畫面剛出現時會自動選第一顆按鈕
var _select_quiet_until := 0
const _ArtPalette := preload("res://ui/_scripts/ArtPalette.gd")
const _ART_FIELDS := ["tone", "main_color"]
const NO_KEY_ART := "palette 選「跟主視覺配」，但找不到主視覺的圖：把圖拖進 key_art（或範本裡的 KeyArt），先用預設配色"
const ART_NOT_TITLE := "palette 的「跟主視覺配」只有標題畫面能用（其他畫面沒有主視覺），先用預設配色"
# 自訂配色的字跟底框亮度差小於這個就提醒看不清楚
const _MIN_CONTRAST := 0.3
const _CUSTOM_FIELDS := ["text_color", "panel_color", "button_color", "accent_color"]

const HUD_BG_NONE := 0
const HUD_BG_OUTLINE := 1
# 字加外框的粗細（像素）
const _OUTLINE_SIZE := 2

const STYLE_PIXEL := 0
const STYLE_CLEAN := 1
const STYLE_CUTE := 2
const STYLE_WOOD := 3
const STYLE_SCIFI := 4
const STYLE_COMIC := 5
const STYLE_RETRO := 6

# 每種風格的底框九宮格圖（灰階，遊戲中依配色的 panel 顏色上色；學員可以照同樣的格子重畫）、四邊各 8 像素不拉伸
const _PANEL_TEXTURES := [
	preload("res://ui/styles/Panel_Pixel.png"),
	preload("res://ui/styles/Panel_Clean.png"),
	preload("res://ui/styles/Panel_Cute.png"),
	preload("res://ui/styles/Panel_Wood.png"),
	preload("res://ui/styles/Panel_SciFi.png"),
	preload("res://ui/styles/Panel_Comic.png"),
	preload("res://ui/styles/Panel_Retro.png"),
]
# 每種風格底框最外圈的外框圖（白色，遊戲中依配色的 accent 上色）；漫畫本來就是黑框，不另外加
const _OUTLINE_TEXTURES := [
	preload("res://ui/styles/Outline_Pixel.png"),
	preload("res://ui/styles/Outline_Clean.png"),
	preload("res://ui/styles/Outline_Cute.png"),
	preload("res://ui/styles/Outline_Wood.png"),
	preload("res://ui/styles/Outline_SciFi.png"),
	null,
	preload("res://ui/styles/Outline_Retro.png"),
]
const _PANEL_PATCH := 8
# 每種風格底框裡面的留白（左右、上下）
const _PANEL_MARGINS := [Vector2(12, 8), Vector2(16, 12), Vector2(14, 10), Vector2(12, 10), Vector2(14, 10), Vector2(12, 10), Vector2(14, 12)]
# 漫畫風格的黑框、硬陰影顏色（不跟配色變）
const _INK := Color(0.08, 0.08, 0.1)
# 「預設」配色選了像素復古以外的風格時用的顏色（不然按鈕會是 Godot 原本的樣子，形狀換不了）
const _NEUTRAL := { "text": Color("f0f0f4"), "dim": Color("a0a0aa"), "panel": Color(0.06, 0.06, 0.09, 0.85),
	"button": Color("3a3a46"), "hover": Color("4c4c5a"), "pressed": Color("2a2a34"), "accent": Color("d0d0dc"), "back": Color("1e1e26") }

# 「預設」配色的選單底框：深色半透明，蓋在遊戲畫面上也看得清楚字
const _DEFAULT_PANEL := Color(0.06, 0.06, 0.09, 0.85)

const NO_CLEAR_SCREEN := "關卡裡沒有 ClearScreen，過關時這個過關畫面不會出現：把 blocks/ClearScreen.tscn 拖進關卡"
const _CLEAR_SCREEN_SCRIPT := "res://blocks/_scripts/ClearScreen.gd"

# 每一種畫面放在哪一層：數字越大蓋在越上面（跟原本的預設 UI 一樣）
const _LAYERS := [1, 20, 10, 30]
const _KIND_NAMES := ["HUD", "暫停選單", "過關畫面", "標題畫面"]
const _SCRIPT_PATH := "res://ui/_scripts/UIRoot.gd"
# 標題畫面的欄位 -> 範本裡對應的節點名稱
const _TITLE_NODES := { "game_name": "GameName", "key_art": "KeyArt", "hook": "Hook" }
# 標題畫面才有的音樂欄位
const _TITLE_MUSIC_FIELDS := ["music", "music_volume"]
# 標題音樂淡入、換關時淡出要幾秒
const _MUSIC_FADE := 1.0
# 淡到這個音量就算聽不到（線性音量）
const _SILENT := 0.0001
# 按鈕音效的選項：無、內建音效（跟下拉的順序一樣）、自訂；自訂卻沒放音檔時改播嗶
const SOUND_NONE := 0
const SOUND_CUSTOM := 7
const _UI_SOUNDS := [
	null,
	preload("res://sfx/beep.wav"),
	preload("res://sfx/coin.wav"),
	preload("res://sfx/pickup.wav"),
	preload("res://sfx/jump.wav"),
	preload("res://sfx/land.wav"),
	preload("res://sfx/laser.wav"),
]
const _SOUND_FIELDS := ["press_sound", "custom_press_sound", "select_sound", "custom_select_sound", "sound_volume"]
# 畫面剛出現、程式自動選第一顆按鈕的這段時間（毫秒）不播選到的音效
const SELECT_QUIET_MS := 200
const TITLE_NOT_ALONE :="標題畫面要自己一個場景（設為主場景），不能放進關卡；從 ui/templates/ 再製一份到 _my/，右鍵「設為主場景」"

# 每套配色的顏色：text 字、dim 次要的字、panel 底色、button 按鈕、hover 滑過、pressed 按下、accent 條和拉桿、back 條的底
const _PALETTES := [
	{},
	{ "text": Color("e8e8f0"), "dim": Color("9a9ab0"), "panel": Color("1c1c28e6"), "button": Color("34344a"),
		"hover": Color("4a4a66"), "pressed": Color("26263a"), "accent": Color("7c8cff"), "back": Color("14141e") },
	{ "text": Color("2a2a33"), "dim": Color("6a6a78"), "panel": Color("f4f1eae6"), "button": Color("dedad0"),
		"hover": Color("cfcabd"), "pressed": Color("bdb7a8"), "accent": Color("3b82c4"), "back": Color("c8c3b6") },
	{ "text": Color("c8f0a0"), "dim": Color("7aa860"), "panel": Color("0f2410e6"), "button": Color("1e4220"),
		"hover": Color("2c5c2e"), "pressed": Color("153016"), "accent": Color("8ce060"), "back": Color("0a180b") },
	{ "text": Color("5a2a4a"), "dim": Color("9a6a88"), "panel": Color("fff0f6e6"), "button": Color("ffc8e0"),
		"hover": Color("ffb0d2"), "pressed": Color("f598c0"), "accent": Color("ff6fae"), "back": Color("ffe0ee") },
	{ "text": Color("e6f6ff"), "dim": Color("8ab8d4"), "panel": Color("0e3550e6"), "button": Color("17507a"),
		"hover": Color("1f6a9e"), "pressed": Color("103c5c"), "accent": Color("4fd2e8"), "back": Color("0a2436") },
	{ "text": Color("f2ecd2"), "dim": Color("a8b08a"), "panel": Color("23361ee6"), "button": Color("3a5a2e"),
		"hover": Color("4c7240"), "pressed": Color("2c4424"), "accent": Color("d8b44a"), "back": Color("18240f") },
	{ "text": Color("3a1e2a"), "dim": Color("8a5a5a"), "panel": Color("ffd8b0e6"), "button": Color("ffb27a"),
		"hover": Color("ff9a62"), "pressed": Color("e8844e"), "accent": Color("e0405a"), "back": Color("f0c098") },
	{ "text": Color("f4f4f4"), "dim": Color("9a9a9a"), "panel": Color("101010e6"), "button": Color("3a3a3a"),
		"hover": Color("5a5a5a"), "pressed": Color("242424"), "accent": Color("ffffff"), "back": Color("000000") },
	{ "text": Color("ffd9a0"), "dim": Color("b08a5c"), "panel": Color("1e1028e6"), "button": Color("4a2468"),
		"hover": Color("6a3290"), "pressed": Color("341a4a"), "accent": Color("ff8a1e"), "back": Color("120a18") },
]

# 套用配色與字型、決定暫停時能不能動；學員的同一種畫面已經有一個的話自己刪掉並警告；
# 暫停選單、過關畫面先藏起來，等暫停、過關時才出現；遊戲中不在 CanvasLayer 底下的話移進一個；
# 自己就是整個場景（例如從標題「開始遊戲」換過來的設定畫面）的話直接顯示
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_process_mode()
	set_process(Engine.is_editor_hint() and palette == PALETTE_TITLE)
	if Engine.is_editor_hint() or art_colors.is_empty():
		_refresh_art_colors()
	_apply_theme()
	_apply_title()
	if Engine.is_editor_hint():
		return
	for problem in [custom_contrast_problem(), art_problem(), title_palette_problem()] + Array(_sound_problems()):
		if problem != "":
			push_warning("[%s] %s" % [name, problem])
			printerr("⚠ [%s] %s" % [name, problem])
	_snap_containers(self)
	_connect_button_sounds(self)
	_select_quiet_until = Time.get_ticks_msec() + SELECT_QUIET_MS
	visibility_changed.connect(_on_visibility_changed_for_sounds)
	if kind == KIND_TITLE:
		_ready_title()
		return
	if kind != KIND_HUD and get_parent() == get_tree().root:
		_ready_alone()
		return
	if kind != KIND_HUD:
		visible = false
	if not get_meta(HudBinding.DEFAULT_META, false):
		var group := "custom_ui_%d" % kind
		var first := get_tree().get_first_node_in_group(group)
		if first != null:
			var message := "關卡裡已經有一個自訂%s「%s」，「%s」不會用到，先拿掉" % [_KIND_NAMES[kind], first.name, name]
			push_warning("[%s] %s" % [name, message])
			printerr("⚠ [%s] %s" % [name, message])
			queue_free()
			return
		add_to_group(group)
		if kind == KIND_CLEAR_SCREEN:
			_check_clear_screen.call_deferred()
	if not get_parent() is CanvasLayer:
		_move_to_layer.call_deferred()

# 標題畫面：自己是場景最上層才用；被放進關卡的話警告並拿掉（不然會蓋住整個遊戲）
func _ready_title() -> void:
	if get_parent() == get_tree().root:
		_focus_first_button.call_deferred(self)
		_start_music()
		return
	push_warning("[%s] %s" % [name, TITLE_NOT_ALONE])
	printerr("⚠ [%s] %s" % [name, TITLE_NOT_ALONE])
	queue_free()

# 暫停選單、過關畫面自己就是整個場景（例如設定畫面）：不藏起來、不暫停，先選好第一個按鈕讓鍵盤、手把能直接操作；
# 按返回（Esc、手把 B）回標題由 PauseMenu 處理
func _ready_alone() -> void:
	_focus_first_button.call_deferred(self)

# 這個畫面是不是自己就是整個場景（標題畫面、單獨開的設定畫面這類），不是放進關卡裡的
func is_alone() -> bool:
	return is_inside_tree() and get_parent() == get_tree().root

# theme 由欄位自動產生：不存進場景檔、Inspector 也不顯示，學員改字型配色用上面的欄位；
# 標題畫面的欄位只在標題畫面顯示
func _validate_property(property: Dictionary) -> void:
	if property.name == "theme":
		property.usage = PROPERTY_USAGE_NONE
	elif (_TITLE_NODES.has(property.name) or property.name in _TITLE_MUSIC_FIELDS) and kind != KIND_TITLE:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "hud_background" and kind != KIND_HUD:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name in _SOUND_FIELDS and kind == KIND_HUD:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "custom_press_sound" and press_sound != SOUND_CUSTOM:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "custom_select_sound" and select_sound != SOUND_CUSTOM:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name in _CUSTOM_FIELDS and palette != PALETTE_CUSTOM:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name in _ART_FIELDS and palette != PALETTE_ART:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "palette":
		# 「跟主視覺配」只給標題畫面、「跟標題一樣」只給其他畫面（已經選了的照樣顯示，才看得到黃色驚嘆號）
		var options: PackedStringArray = property.hint_string.split(",")
		var shown := PackedStringArray()
		for i in options.size():
			var hide_art := i == PALETTE_ART and kind != KIND_TITLE and palette != PALETTE_ART
			var hide_title := i == PALETTE_TITLE and kind == KIND_TITLE and palette != PALETTE_TITLE
			if not hide_art and not hide_title:
				shown.append("%s:%d" % [options[i].get_slice(":", 0), i])
		property.hint_string = ",".join(shown)

# 這套 UI 放進關卡時（不是單獨編輯它的時候），把底下顯示零件的設定錯誤收集起來顯示在這裡：
# 放進關卡的場景看不到裡面的子節點，錯誤要掛在看得到的這一層
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_inside_tree():
		return warnings
	var scene_root := get_tree().edited_scene_root
	var contrast := custom_contrast_problem()
	if contrast != "":
		warnings.append(contrast)
	var art := art_problem()
	if art != "":
		warnings.append(art)
	var follow := title_palette_problem()
	if follow != "":
		warnings.append(follow)
	warnings.append_array(_sound_problems())
	if kind == KIND_TITLE:
		if scene_root != null and scene_root != self:
			warnings.append(TITLE_NOT_ALONE)
		else:
			warnings.append_array(_title_warnings())
		return warnings
	if scene_root == null or scene_root == self:
		return warnings
	var first := _first_of_kind(scene_root)
	if first != null and first != self:
		warnings.append("關卡裡已經有一個自訂%s「%s」，這個不會用到：一個關卡只能放一個%s" % [_KIND_NAMES[kind], first.name, _KIND_NAMES[kind]])
	if kind == KIND_CLEAR_SCREEN and not has_clear_screen(scene_root):
		warnings.append(NO_CLEAR_SCREEN)
	_collect_warnings(self, scene_root, warnings)
	return warnings

# 往下找第一個看得到的按鈕先選起來，鍵盤（Enter、空白鍵）可以直接按；找到就停
func _focus_first_button(node: Node) -> bool:
	for child in node.get_children():
		if child is BaseButton and (child as Control).is_visible_in_tree():
			(child as Control).grab_focus()
			return true
		if _focus_first_button(child):
			return true
	return false

# 標題畫面的背景音樂：有放音樂檔就走 BGM 匯流排（音樂拉桿管得到）淡入播放，播完自己從頭再播
func _start_music() -> void:
	if music == null:
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "TitleMusic"
	_music_player.bus = &"BGM"
	_music_player.stream = music
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.finished.connect(_music_player.play)
	add_child(_music_player)
	_set_music_level(0.0, _music_player)
	_music_player.play()
	_music_tween = _fade_music(_music_player, 0.0, music_volume)
	print("[%s] 開始播放標題音樂" % name)

# 換場景時 PauseMenu 呼叫：把還在播的標題音樂交給 keeper（不會跟著標題畫面一起消失），淡出之後拿掉
func hand_off_music(keeper: Node) -> void:
	if _music_player == null or not is_instance_valid(_music_player):
		return
	var player := _music_player
	_music_player = null
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	player.finished.disconnect(player.play)
	# 播放器換位置時會停掉，記下播到哪裡、換好之後接著播
	var at := player.get_playback_position()
	var level := db_to_linear(player.volume_db)
	player.reparent(keeper)
	player.play(at)
	_fade_music(player, level, 0.0).tween_callback(player.queue_free)

# 把播放器的音量從 from 淡到 to（線性 0～1），用真實時間，頓幀、暫停都不影響
func _fade_music(player: AudioStreamPlayer, from: float, to: float) -> Tween:
	var tween := player.create_tween().set_ignore_time_scale(true)
	tween.tween_method(_set_music_level.bind(player), from, to, _MUSIC_FADE)
	return tween

# 設定播放器的音量（線性 0～1）
func _set_music_level(level: float, player: AudioStreamPlayer) -> void:
	player.volume_db = linear_to_db(maxf(level, _SILENT))

# 下拉選的按鈕音效：無回傳 null；自訂回傳學員的音檔，沒放音檔改播嗶。MenuAction 也用這個
static func ui_sound(choice: int, custom: AudioStream) -> AudioStream:
	if choice == SOUND_CUSTOM:
		return custom if custom != null else _UI_SOUNDS[1]
	if choice < 0 or choice >= _UI_SOUNDS.size():
		return null
	return _UI_SOUNDS[choice]

# 播一次選單按鈕的音效（按下、選到）：播放器放在場景樹最上層，按「開始遊戲」換場景也不會被切掉；
# 走 SFX 匯流排、暫停中照播，播完自己拿掉；stream 是 null 就不播。MenuAction 也用這個
static func play_ui_sound(from: Node, stream: AudioStream, volume: float) -> void:
	if stream == null or not from.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.name = "UISound"
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = linear_to_db(maxf(volume, _SILENT))
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	from.get_tree().root.add_child(player)
	player.play()

# 按鈕音效的設定問題：選了「自訂」卻沒放音檔
func _sound_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	if kind == KIND_HUD:
		return problems
	if press_sound == SOUND_CUSTOM and custom_press_sound == null:
		problems.append("press_sound 選了「自訂」，但 custom_press_sound 是空的，請把音檔從檔案系統拖進來；沒放之前先播嗶")
	if select_sound == SOUND_CUSTOM and custom_select_sound == null:
		problems.append("select_sound 選了「自訂」，但 custom_select_sound 是空的，請把音檔從檔案系統拖進來；沒放之前先播嗶")
	return problems

# 往下找這個畫面裡所有按鈕，接上按下、選到的音效（不用學員連線）
func _connect_button_sounds(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			var button := child as BaseButton
			button.pressed.connect(_on_button_pressed.bind(button))
			button.mouse_entered.connect(_on_button_selected.bind(button, true))
			button.focus_entered.connect(_on_button_selected.bind(button, false))
		_connect_button_sounds(child)

# 畫面出現時（暫停選單、過關畫面打開）會自動選第一顆按鈕，這一下不播選到的音效
func _on_visibility_changed_for_sounds() -> void:
	if visible:
		_select_quiet_until = Time.get_ticks_msec() + SELECT_QUIET_MS

# 按下按鈕：播這個畫面的按下音效（按鈕自己選了音效的話由它自己播）
func _on_button_pressed(button: BaseButton) -> void:
	if button.has_method("has_own_sound") and button.has_own_sound(true):
		return
	play_ui_sound(self, ui_sound(press_sound, custom_press_sound), sound_volume)

# 選到按鈕：滑鼠移上去，或用鍵盤、手把切換過去時播選到的音效；滑鼠點下去順便選到的、畫面剛出現自動選的不播
func _on_button_selected(button: BaseButton, by_mouse: bool) -> void:
	if not is_select_sound_wanted(button, by_mouse, _select_quiet_until):
		return
	if button.has_method("has_own_sound") and button.has_own_sound(false):
		return
	play_ui_sound(self, ui_sound(select_sound, custom_select_sound), sound_volume)

# 這一次選到要不要播音效：按鈕停用、看不到的不播；鍵盤選到的時候滑鼠正按著（點下去順便選到）不播；quiet_until 以前不播
static func is_select_sound_wanted(button: BaseButton, by_mouse: bool, quiet_until: int) -> bool:
	if button.disabled or not button.is_visible_in_tree():
		return false
	if Time.get_ticks_msec() < quiet_until:
		return false
	if not by_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return false
	return true

# 標題畫面的欄位填了，範本裡卻找不到對應的節點（被刪掉或改名）時的警告
func _title_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for field in _TITLE_NODES:
		var value = get(field)
		var filled: bool = value != null and not (value is String and (value as String).strip_edges() == "")
		if filled and _title_node(field) == null:
			warnings.append("%s：範本裡的 %s 被刪掉或改名了，這一欄不會顯示" % [field, _TITLE_NODES[field]])
	return warnings

# 範本裡標題畫面某個欄位對應的節點（照名稱往下找），找不到回傳 null
func _title_node(field: String) -> Node:
	return find_child(_TITLE_NODES[field], true, false)

# 把標題畫面的欄位套到範本裡的字和圖：有填的才蓋掉，空白的不動
func _apply_title() -> void:
	if kind != KIND_TITLE or not is_inside_tree():
		return
	var name_label := _title_node("game_name") as Label
	if name_label != null and game_name.strip_edges() != "":
		name_label.text = game_name.strip_edges()
	var art := _title_node("key_art") as TextureRect
	if art != null and key_art != null and art.texture != key_art:
		art.texture = key_art
	var hook_label := _title_node("hook") as Label
	if hook_label != null and hook.strip_edges() != "":
		hook_label.text = hook.strip_edges()
	update_configuration_warnings()

# 場景檔最上層是哪一種 UIRoot（只看場景檔，不生出來）；最上層不是 UIRoot 回傳 -1。
# 最上層是另一個場景的實例（繼承的場景）時，往那個場景找腳本
static func scene_root_kind(packed: PackedScene) -> int:
	var state := packed.get_state()
	var found_kind := -1
	var is_root := false
	for i in state.get_node_property_count(0):
		var prop := state.get_node_property_name(0, i)
		var value = state.get_node_property_value(0, i)
		if prop == &"script" and value is Script:
			is_root = (value as Script).resource_path == _SCRIPT_PATH
		elif prop == &"kind":
			found_kind = int(value)
	var base := state.get_node_instance(0)
	if not is_root and base != null:
		var base_kind := scene_root_kind(base)
		if base_kind == -1:
			return -1
		return found_kind if found_kind != -1 else base_kind
	if not is_root:
		return -1
	return found_kind if found_kind != -1 else KIND_HUD

# 關卡裡有沒有 ClearScreen（過關的流程靠它，自訂過關畫面只管長相）
static func has_clear_screen(scene_root: Node) -> bool:
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var node_script: Script = node.get_script()
		if node_script != null and node_script.resource_path == _CLEAR_SCREEN_SCRIPT:
			return true
		stack.append_array(node.get_children())
	return false

# 遊戲中：自訂過關畫面在關卡裡，卻沒有 ClearScreen 叫它出來時提醒
func _check_clear_screen() -> void:
	if is_inside_tree() and get_tree().get_first_node_in_group("clear_screen") == null:
		push_warning("[%s] %s" % [name, NO_CLEAR_SCREEN])
		printerr("⚠ [%s] %s" % [name, NO_CLEAR_SCREEN])

# 關卡裡第一個跟自己同一種畫面的 UIRoot（照場景樹由上到下的順序）
func _first_of_kind(node: Node) -> UIRoot:
	if node is UIRoot and node.kind == kind:
		return node
	for child in node.get_children():
		var found := _first_of_kind(child)
		if found != null:
			return found
	return null

# 往下找顯示零件，把它們在這個關卡裡的設定錯誤加上零件名稱收集起來
func _collect_warnings(node: Node, scene_root: Node, warnings: PackedStringArray) -> void:
	for child in node.get_children():
		if child.has_method("get_hud_warnings"):
			for w in child.get_hud_warnings(scene_root):
				warnings.append("%s：%s" % [child.name, w])
		_collect_warnings(child, scene_root, warnings)

# 讀目前配色裡某個角色的顏色（text、dim、panel、button、hover、pressed、accent、back），
# 配色是「預設」（而且風格是像素復古）時回傳 fallback；顯示零件畫自己的預設樣式時用這個
func get_palette_color(role: String, fallback: Color) -> Color:
	return _colors().get(role, fallback)

# 「跟主視覺配」用不了的原因（不是標題畫面、找不到主視覺、讀不到圖），能用回傳空字串
func art_problem() -> String:
	if palette != PALETTE_ART:
		return ""
	if kind != KIND_TITLE:
		return ART_NOT_TITLE
	if _art_texture() == null:
		return NO_KEY_ART
	if art_colors.size() < 4:
		return "讀不到主視覺「%s」的顏色，先用預設配色：換一張 PNG 或 JPG 圖試試" % _art_texture().resource_path.get_file()
	return ""

# 「跟標題一樣」用不了的原因（這個就是標題畫面、主場景不是標題畫面），能用回傳空字串
func title_palette_problem() -> String:
	if palette != PALETTE_TITLE:
		return ""
	if kind == KIND_TITLE:
		return "palette 的「跟標題一樣」是給 HUD、暫停選單、過關畫面用的，標題畫面自己選一套配色"
	_read_title_palette()
	return _title_cache_problem

# 讀主場景（標題畫面）的配色存起來：遊戲中只讀一次，編輯器裡超過一秒就重讀
static func _read_title_palette() -> void:
	var now := Time.get_ticks_msec()
	if _title_cache_time >= 0 and (not Engine.is_editor_hint() or now - _title_cache_time < 1000):
		return
	_title_cache_time = now
	_title_cache = {}
	_title_cache_problem = ""
	var path: String = title_scene_override
	if path == "":
		path = ProjectSettings.get_setting("application/run/main_scene", "")
	var packed := load(path) as PackedScene if path != "" and ResourceLoader.exists(path) else null
	var title: Node = packed.instantiate() if packed != null else null
	if not title is UIRoot or (title as UIRoot).kind != KIND_TITLE:
		_title_cache_problem = "palette 選「跟標題一樣」，但專案的主場景不是標題畫面：先把 _my/ 裡的標題畫面「設為主場景」，現在先用預設配色"
	else:
		var t := title as UIRoot
		if t.palette == PALETTE_ART and t.art_colors.is_empty():
			t._refresh_art_colors()
		_title_cache = t._colors()
	if title != null:
		title.free()

# 編輯器裡選了「跟標題一樣」：標題的配色改了就跟著換
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or palette != PALETTE_TITLE:
		set_process(false)
		return
	_read_title_palette()
	if _title_cache != _applied_title_colors:
		_apply_theme()
		update_configuration_warnings()

# 主視覺的圖：key_art 有填就用它，沒填就用範本裡 KeyArt 原本的圖
func _art_texture() -> Texture2D:
	if key_art != null:
		return key_art
	var art := _title_node("key_art") as TextureRect
	return art.texture if art != null else null

# 重新從主視覺算 4 個顏色（只在選了「跟主視覺配」的標題畫面算）
func _refresh_art_colors() -> void:
	if palette != PALETTE_ART or kind != KIND_TITLE:
		return
	var info := _ArtPalette.analyze(_ArtPalette.read_image(_art_texture()))
	art_colors = _ArtPalette.make_colors(info, tone, main_color)

# 主視覺、深淺、主色改了：重算顏色、重建 Theme、重新檢查
func _on_art_changed() -> void:
	if palette != PALETTE_ART or not is_inside_tree():
		return
	_refresh_art_colors()
	_apply_theme()
	update_configuration_warnings()

# 從「跟主視覺配」改選「自訂」：4 個取色器帶著剛剛配好的顏色，學員從這裡開始微調
func _copy_art_to_custom() -> void:
	if art_colors.size() < 4:
		return
	text_color = art_colors[0]
	panel_color = art_colors[1]
	button_color = art_colors[2]
	accent_color = art_colors[3]

# 存檔前重算一次（範本裡 KeyArt 的圖被直接換掉時，存進去的顏色也跟著對）
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE and palette == PALETTE_ART:
		_refresh_art_colors()
		_apply_theme()

# 自訂配色改了顏色：重建 Theme、重新檢查看不看得清楚
func _on_custom_color_changed() -> void:
	if palette == PALETTE_CUSTOM:
		_apply_theme()
		update_configuration_warnings()

# 自訂配色的字跟底框顏色太接近時回傳提醒，沒問題回傳空字串
func custom_contrast_problem() -> String:
	if palette != PALETTE_CUSTOM:
		return ""
	if absf(text_color.get_luminance() - panel_color.get_luminance()) >= _MIN_CONTRAST:
		return ""
	return "自訂配色的 text_color（字）跟 panel_color（底框）太接近，字可能看不清楚：把其中一個調亮、另一個調暗"

# 從 4 個顏色（字、底框、按鈕、亮色）算出整套顏色：次要字＝字往底框混一點，滑過／按下＝按鈕變亮／變暗，條的底＝底框變暗
func _colors_from(text: Color, panel: Color, button: Color, accent: Color) -> Dictionary:
	var lighter := button.get_luminance() < 0.6
	return {
		"text": text,
		"dim": text.lerp(Color(panel, 1.0), 0.45),
		"panel": panel,
		"button": button,
		"hover": button.lightened(0.15) if lighter else button.darkened(0.12),
		"pressed": button.darkened(0.2),
		"accent": accent,
		"back": Color(panel.darkened(0.45), 1.0),
	}

# 現在用的這套顏色：「預設」配色配像素復古以外的風格時用中性色；「跟主視覺配」用不了時當成「預設」
func _colors() -> Dictionary:
	if palette == PALETTE_CUSTOM:
		return _colors_from(text_color, panel_color, button_color, accent_color)
	if palette == PALETTE_ART:
		if art_problem() == "":
			return _colors_from(art_colors[0], art_colors[1], art_colors[2], art_colors[3])
		return _NEUTRAL if style != STYLE_PIXEL else {}
	if palette == PALETTE_TITLE:
		if title_palette_problem() == "":
			_applied_title_colors = _title_cache
			if not _title_cache.is_empty():
				return _title_cache
		return _NEUTRAL if style != STYLE_PIXEL else {}
	var colors: Dictionary = _PALETTES[palette]
	if colors.is_empty() and style != STYLE_PIXEL:
		return _NEUTRAL
	return colors

# 依欄位建一份 Theme 套在自己身上，再通知底下的零件配色換了
func _apply_theme() -> void:
	if not is_inside_tree():
		return
	var t := Theme.new()
	if font != null:
		t.default_font = font
	t.default_font_size = font_size
	var colors := _colors()
	if not colors.is_empty():
		_add_palette(t, colors)
	_add_panel(t, colors)
	_add_variations(t, colors)
	if kind == KIND_HUD and hud_background == HUD_BG_OUTLINE:
		_add_outline(t, colors)
	theme = t
	_notify_children(self)

# HUD 的字加外框：字是亮的就描深色、字是暗的就描淺色
func _add_outline(t: Theme, c: Dictionary) -> void:
	var text_color: Color = c.get("text", Color.WHITE)
	var edge := Color(0, 0, 0, 0.85) if text_color.get_luminance() > 0.5 else Color(1, 1, 1, 0.85)
	for type in ["Label", "Button", "ProgressBar"]:
		t.set_constant("outline_size", type, _OUTLINE_SIZE)
		t.set_color("font_outline_color", type, edge)

# 把一套配色寫進 Theme：字、按鈕、進度條、拉桿、面板
func _add_palette(t: Theme, c: Dictionary) -> void:
	t.set_color("font_color", "Label", c.text)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", c.text)
	t.set_color("font_disabled_color", "Button", c.dim)
	t.set_stylebox("normal", "Button", _button_box(c.button, c.dim, false))
	t.set_stylebox("hover", "Button", _button_box(c.hover, c.accent, false))
	t.set_stylebox("pressed", "Button", _button_box(c.pressed, c.accent, true))
	t.set_stylebox("hover_pressed", "Button", _button_box(c.pressed, c.accent, true))
	t.set_stylebox("disabled", "Button", _button_box(c.back, c.back, false))
	t.set_stylebox("focus", "Button", _outline(c.accent))
	t.set_color("font_color", "ProgressBar", c.text)
	t.set_stylebox("background", "ProgressBar", _bar_box(c.back))
	t.set_stylebox("fill", "ProgressBar", _bar_box(c.accent))
	t.set_stylebox("slider", "HSlider", _bar_box(c.back, 2))
	t.set_stylebox("grabber_area", "HSlider", _bar_box(c.accent, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _bar_box(c.accent, 2))

# 選單的底框（Panel、PanelContainer）：用這個風格的九宮格圖，依配色上色（「預設」配色是深色半透明），
# 最外圈再疊一圈 accent 顏色的外框；四周留白讓字不貼邊
func _add_panel(t: Theme, c: Dictionary) -> void:
	var fill := StyleBoxTexture.new()
	fill.texture = _PANEL_TEXTURES[style]
	fill.set_texture_margin_all(_PANEL_PATCH)
	if style == STYLE_WOOD:
		fill.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		fill.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	fill.modulate_color = c.get("panel", _DEFAULT_PANEL)
	var box := PanelBox.new()
	box.fill = fill
	if _OUTLINE_TEXTURES[style] != null:
		var outline := StyleBoxTexture.new()
		outline.texture = _OUTLINE_TEXTURES[style]
		outline.set_texture_margin_all(_PANEL_PATCH)
		outline.draw_center = false
		outline.modulate_color = c.get("accent", _NEUTRAL.accent)
		box.outline = outline
	var margin: Vector2 = _PANEL_MARGINS[style]
	box.content_margin_left = margin.x
	box.content_margin_right = margin.x
	box.content_margin_top = margin.y
	box.content_margin_bottom = margin.y
	t.set_stylebox("panel", "Panel", box)
	t.set_stylebox("panel", "PanelContainer", box)

# 範本用的兩種字：標題（TitleLabel，兩倍大）、提示（HintLabel，次要的顏色）；
# 在 Label 的 Theme Type Variation 選它們，換配色、字的大小時跟著變
func _add_variations(t: Theme, c: Dictionary) -> void:
	t.set_type_variation("TitleLabel", "Label")
	t.set_font_size("font_size", "TitleLabel", font_size * 2)
	t.set_type_variation("HintLabel", "Label")
	t.set_color("font_color", "HintLabel", c.get("dim", Color(0.75, 0.75, 0.75)))

# 純色的方框（像素風，不要圓角），margin 是內距
func _box(color: Color, margin: int = 4) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin / 2.0
	box.content_margin_bottom = margin / 2.0
	return box

# 按鈕的方框，形狀照風格：像素復古＝純色方角；乾淨極簡＝細外框（edge 顏色）、左右多留白；
# 可愛圓角＝圓角、底邊加厚像按得下去的按鍵，按下時底邊變薄、字往下移
func _button_box(color: Color, edge: Color, pressed: bool) -> StyleBoxFlat:
	var box := _box(color)
	match style:
		STYLE_CLEAN:
			box.set_border_width_all(1)
			box.border_color = edge
			box.content_margin_left = 8
			box.content_margin_right = 8
		STYLE_CUTE:
			box.set_corner_radius_all(6)
			box.anti_aliasing = false
			box.border_color = color.darkened(0.35)
			box.border_width_bottom = 1 if pressed else 3
			box.content_margin_left = 8
			box.content_margin_right = 8
			box.content_margin_top = 4 if pressed else 2
		STYLE_WOOD:
			box.set_corner_radius_all(2)
			box.anti_aliasing = false
			box.set_border_width_all(1)
			box.border_color = color.darkened(0.5)
			box.border_width_bottom = 1 if pressed else 2
			box.content_margin_left = 6
			box.content_margin_right = 6
			box.content_margin_top = 3 if pressed else 2
		STYLE_SCIFI:
			box.bg_color = Color(color, color.a * 0.85)
			box.set_border_width_all(1)
			box.border_width_left = 3
			box.border_color = edge
			box.content_margin_left = 8
			box.content_margin_right = 6
		STYLE_COMIC:
			box.border_color = _INK
			box.set_border_width_all(2)
			box.border_width_right = 2 if pressed else 4
			box.border_width_bottom = 2 if pressed else 4
			box.content_margin_left = 8 if pressed else 6
			box.content_margin_right = 6
			box.content_margin_top = 4 if pressed else 2
		STYLE_RETRO:
			box.border_width_left = 4
			box.border_color = edge
			box.content_margin_left = 10
			box.content_margin_right = 6
	return box

# 條和拉桿的方框：可愛圓角時是圓的，其他風格方角
func _bar_box(color: Color, margin: int = 4) -> StyleBoxFlat:
	var box := _box(color, margin)
	if style == STYLE_CUTE:
		box.set_corner_radius_all(3)
		box.anti_aliasing = false
	elif style == STYLE_WOOD:
		box.set_corner_radius_all(2)
		box.anti_aliasing = false
	elif style == STYLE_COMIC:
		box.set_border_width_all(1)
		box.border_color = _INK
	return box

# 只有外框的方框，按鈕被選到（用鍵盤操作）時用；可愛圓角時也是圓角
func _outline(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_border_width_all(2 if style == STYLE_COMIC else 1)
	box.border_color = color
	if style == STYLE_CUTE:
		box.set_corner_radius_all(6)
		box.anti_aliasing = false
	return box

# 往下找所有零件，有 _on_ui_root_changed 的就通知它配色或字型換了（零件不用往上找根節點）
func _notify_children(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("_on_ui_root_changed"):
			child._on_ui_root_changed(self)
		_notify_children(child)

# 暫停選單、過關畫面在遊戲暫停時也要能動；HUD 跟著遊戲
func _apply_process_mode() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if kind == KIND_HUD else Node.PROCESS_MODE_ALWAYS

# 置中的容器排出來的位置常常落在半個像素上，像素字型會糊掉：排好之後捨去成整數像素
func _snap_containers(node: Node) -> void:
	for child in node.get_children():
		if child is CenterContainer:
			child.sort_children.connect(_snap_to_pixels.bind(child))
		_snap_containers(child)

# 把容器底下每個子節點的位置捨去成整數像素
func _snap_to_pixels(container: Container) -> void:
	for child in container.get_children():
		if child is Control:
			(child as Control).position = (child as Control).position.floor()

# 移進一個新的 CanvasLayer（擺在原本的位置），之後固定在畫面上、不跟著鏡頭跑
func _move_to_layer() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "%sLayer" % name
	layer.layer = _LAYERS[kind]
	layer.process_mode = process_mode
	parent.add_child(layer)
	reparent(layer, false)
