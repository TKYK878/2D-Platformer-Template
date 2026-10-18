@tool
extends Control

# 手機按鈕：拖進關卡就出現在畫面角落，手指按住就等於那個鍵按住，不用連任何線。
# 角色移動、跳躍、能力、機制卡都是問「這個鍵有沒有按著」，所以手機按鈕假裝按鍵，其他地方都不用改。
# 遊戲開始時如果不在 CanvasLayer 底下（例如直接拖進關卡），會自己移進一個，固定在畫面上、不跟著鏡頭跑。
# 好幾根手指可以同時按不同按鈕；手指按著從一顆滑到另一顆，會換成按另一顆（暫停鈕要直接點）。

## 這顆按鈕代表哪個鍵
@export_enum("左", "右", "上", "下", "跳", "暫停", "鍵盤按鍵") var press: int = 4:
	set(value):
		press = value
		notify_property_list_changed()
		update_configuration_warnings()
		queue_redraw()
## 要假裝按哪個鍵（「代表」選鍵盤按鍵時才會顯示這一欄），能力、機制卡用的鍵選一樣的就按得到
@export var key: Key = KEY_F:
	set(value):
		key = value
		update_configuration_warnings()
		queue_redraw()
## 放在畫面哪個角落
@export_enum("左下", "右下", "左上", "右上") var corner: int = 0:
	set(value):
		corner = value
		_place()
## 離角落左右多遠（像素）
@export_range(0, 240) var distance_x: int = 8:
	set(value):
		distance_x = value
		_place()
## 離角落上下多遠（像素）
@export_range(0, 135) var distance_y: int = 8:
	set(value):
		distance_y = value
		_place()
## 按鈕多大（像素），手指按得到大概要 32 以上
@export_range(16, 96) var button_size: int = 40:
	set(value):
		button_size = value
		_place()
## 看起來多透明，越小越透明（按下去時會變清楚一點）
@export_range(0.1, 1.0) var opacity: float = 0.5:
	set(value):
		opacity = value
		queue_redraw()
## 什麼時候顯示：只在手機、平板這類觸控裝置；一直顯示（在電腦上可以用滑鼠點來測）；
## 或摸到螢幕才出現（手指碰到螢幕就出現、改按鍵盤又藏起來，有觸控螢幕的筆電用鍵盤玩也不會擋畫面）
@export_enum("只在觸控裝置", "一直顯示", "摸到螢幕才出現") var show_on: int = 0
## 按鈕的圖：從檔案系統把圖片拖進來；空白就畫預設的圓角框＋箭頭或字
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

const PRESS_JUMP := 4
const PRESS_PAUSE := 5
const PRESS_KEY := 6
# 左、右、上、下、跳對應的 Input Map 動作
const _ACTIONS := [&"move_left", &"move_right", &"move_up", &"move_down", &"jump"]
const _LAYER := 5
const _NO_TOUCH := -1
const _MOUSE := -2
const _FONT_SIZE := 12
const _DOWN_OPACITY := 0.3
const _BOX_COLOR := Color(0.1, 0.1, 0.15, 0.8)
const _BOX_DOWN_COLOR := Color(0.45, 0.45, 0.55, 0.9)
const _LINE_COLOR := Color(1, 1, 1, 0.9)

var _hidden_by_student: bool = false   # 學員自己把「可見」取消勾
var _touch: int = _NO_TOUCH   # 按著這顆的是哪根手指（_MOUSE 是滑鼠），沒人按是 _NO_TOUCH

# 擺到角落；遊戲中檢查要不要顯示、移進 CanvasLayer、設定暫停時要不要繼續收輸入
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_place()
	if Engine.is_editor_hint():
		set_process_input(false)
		return
	_hidden_by_student = not visible
	TouchSettings.changed.connect(_refresh_shown)
	_refresh_shown()
	print_hidden_reason(show_on, name)
	process_mode = Node.PROCESS_MODE_ALWAYS if press == PRESS_PAUSE else Node.PROCESS_MODE_PAUSABLE
	if press < PRESS_PAUSE and not InputMap.has_action(_ACTIONS[press]):
		var message := "Input Map 裡找不到「%s」，這顆按鈕按了不會有反應：到「專案設定 → Input Map」把它加回來" % _ACTIONS[press]
		push_warning("[%s] %s" % [name, message])
		printerr("⚠ [%s] %s" % [name, message])
	get_viewport().size_changed.connect(_place)
	if not (get_parent() is CanvasLayer or get_parent() is Control):
		_move_to_layer.call_deferred()

# 照 show_on 和玩家現在用什麼裝置，決定要不要顯示（學員自己把「可見」取消勾的就一直藏著）
func _refresh_shown() -> void:
	visible = not _hidden_by_student and TouchSettings.should_show(show_on)

# 一開始藏起來的話，在輸出面板說為什麼；套件、搖桿也用這個
static func print_hidden_reason(choice: int, label: String) -> void:
	if TouchSettings.should_show(choice):
		return
	if TouchSettings.mode == TouchSettings.MODE_HIDE:
		print("[%s] 玩家在手機按鈕開關選了「隱藏」，先藏起來（設定存在設定檔，選「自動」或「顯示」就會回來）" % label)
	elif choice == TouchSettings.SHOW_AUTO:
		print("[%s] 選了「摸到螢幕才出現」：手指碰到螢幕才會顯示（想在電腦上測，把 show_on 改成「一直顯示」）" % label)
	else:
		print("[%s] 這台裝置沒有觸控螢幕，先藏起來（想在電腦上測，把 show_on 改成「一直顯示」）" % label)

# 離開場景、遊戲暫停（暫停鈕以外）、被藏起來時，按著的鍵要放開，不然角色會一直走
func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED:
		if _touch != _NO_TOUCH and (what != NOTIFICATION_VISIBILITY_CHANGED or not is_visible_in_tree()):
			_release()

# 選鍵盤按鍵以外的時候隱藏 key 欄位
func _validate_property(property: Dictionary) -> void:
	if property.name == "key" and press != PRESS_KEY:
		property.usage = PROPERTY_USAGE_NONE

# 編輯器裡的黃色驚嘆號：選了鍵盤按鍵卻沒選是哪個鍵
func _get_configuration_warnings() -> PackedStringArray:
	if press == PRESS_KEY and key == KEY_NONE:
		return PackedStringArray(["「代表」選了鍵盤按鍵，但 key 還沒選是哪個鍵，按了不會有反應"])
	return PackedStringArray()

# 手指（或滑鼠左鍵）按下、滑動、放開：按在這顆上面就按住，離開或放開就放開
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch == _NO_TOUCH and _hit(touch.position):
				_press(touch.index)
				get_viewport().set_input_as_handled()
		elif touch.index == _touch:
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_on_slide(drag.index, drag.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			if _touch == _NO_TOUCH and _hit(click.position):
				_press(_MOUSE)
				get_viewport().set_input_as_handled()
		elif _touch == _MOUSE:
			_release()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_on_slide(_MOUSE, motion.position)

# 按著滑動：按著這顆的手指滑出去就放開；別的手指按著滑進來就換按這顆（暫停鈕不算）
func _on_slide(index: int, at: Vector2) -> void:
	if index == _touch:
		if not _hit(at):
			_release()
	elif _touch == _NO_TOUCH and press != PRESS_PAUSE and _hit(at):
		_press(index)

# 這個畫面上的點有沒有在按鈕上
func _hit(at: Vector2) -> bool:
	var origin := get_global_transform_with_canvas().origin
	return Rect2(origin, size).has_point(at)

# 按下：記住是哪根手指，假裝按下那個鍵
func _press(index: int) -> void:
	_touch = index
	_send(true)
	queue_redraw()

# 放開：假裝放開那個鍵
func _release() -> void:
	_touch = _NO_TOUCH
	_send(false)
	queue_redraw()

# 依「代表」送出按下或放開：移動和跳躍按住 Input Map 動作，暫停送一下 Esc，鍵盤按鍵送那個鍵
func _send(down: bool) -> void:
	if press == PRESS_PAUSE:
		if down:
			_send_key(KEY_ESCAPE, true)
			_send_key(KEY_ESCAPE, false)
	elif press == PRESS_KEY:
		if key != KEY_NONE:
			_send_key(key, down)
	elif InputMap.has_action(_ACTIONS[press]):
		if down:
			Input.action_press(_ACTIONS[press])
		else:
			Input.action_release(_ACTIONS[press])

# 假裝鍵盤上的某個鍵被按下或放開
func _send_key(which: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = which
	event.physical_keycode = which
	event.pressed = down
	TouchSettings.expect_fake_key(which)
	Input.parse_input_event(event)

# 依角落和距離擺到畫面上（編輯器裡照專案設定的畫面大小擺）
func _place() -> void:
	if not is_inside_tree():
		return
	var screen := _screen_size()
	var side := Vector2(button_size, button_size)
	var at := Vector2(distance_x, distance_y)
	if corner == 1 or corner == 3:
		at.x = screen.x - distance_x - button_size
	if corner == 0 or corner == 1:
		at.y = screen.y - distance_y - button_size
	size = side
	position = at.round()
	queue_redraw()

# 畫面多大：遊戲中用實際看得到的範圍，編輯器裡用專案設定的大小
func _screen_size() -> Vector2:
	if Engine.is_editor_hint():
		return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	return get_viewport().get_visible_rect().size

# 畫按鈕：有圖就畫圖（按下時變暗），沒圖就畫圓角框＋箭頭、暫停符號或字
func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var down := _touch != _NO_TOUCH
	var alpha := minf(1.0, opacity + (_DOWN_OPACITY if down else 0.0))
	if texture != null:
		draw_texture_rect(texture, rect, false, Color(0.7, 0.7, 0.7, alpha) if down else Color(1, 1, 1, alpha))
		return
	var line := Color(_LINE_COLOR, _LINE_COLOR.a * alpha)
	var fill := _BOX_DOWN_COLOR if down else _BOX_COLOR
	var box := StyleBoxFlat.new()
	box.bg_color = Color(fill, fill.a * alpha)
	box.border_color = line
	box.set_border_width_all(1)
	box.set_corner_radius_all(int(size.x / 4.0))
	draw_style_box(box, rect)
	var center := size / 2.0
	var half := size.x * 0.2
	match press:
		0:
			draw_colored_polygon(PackedVector2Array([center + Vector2(-half, 0), center + Vector2(half, -half), center + Vector2(half, half)]), line)
		1:
			draw_colored_polygon(PackedVector2Array([center + Vector2(half, 0), center + Vector2(-half, -half), center + Vector2(-half, half)]), line)
		2:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -half), center + Vector2(half, half), center + Vector2(-half, half)]), line)
		3:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, half), center + Vector2(half, -half), center + Vector2(-half, -half)]), line)
		PRESS_PAUSE:
			var bar := Vector2(maxf(2.0, half * 0.5), half * 2.0)
			draw_rect(Rect2(center + Vector2(-half * 0.6 - bar.x / 2.0, -half), bar), line)
			draw_rect(Rect2(center + Vector2(half * 0.6 - bar.x / 2.0, -half), bar), line)
		_:
			_draw_label("跳" if press == PRESS_JUMP else OS.get_keycode_string(key), line)

# 在按鈕正中間寫一行字
func _draw_label(text: String, color: Color) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var y := (size.y - font.get_height(_FONT_SIZE)) / 2.0 + font.get_ascent(_FONT_SIZE)
	draw_string(font, Vector2(0, roundf(y)), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, _FONT_SIZE, color)

# 移進一個新的 CanvasLayer，之後固定在畫面上、不跟著鏡頭跑
func _move_to_layer() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "%sLayer" % name
	layer.layer = _LAYER
	layer.process_mode = process_mode
	parent.add_child(layer)
	reparent(layer, false)
	_place()
