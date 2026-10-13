extends AnimatableBody2D

# 移動平台：會動，在起點跟指定距離外的終點之間來回移動，玩家站上去會被帶著走
#（AnimatableBody2D 內建這個行為，不用自己處理）。按鈕加這個零件就是電梯。

## 移動方向：水平或垂直
@export_enum("水平", "垂直") var direction: int = 0

## 來回移動的距離，單位是格（1 格 = 16 像素）
@export_range(1, 20) var distance_tiles: int = 3

## 移動速度（像素/秒）
@export_range(10.0, 300.0) var speed: float = 60.0

## 一開始就在動
@export var start_active: bool = true

const _TILE_SIZE := 16.0
const _AXIS_HORIZONTAL := 0

var _start_position: Vector2
var _end_position: Vector2
var _moving_to_end: bool = true
var _active: bool = true

## 開始移動
func activate() -> void:
	_active = true

## 停在原地（保持目前位置，不會跳回起點）
func deactivate() -> void:
	_active = false

## 切換
func toggle() -> void:
	_active = not _active

# 記錄起點跟終點，套用一開始要不要動；底下有皮就換上皮（平台沒有狀態變化，不用留著 SkinLink）
func _ready() -> void:
	SkinLink.new(self, $Visual)
	_start_position = global_position
	var offset := distance_tiles * _TILE_SIZE
	var axis := Vector2.RIGHT if direction == _AXIS_HORIZONTAL else Vector2.DOWN
	_end_position = _start_position + axis * offset
	_active = start_active

# 回到起點、重新往終點方向走（重生處理者呼叫）。
# 動不動（activate／deactivate）是別的零件用訊號控制的，不在這裡重置，不然會跟控制它的按鈕對不上
func reset() -> void:
	global_position = _start_position
	_moving_to_end = true

# 在起點終點之間來回移動
func _physics_process(delta: float) -> void:
	if not _active:
		return
	var target := _end_position if _moving_to_end else _start_position
	global_position = global_position.move_toward(target, speed * delta)
	if global_position.is_equal_approx(target):
		_moving_to_end = not _moving_to_end
