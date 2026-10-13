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
## 配色：字、底色、按鈕、條的顏色一起換
@export_enum("預設", "暗色", "亮色", "復古綠", "糖果") var palette: int = PALETTE_DEFAULT:
	set(value):
		palette = value
		_apply_theme()
## 風格：按鈕、條、底框的形狀（像素復古＝方角、乾淨極簡＝細外框、可愛圓角＝圓角加厚底邊），顏色照 palette
@export_enum("像素復古", "乾淨極簡", "可愛圓角") var style: int = STYLE_PIXEL:
	set(value):
		style = value
		_apply_theme()

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
## 一行小字，例如「跳過 100 根尖刺，你做得到嗎？」（這一格可以打字）：填了就蓋掉範本裡 Hook 的字；空白就用範本裡原本的字
@export var hook: String = "":
	set(value):
		hook = value
		_apply_title()

const KIND_HUD := 0
const KIND_PAUSE_MENU := 1
const KIND_CLEAR_SCREEN := 2
const KIND_TITLE := 3

const PALETTE_DEFAULT := 0

const STYLE_PIXEL := 0
const STYLE_CLEAN := 1
const STYLE_CUTE := 2

# 每種風格的底框九宮格圖（灰階，遊戲中依配色的 panel 顏色上色；學員可以照同樣的格子重畫）、四邊各 8 像素不拉伸
const _PANEL_TEXTURES := [
	preload("res://ui/styles/Panel_Pixel.png"),
	preload("res://ui/styles/Panel_Clean.png"),
	preload("res://ui/styles/Panel_Cute.png"),
]
const _PANEL_PATCH := 8
# 每種風格底框裡面的留白（左右、上下）
const _PANEL_MARGINS := [Vector2(12, 8), Vector2(16, 12), Vector2(14, 10)]
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
const TITLE_NOT_ALONE := "標題畫面要自己一個場景（設為主場景），不能放進關卡；從 ui/templates/ 再製一份到 _my/，右鍵「設為主場景」"

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
]

# 套用配色與字型、決定暫停時能不能動；學員的同一種畫面已經有一個的話自己刪掉並警告；
# 暫停選單、過關畫面先藏起來，等暫停、過關時才出現；遊戲中不在 CanvasLayer 底下的話移進一個
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_process_mode()
	_apply_theme()
	_apply_title()
	if Engine.is_editor_hint():
		return
	_snap_containers(self)
	if kind == KIND_TITLE:
		_ready_title()
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
		return
	push_warning("[%s] %s" % [name, TITLE_NOT_ALONE])
	printerr("⚠ [%s] %s" % [name, TITLE_NOT_ALONE])
	queue_free()

# theme 由欄位自動產生：不存進場景檔、Inspector 也不顯示，學員改字型配色用上面的欄位；
# 標題畫面的欄位只在標題畫面顯示
func _validate_property(property: Dictionary) -> void:
	if property.name == "theme":
		property.usage = PROPERTY_USAGE_NONE
	elif _TITLE_NODES.has(property.name) and kind != KIND_TITLE:
		property.usage = PROPERTY_USAGE_NO_EDITOR

# 這套 UI 放進關卡時（不是單獨編輯它的時候），把底下顯示零件的設定錯誤收集起來顯示在這裡：
# 放進關卡的場景看不到裡面的子節點，錯誤要掛在看得到的這一層
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_inside_tree():
		return warnings
	var scene_root := get_tree().edited_scene_root
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
	if art != null and key_art != null:
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

# 現在用的這套顏色：「預設」配色配像素復古以外的風格時用中性色
func _colors() -> Dictionary:
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
	theme = t
	_notify_children(self)

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

# 選單的底框（Panel、PanelContainer）：用這個風格的九宮格圖，依配色上色（「預設」配色是深色半透明）；四周留白讓字不貼邊
func _add_panel(t: Theme, c: Dictionary) -> void:
	var box := StyleBoxTexture.new()
	box.texture = _PANEL_TEXTURES[style]
	box.set_texture_margin_all(_PANEL_PATCH)
	box.modulate_color = c.get("panel", _DEFAULT_PANEL)
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
	return box

# 條和拉桿的方框：可愛圓角時是圓的，其他風格方角
func _bar_box(color: Color, margin: int = 4) -> StyleBoxFlat:
	var box := _box(color, margin)
	if style == STYLE_CUTE:
		box.set_corner_radius_all(3)
		box.anti_aliasing = false
	return box

# 只有外框的方框，按鈕被選到（用鍵盤操作）時用；可愛圓角時也是圓角
func _outline(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_border_width_all(1)
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
