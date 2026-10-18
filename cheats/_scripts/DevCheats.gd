extends CanvasLayer

# 開發熱鍵：給自己測關卡用，拖進關卡就能用，不用設定任何東西。
# 按 `（鍵盤左上角、Tab 上面那顆）打開清單，清單開著時按 1～9、-、= 開關各種作弊，清單上會標出哪些開著。
# 不用 F 鍵（遊戲嵌在編輯器裡跑時可能被編輯器快捷鍵吃掉），也不用 0（Juice 總開關）。
# editor_only 勾著（預設）的話只在編輯器按 Play 時有效，匯出成網頁版、執行檔給別人玩時自動失效，不用記得拔掉。
# 底下的功能其實是幾個「只當接口」的 Cheat，開場自己建出來（不存進場景）。

## 只在編輯器按 Play 時有效：匯出的遊戲裡開發熱鍵自動失效。取消勾的話匯出的遊戲也能用（玩家也按得到）
@export var editor_only: bool = true

const _OPEN_KEY := KEY_QUOTELEFT
const _CHEAT_SCENE := preload("res://cheats/Cheat.tscn")
# [按鍵, 按鍵上的字, 要勾的設定]
const _ENTRIES := [
	[KEY_1, "1", {"no_death": true}],
	[KEY_2, "2", {"fly": true, "pass_walls": true}],
	[KEY_3, "3", {"infinite_jump": true}],
	[KEY_4, "4", {"change_speed": true, "game_speed": 0.5}],
	[KEY_5, "5", {"freeze_enemies": true}],
	[KEY_6, "6", {"zoom_out": true}],
	[KEY_7, "7", {"go_to_room": 1}],
	[KEY_8, "8", {"go_to_room": 2}],
	[KEY_9, "9", {"save_here": true}],
	[KEY_MINUS, "-", {"add_value": true, "value_kind": 2, "fill_up": true}],
	[KEY_EQUAL, "=", {"clear_level": true}],
]

var _cheats: Array[Node] = []
var _panel: PanelContainer = null
var _list: Label = null
var _hint: Label = null

# 編輯器裡按 Play 才建出作弊與畫面；匯出的遊戲裡（editor_only 勾著）什麼都不做
func _ready() -> void:
	layer = 31
	if editor_only and not OS.has_feature("editor"):
		return
	for entry in _ENTRIES:
		var cheat: Node = _CHEAT_SCENE.instantiate()
		cheat.name = "DevCheat_%s" % entry[1]
		cheat.unlock_by = cheat.UNLOCK_SIGNAL
		cheat.show_label = false
		cheat.quiet = true
		var settings: Dictionary = entry[2]
		for key in settings:
			cheat.set(key, settings[key])
		add_child(cheat)
		_cheats.append(cheat)
		cheat.turned_on.connect(_refresh)
		cheat.turned_off.connect(_refresh)
	_build_screen()
	print("[開發熱鍵] 按 `（Tab 上面那顆鍵）打開開發熱鍵清單")

# 按 ` 打開／關掉清單；清單開著時按數字鍵開關作弊（這個鍵就不再傳給遊戲）
func _input(event: InputEvent) -> void:
	if _cheats.is_empty() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = (event as InputEventKey).physical_keycode
	if key == _OPEN_KEY:
		_panel.visible = not _panel.visible
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if not _panel.visible:
		return
	for i in _ENTRIES.size():
		if _ENTRIES[i][0] == key:
			_cheats[i].toggle()
			_refresh()
			get_viewport().set_input_as_handled()
			return

# 建出右上角的清單與右下角的小提示
func _build_screen() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -4.0
	_panel.offset_right = -4.0
	_panel.offset_top = 4.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	style.set_content_margin_all(6.0)
	_panel.add_theme_stylebox_override("panel", style)
	_list = _make_label(10)
	_panel.add_child(_list)
	_panel.visible = false
	add_child(_panel)
	_hint = _make_label(8)
	_hint.text = "` 開發熱鍵"
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_left = -4.0
	_hint.offset_right = -4.0
	_hint.offset_top = -2.0
	_hint.offset_bottom = -2.0
	_hint.modulate.a = 0.6
	add_child(_hint)
	_refresh()

# 建一個有黑邊的小字
func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# 更新清單：每一行「按鍵 功能」，開著的標「● 開」；清單關著時右下角提示有開著的作弊
func _refresh() -> void:
	if _list == null:
		return
	var lines := PackedStringArray(["開發熱鍵（按 ` 關掉）"])
	var on_count := 0
	for i in _ENTRIES.size():
		var cheat: Node = _cheats[i]
		var mark := ""
		if cheat.is_on():
			mark = "  ● 開"
			on_count += 1
		lines.append("%s　%s%s" % [_ENTRIES[i][1], cheat.get_menu_text().trim_prefix("作弊："), mark])
	_list.text = "\n".join(lines)
	_hint.text = "` 開發熱鍵" if on_count == 0 else "` 開發熱鍵（%d 個開著）" % on_count
