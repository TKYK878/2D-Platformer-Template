@tool
extends AnimatableBody2D

# 移動平台：會動，在起點跟指定距離外的終點之間移動，玩家站上去會被帶著走
#（AnimatableBody2D 內建這個行為，不用自己處理）。按鈕加這個零件就是電梯。
# 普通平台啟動後來回循環、關閉就停在原地；單向平台啟動後走到終點停下、關閉時回到起點。

## 普通平台：啟動後在起點終點之間來回循環，關閉就停在原地；單向平台：啟動後走到終點就停下，關閉時回到起點
@export_enum("普通平台", "單向平台") var platform_mode: int = 0

## 跟著訊號開關：收到啟動就動、收到關閉就停；啟動後永久開著：收到一次啟動之後，關閉的訊號都不理（配合只能按一次的按鈕）
@export_enum("跟著訊號開關", "啟動後永久開著") var activate_mode: int = 0

## 移動方向：水平或垂直
@export_enum("水平", "垂直") var direction: int = 0

## 來回移動的距離，單位是格（1 格 = 16 像素）
@export_range(1, 40) var distance_tiles: int = 3

## 移動速度（像素/秒）
@export_range(10.0, 300.0) var speed: float = 75.0

## 移動到兩端時減速：靠近起點、終點時慢下來，離開時再慢慢加速
@export var slow_at_ends: bool = false:
	set(value):
		slow_at_ends = value
		notify_property_list_changed()

## 離兩端還有幾格就開始減速，數字越大減速越平緩、越早開始慢下來（勾「兩端減速」才會顯示這一欄）
@export_range(0.5, 10.0, 0.5) var slow_distance: float = 1.5

## 一開始就在動
@export var start_active: bool = false

const _TILE_SIZE := 16.0
const _AXIS_HORIZONTAL := 0
const _MODE_LOOP := 0
const _MODE_ONE_WAY := 1
const _ACTIVATE_FOLLOW := 0
const _ACTIVATE_STAY_ON := 1
# 減速時最慢是原本速度的幾倍，不會完全停住（不然到了端點就出發不了）
const _SLOW_MIN_RATIO := 0.15

var _start_position: Vector2
var _end_position: Vector2
var _moving_to_end: bool = true
var _active: bool = true
var _stay_on: bool = false    # 「啟動後永久開著」已經啟動過了，之後不再關閉

# 沒勾「兩端減速」時隱藏減速範圍欄位
func _validate_property(property: Dictionary) -> void:
	if property.name == "slow_distance" and not slow_at_ends:
		property.usage = PROPERTY_USAGE_NONE

# 啟動平台：普通平台開始來回移動，單向平台往終點走；「啟動後永久開著」的話之後就不會再被關掉
func activate() -> void:
	_active = true
	if activate_mode == _ACTIVATE_STAY_ON:
		_stay_on = true

# 關閉平台：普通平台停在原地，單向平台回到起點；「啟動後永久開著」已經啟動過的話不理
func deactivate() -> void:
	if _stay_on:
		return
	_active = false

# 開著就關閉、關著就啟動
func toggle() -> void:
	if _active:
		deactivate()
	else:
		activate()

# 記錄起點跟終點，套用一開始要不要動；底下有皮就換上皮（平台沒有狀態變化，不用留著 SkinLink）
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	SkinLink.new(self, $Visual)
	_start_position = global_position
	var offset := distance_tiles * _TILE_SIZE
	var axis := Vector2.RIGHT if direction == _AXIS_HORIZONTAL else Vector2.DOWN
	_end_position = _start_position + axis * offset
	_active = false
	if start_active:
		activate()

# 回到起點、重新往終點方向走（重生處理者呼叫）。
# 動不動（activate／deactivate）是別的零件用訊號控制的，不在這裡重置，不然會跟控制它的按鈕對不上
func reset() -> void:
	global_position = _start_position
	_moving_to_end = true

# 依平台模式移動：普通平台開著時來回循環；單向平台開著往終點、關著往起點，到了就停
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if platform_mode == _MODE_ONE_WAY:
		var goal := _end_position if _active else _start_position
		if not global_position.is_equal_approx(goal):
			global_position = global_position.move_toward(goal, _current_speed() * delta)
		return
	if not _active:
		return
	var target := _end_position if _moving_to_end else _start_position
	global_position = global_position.move_toward(target, _current_speed() * delta)
	if global_position.is_equal_approx(target):
		_moving_to_end = not _moving_to_end

# 這一幀的移動速度：有勾「兩端減速」的話，離最近的端點越近越慢（最慢不低於 _SLOW_MIN_RATIO 倍）
func _current_speed() -> float:
	if not slow_at_ends:
		return speed
	var slow_px := slow_distance * _TILE_SIZE
	var to_end := minf(global_position.distance_to(_start_position), global_position.distance_to(_end_position))
	var ratio := clampf(to_end / slow_px, 0.0, 1.0)
	return speed * lerpf(_SLOW_MIN_RATIO, 1.0, ratio)


func _on_button_hold_turned_off() -> void:
	pass # Replace with function body.
