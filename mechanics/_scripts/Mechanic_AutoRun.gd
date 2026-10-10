extends MechanicBase

# 只能往前：玩家不能自己控制方向，角色會自動往一邊跑，只能按跳躍。
# turn_at_wall 開啟時，撞到牆壁或箱子會自動轉向。拖進 Player → Mechanics 底下就能用。
# 可以把訊號連到 run_left()／run_right()／turn_around() 直接改方向（例：按鈕 turned_on → run_left）。

## 遊戲開始時、重生時往哪個方向跑
@export_enum("向右", "向左") var start_direction: int = 0

## 撞到牆壁或箱子時要不要自動轉向
@export var turn_at_wall: bool = true

## 轉向後多久內不能再轉向，避免卡在角落抖動
@export_range(0.05, 0.5) var turn_cooldown: float = 0.15

## 撞到牆壁或箱子、自動轉向之後發出
signal turned_around

const _DIR_RIGHT := 0

var _dir: int = 1
var _turn_cooldown_left: float = 0.0
# 重生後第一幀不檢查撞牆：死掉期間沒有移動，is_on_wall() 還是死掉那一刻的狀態，貼著牆死的話會一重生就轉向
var _skip_wall_check: bool = false

# 套用一開始的方向，同步角色朝向
func _on_setup() -> void:
	_dir = 1 if start_direction == _DIR_RIGHT else -1
	_sync_visual()

# 強制水平方向，撞到正前方的牆（或箱子）就轉向
func apply(ctx: MoveContext) -> void:
	ctx.auto_run_dir = _dir
	if _turn_cooldown_left > 0.0:
		_turn_cooldown_left -= ctx.delta
		return
	if _skip_wall_check:
		_skip_wall_check = false
		return
	if not turn_at_wall or not player.is_on_wall():
		return
	var normal: Vector2 = player.get_wall_normal()
	if normal.dot(Vector2(_dir, 0.0)) < 0.0:
		_turn_around()

# 重生時方向回到一開始設定的方向
func on_respawn() -> void:
	_dir = 1 if start_direction == _DIR_RIGHT else -1
	_turn_cooldown_left = 0.0
	_skip_wall_check = true
	_sync_visual()

# 改成往左跑，可以連任何訊號
func run_left(..._args: Array) -> void:
	_set_direction(-1)

# 改成往右跑，可以連任何訊號
func run_right(..._args: Array) -> void:
	_set_direction(1)

# 往反方向跑，可以連任何訊號（不會發出 turned_around，那是撞牆轉向才發）
func turn_around(..._args: Array) -> void:
	_set_direction(-_dir)

# 換成指定方向、進入轉向冷卻（避免剛轉完就被牆轉回去）、同步角色朝向
func _set_direction(dir: int) -> void:
	_dir = dir
	_turn_cooldown_left = turn_cooldown
	_sync_visual()

# 撞牆轉向：反轉方向，發出 turned_around 訊號與 wall_turned 事件
func _turn_around() -> void:
	_set_direction(-_dir)
	turned_around.emit()
	Events.mechanic_event.emit("Mechanic_AutoRun", "wall_turned")

# 依目前方向翻轉角色視覺，保留忽大忽小這類卡設定的體型
func _sync_visual() -> void:
	if player and player.visual:
		player.visual.scale.x = absf(player.visual.scale.x) * _dir
