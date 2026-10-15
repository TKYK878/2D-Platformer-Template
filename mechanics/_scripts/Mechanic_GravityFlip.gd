extends MechanicBase

# 重力翻轉：依觸發時機翻轉重力方向，角色視覺同步上下翻轉。
# 拖進 Player → Mechanics 底下就能用，不用連任何線。

## 什麼時候會翻轉重力
@export_enum("按下按鍵", "落地時", "撞牆時") var trigger_timing: int = 0

## 按下按鍵時用鍵盤按鍵、滑鼠按鍵，還是 Input Map 動作（可以綁手把）（只有「觸發時機」選按下按鍵時才會顯示這一欄）
@export_enum("鍵盤按鍵", "滑鼠左鍵", "滑鼠右鍵", "滑鼠中鍵", "Input Map 動作") var input_type: int = 0

## 按下按鍵時要按哪一鍵翻轉（「觸發時機」選按下按鍵、「按鍵種類」選鍵盤按鍵時才會顯示這一欄）
@export var key: Key = KEY_SHIFT

## 「按鍵種類」選 Input Map 動作時，要聽哪一個動作（動作在「專案設定 → Input Map」裡加，可以綁手把等其他裝置）
@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin") var action: StringName = &""

## 翻轉之後多久內不能再翻轉
@export_range(0.1, 1.0) var cooldown: float = 0.3

## 重力翻轉之後發出
signal flipped

const _TRIGGER_KEY := 0
const _TRIGGER_LAND := 1
const _TRIGGER_WALL := 2

var _cooldown_left: float = 0.0

# input_type 的「Input Map 動作」選項
const _INPUT_MAP_ACTION := 4

# 依 trigger_timing 決定要不要顯示按鍵欄位；選滑鼠按鍵時也隱藏 key 欄位
func _validate_property(property: Dictionary) -> void:
	if property.name == "input_type" and trigger_timing != _TRIGGER_KEY:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "key" and (trigger_timing != _TRIGGER_KEY or input_type != 0):
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "action" and (trigger_timing != _TRIGGER_KEY or input_type != _INPUT_MAP_ACTION):
		property.usage = PROPERTY_USAGE_NONE

# 依觸發時機接對應的按鍵或 Player 訊號
func _on_setup() -> void:
	match trigger_timing:
		_TRIGGER_KEY:
			if input_type == 0:
				InputRouter.warn_if_dangerous_key(key, "[重力翻轉]")
			InputRouter.bind_input(self, input_type, key, InputRouter.PRESSED, _try_flip, 0, action)
		_TRIGGER_LAND:
			player.landed.connect(func(_impact_force): _try_flip())
		_TRIGGER_WALL:
			player.wall_hit.connect(_try_flip)

# 每幀倒數冷卻
func apply(ctx: MoveContext) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= ctx.delta

# 重生時角色視覺轉回正的、冷卻歸零（重力方向由 Player.revive() 復位）
func on_respawn() -> void:
	_cooldown_left = 0.0
	if player.visual:
		player.visual.scale.y = absf(player.visual.scale.y)

# 冷卻中不生效，否則翻轉重力、同步視覺上下翻轉、進入冷卻、發出 flipped 事件
func _try_flip() -> void:
	if _cooldown_left > 0.0:
		return
	player.flip_gravity()
	if player.visual:
		player.visual.scale.y *= -1
	_cooldown_left = cooldown
	flipped.emit()
	Events.mechanic_event.emit("Mechanic_GravityFlip", "flipped")
