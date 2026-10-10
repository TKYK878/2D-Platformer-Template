extends MechanicBase

# 二段跳：離地後還能再跳 extra_jumps 次，落地會重新補滿。備品庫卡，不在抽卡池裡，
# 學員許願才拖給他。拖進 Player → Mechanics 底下就能用，不用連任何線。

## 離地後最多能再跳幾次
@export_range(1, 3) var extra_jumps: int = 1

## 空中跳的力道，是一般跳躍的幾倍
@export_range(0.3, 1.5) var jump_scale: float = 1.0

## 在空中再跳一次的那一刻發出，在起跳之前
signal air_jumped

const _PRIORITY := 100

var _jumps_left: int = 0

# 用比 Player 預設跳躍高的優先權攔截跳躍鍵
func _on_setup() -> void:
	InputRouter.bind(self, "jump", InputRouter.PRESSED, _on_jump_pressed, _PRIORITY)

# 站在地面上就把空中跳的次數補滿
func apply(_ctx: MoveContext) -> void:
	if player.is_on_ground():
		_jumps_left = extra_jumps

# 重生時空中跳的次數補滿
func on_respawn() -> void:
	_jumps_left = extra_jumps

# 地面上（含剛走出平台邊緣還能跳的那一下）不攔截，讓 Player 自己的跳躍照常運作；空中還有次數就跳一次並扣一次
func _on_jump_pressed() -> bool:
	if player.can_ground_jump() or _jumps_left <= 0:
		return false
	_jumps_left -= 1
	air_jumped.emit()
	player.force_jump(jump_scale)
	Events.mechanic_event.emit("Extra_DoubleJump", "jumped")
	return true
