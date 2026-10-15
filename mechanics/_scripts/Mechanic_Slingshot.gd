extends MechanicBase

# 只能用滑鼠控制：鍵盤移動完全鎖住，按住拖曳鍵（預設滑鼠左鍵）移動滑鼠瞄準，像彈弓一樣
# 放開往反方向射出去。拖進 Player → Mechanics 底下就能用，不用連任何線。

## 用哪一種按鍵拖曳；選鍵盤按鍵時，按住那顆鍵移動滑鼠瞄準，放開發射
@export_enum("鍵盤按鍵", "滑鼠左鍵", "滑鼠右鍵", "滑鼠中鍵", "Input Map 動作") var input_type: int = 1

## 拖曳鍵（「按鍵種類」選鍵盤按鍵時才會顯示這一欄）
@export var key: Key = KEY_E

## 「按鍵種類」選 Input Map 動作時，要聽哪一個動作（動作在「專案設定 → Input Map」裡加，可以綁手把等其他裝置）
@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin") var action: StringName = &""

## 拖到最遠時發射的力道上限
@export_range(200.0, 1200.0) var max_launch_force: float = 700.0

## 拖曳超過這個距離，力道就不會再增加
@export_range(50.0, 300.0) var max_drag_distance: float = 150.0

## 開啟後只有站在地面上才能開始拖曳瞄準
@export var ground_only: bool = true

## 拖曳時要不要畫出瞄準線
@export var show_aim_line: bool = true

## 開始拉的那一刻發出（例如連到 Player 的 stop_motion，拉的時候速度歸零）
signal drag_started
## 放開、要射出去的那一刻發出，在推力之前（連到 Player 的 stop_motion 就是先歸零再射）；拉的距離是 0 也會發出
signal launched

# 拖曳鍵用較高優先權向 InputRouter 註冊，跟其他綁同一顆鍵的組件同時存在時彈弓先收到
const _PRIORITY := 100

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _aim_line: Line2D

# input_type 的「Input Map 動作」選項
const _INPUT_MAP_ACTION := 4

# 選滑鼠按鍵時隱藏 key 欄位
func _validate_property(property: Dictionary) -> void:
	if property.name == "key" and input_type != 0:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "action" and input_type != _INPUT_MAP_ACTION:
		property.usage = PROPERTY_USAGE_NONE

# 向 InputRouter 註冊拖曳鍵的按下／放開；show_aim_line 開啟時自己生成一條瞄準線，學員不用擺
func _on_setup() -> void:
	if input_type == 0:
		InputRouter.warn_if_dangerous_key(key, "[彈弓]")
	InputRouter.bind_input(self, input_type, key, InputRouter.PRESSED, _on_drag_pressed, _PRIORITY, action)
	InputRouter.bind_input(self, input_type, key, InputRouter.RELEASED, _on_drag_released, _PRIORITY, action)
	if not show_aim_line:
		return
	_aim_line = Line2D.new()
	_aim_line.width = 2.0
	_aim_line.default_color = Color(1.0, 1.0, 1.0, 0.8)
	_aim_line.visible = false
	add_child(_aim_line)

# 按下拖曳鍵：開始拖曳（ground_only 開啟時要先站在地面上）；沒開始拖曳就不攔截，讓其他組件收到
func _on_drag_pressed() -> bool:
	if ground_only and not player.is_on_ground():
		return false
	_dragging = true
	_drag_start = player.get_global_mouse_position()
	drag_started.emit()
	return true

# 放開拖曳鍵：正在拖曳才發射並攔截，否則讓其他組件收到
func _on_drag_released(_seconds: float) -> bool:
	if not _dragging:
		return false
	_release()
	return true

# 鍵盤全鎖住；拖曳中同步更新瞄準線
func apply(ctx: MoveContext) -> void:
	ctx.input_locked = true

	if _dragging and _aim_line:
		var drag: Vector2 = player.get_global_mouse_position() - _drag_start
		drag = drag.limit_length(max_drag_distance)
		_aim_line.visible = true
		_aim_line.points = PackedVector2Array([Vector2.ZERO, -drag])

# 重生時取消拖曳中的狀態、藏起瞄準線
func on_respawn() -> void:
	_dragging = false
	if _aim_line:
		_aim_line.visible = false

# 放開拖曳鍵：往拖曳的反方向發射，力道依拖曳距離比例縮放。launched 一定在推力之前發出，
# 拉的距離是 0 也發，學員用 drag_started 凍住、launched 解凍時才不會卡在空中
func _release() -> void:
	_dragging = false
	if _aim_line:
		_aim_line.visible = false
	var drag: Vector2 = player.get_global_mouse_position() - _drag_start
	drag = drag.limit_length(max_drag_distance)
	var ratio := drag.length() / max_drag_distance
	launched.emit()
	if ratio <= 0.0:
		return
	var direction := -drag.normalized()
	player.add_impulse(direction * max_launch_force * ratio)
	Events.mechanic_event.emit("Mechanic_Slingshot", "launched")
