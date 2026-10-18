@tool
extends Control

# 手機搖桿：拖進關卡就出現在畫面角落，手指按在圓圈裡往左右推，推多遠就走多快，不用連任何線。
# 往上、下推超過一半，會按住上、下（關掉 use_up_down 就只管左右）。
# 想拿來取代手機按鈕套件的左右鍵：套件開「可編輯的子節點」，把 Left、Right 的「可見」取消勾。
# 遊戲開始時如果不在 CanvasLayer 底下（例如直接拖進關卡），會自己移進一個，固定在畫面上、不跟著鏡頭跑。

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
## 搖桿的圓圈多大（直徑，像素）
@export_range(32, 160) var stick_size: int = 72:
	set(value):
		stick_size = value
		_place()
## 看起來多透明，越小越透明（推的時候會變清楚一點）
@export_range(0.1, 1.0) var opacity: float = 0.5:
	set(value):
		opacity = value
		queue_redraw()
## 推不到這個比例就當作沒推（0.2＝推不到兩成不會動），手指放在中間時角色才不會一直慢慢走
@export_range(0.0, 0.8) var dead_zone: float = 0.2
## 往上、下推的時候要不要按住上、下
@export var use_up_down: bool = true
## 什麼時候顯示：只在手機、平板這類觸控裝置；一直顯示（在電腦上可以用滑鼠拖來測）；
## 或摸到螢幕才出現（手指碰到螢幕就出現、改按鍵盤又藏起來，有觸控螢幕的筆電用鍵盤玩也不會擋畫面）
@export_enum("只在觸控裝置", "一直顯示", "摸到螢幕才出現") var show_on: int = 0

const _BUTTON_SCRIPT := preload("res://ui/_scripts/TouchButton.gd")
const _LEFT := &"move_left"
const _RIGHT := &"move_right"
const _UP := &"move_up"
const _DOWN := &"move_down"
# 上、下要推超過這個比例才算
const _UP_DOWN_PUSH := 0.5
const _LAYER := 5
const _NO_TOUCH := -1
const _MOUSE := -2
const _DOWN_OPACITY := 0.3
const _BASE_COLOR := Color(0.1, 0.1, 0.15, 0.6)
const _KNOB_COLOR := Color(0.45, 0.45, 0.55, 0.9)
const _LINE_COLOR := Color(1, 1, 1, 0.9)
const _KNOB_RATIO := 0.4

var _hidden_by_student: bool = false   # 學員自己把「可見」取消勾
var _touch: int = _NO_TOUCH   # 按著搖桿的是哪根手指（_MOUSE 是滑鼠），沒人按是 _NO_TOUCH
var _push: Vector2 = Vector2.ZERO   # 推的方向和程度，長度 0～1
var _held: Dictionary = {}   # 搖桿自己按住的動作，放開時只放這些（不會把鍵盤按著的一起放掉）

# 擺到角落；遊戲中檢查要不要顯示、移進 CanvasLayer
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
	_BUTTON_SCRIPT.print_hidden_reason(show_on, name)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for action in [_LEFT, _RIGHT, _UP, _DOWN]:
		if not InputMap.has_action(action):
			var message := "Input Map 裡找不到「%s」，搖桿往這個方向推不會有反應：到「專案設定 → Input Map」把它加回來" % action
			push_warning("[%s] %s" % [name, message])
			printerr("⚠ [%s] %s" % [name, message])
	get_viewport().size_changed.connect(_place)
	if not (get_parent() is CanvasLayer or get_parent() is Control):
		_move_to_layer.call_deferred()

# 照 show_on 和玩家現在用什麼裝置，決定要不要顯示（學員自己把「可見」取消勾的就一直藏著）
func _refresh_shown() -> void:
	visible = not _hidden_by_student and TouchSettings.should_show(show_on)

# 離開場景、遊戲暫停、被藏起來時放開，不然角色會一直走
func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED:
		if _touch != _NO_TOUCH and (what != NOTIFICATION_VISIBILITY_CHANGED or not is_visible_in_tree()):
			_release()

# 手指（或滑鼠左鍵）按在圓圈裡就抓住搖桿，之後滑到哪都跟著推，放開才放掉
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch == _NO_TOUCH and _hit(touch.position):
				_touch = touch.index
				_push_to(touch.position)
				get_viewport().set_input_as_handled()
		elif touch.index == _touch:
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch:
			_push_to(drag.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			if _touch == _NO_TOUCH and _hit(click.position):
				_touch = _MOUSE
				_push_to(click.position)
				get_viewport().set_input_as_handled()
		elif _touch == _MOUSE:
			_release()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _touch == _MOUSE:
			_push_to((event as InputEventMouseMotion).position)

# 圓圈正中間在畫面上的位置
func _center() -> Vector2:
	return get_global_transform_with_canvas().origin + size / 2.0

# 這個畫面上的點有沒有在圓圈裡
func _hit(at: Vector2) -> bool:
	return at.distance_to(_center()) <= stick_size / 2.0

# 手指在這個位置：算出推的方向和程度（超出圓圈算推到底），按住對應的方向
func _push_to(at: Vector2) -> void:
	_push = ((at - _center()) / (stick_size / 2.0)).limit_length(1.0)
	_apply()
	queue_redraw()

# 放開搖桿：回到中間，四個方向都放開
func _release() -> void:
	_touch = _NO_TOUCH
	_push = Vector2.ZERO
	_apply()
	queue_redraw()

# 依推的程度按住左右（推多遠就多用力）和上下（推超過一半才算）
func _apply() -> void:
	var amount := 0.0
	if absf(_push.x) > dead_zone:
		amount = (absf(_push.x) - dead_zone) / (1.0 - dead_zone)
	_hold(_RIGHT, amount if _push.x > 0.0 else 0.0)
	_hold(_LEFT, amount if _push.x < 0.0 else 0.0)
	var up_down := use_up_down and absf(_push.y) > maxf(dead_zone, _UP_DOWN_PUSH)
	_hold(_DOWN, 1.0 if up_down and _push.y > 0.0 else 0.0)
	_hold(_UP, 1.0 if up_down and _push.y < 0.0 else 0.0)

# 用某個力道按住一個動作，力道 0 就放開（只放搖桿自己按住的）
func _hold(action: StringName, strength: float) -> void:
	if not InputMap.has_action(action):
		return
	if strength > 0.0:
		Input.action_press(action, strength)
		_held[action] = true
	elif _held.has(action):
		Input.action_release(action)
		_held.erase(action)

# 依角落和距離擺到畫面上（編輯器裡照專案設定的畫面大小擺）
func _place() -> void:
	if not is_inside_tree():
		return
	var screen := _screen_size()
	var at := Vector2(distance_x, distance_y)
	if corner == 1 or corner == 3:
		at.x = screen.x - distance_x - stick_size
	if corner == 0 or corner == 1:
		at.y = screen.y - distance_y - stick_size
	size = Vector2(stick_size, stick_size)
	position = at.round()
	queue_redraw()

# 畫面多大：遊戲中用實際看得到的範圍，編輯器裡用專案設定的大小
func _screen_size() -> Vector2:
	if Engine.is_editor_hint():
		return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	return get_viewport().get_visible_rect().size

# 畫底下的圓圈和中間的圓鈕，圓鈕跟著推的方向移動
func _draw() -> void:
	var alpha := minf(1.0, opacity + (_DOWN_OPACITY if _touch != _NO_TOUCH else 0.0))
	var radius := size.x / 2.0
	var center := size / 2.0
	var line := Color(_LINE_COLOR, _LINE_COLOR.a * alpha)
	draw_circle(center, radius, Color(_BASE_COLOR, _BASE_COLOR.a * alpha))
	draw_arc(center, radius - 0.5, 0.0, TAU, 48, line, 1.0)
	var knob := center + _push * radius * (1.0 - _KNOB_RATIO)
	draw_circle(knob, radius * _KNOB_RATIO, Color(_KNOB_COLOR, _KNOB_COLOR.a * alpha))
	draw_arc(knob, radius * _KNOB_RATIO - 0.5, 0.0, TAU, 32, line, 1.0)

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
