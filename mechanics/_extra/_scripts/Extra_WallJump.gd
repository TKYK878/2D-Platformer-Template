extends MechanicBase

# 蹬牆跳：貼著牆壁在空中時按跳躍鍵，會往牆壁反方向蹬出去並往上跳。備品庫卡，
# 不在抽卡池裡，學員許願才拖給他。拖進 Player → Mechanics 底下就能用，不用連任何線。

## 蹬牆跳的橫向力道
@export_range(150.0, 600.0) var push_force: float = 350.0

## 蹬牆跳垂直力道，是一般跳躍的幾倍
@export_range(0.5, 1.5) var jump_scale: float = 1.0

## 蹬出去之後多久內不能再蹬（避免同一面牆連續蹬）
@export_range(0.1, 1.0) var cooldown: float = 0.2

## 蹬牆跳的那一刻發出，在蹬出去之前
signal wall_jumped

const _PRIORITY := 100

var _cooldown_left: float = 0.0

# 用比 Player 預設跳躍高的優先權攔截跳躍鍵
func _on_setup() -> void:
	InputRouter.bind(self, "jump", InputRouter.PRESSED, _on_jump_pressed, _PRIORITY)

# 每幀倒數冷卻
func apply(ctx: MoveContext) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= ctx.delta

# 重生時冷卻歸零
func on_respawn() -> void:
	_cooldown_left = 0.0

# 站在地面上、沒貼牆、或還在冷卻就不攔截，讓 Player 自己的跳躍照常運作；
# 否則往牆壁反方向蹬出去，同時往上跳
func _on_jump_pressed() -> bool:
	if player.can_ground_jump() or not player.is_on_wall() or _cooldown_left > 0.0:
		return false
	var normal: Vector2 = player.get_wall_normal()
	wall_jumped.emit()
	player.add_impulse(normal * push_force)
	player.force_jump(jump_scale)
	_cooldown_left = cooldown
	Events.mechanic_event.emit("Extra_WallJump", "wall_jumped")
	return true
