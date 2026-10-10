extends CharacterBody2D

# 笨敵人：會動，左右巡邏，撞牆自動轉身，turn_at_ledge 開啟時走到懸崖邊也會轉身。
# 被攻擊會扣血，歸零時消失並發出 defeated；碰到玩家會造成傷害。
# 拖進場景就能用，不用連任何線。
# 攻擊組件（例如 EnemyShooter）拖到關卡裡這個敵人的底下就會生效：敵人主動找子節點呼叫 setup()。

## 巡邏速度
@export_range(20.0, 200.0) var speed: float = 60.0

## 血量，扣到 0 就會消失
@export_range(1, 20) var health: int = 3

## 碰到玩家造成的傷害
@export_range(1, 10) var damage: int = 1

## 碰到玩家時把玩家彈開的力道，0 = 不彈開只扣血
@export_range(0.0, 800.0) var knockback: float = 300.0

## 走到懸崖邊會不會轉身，關掉的話會直接走下去
@export var turn_at_ledge: bool = true

## 血量歸零消失時發出，給學員自己接特效／音效用
signal defeated

const _GRAVITY := 980.0
const _STUN_DURATION := 0.25

@onready var _hurtbox: Area2D = $Hurtbox
@onready var _ledge_check_left: RayCast2D = $LedgeCheckLeft
@onready var _ledge_check_right: RayCast2D = $LedgeCheckRight

var _direction: int = 1
var _health_left: int = 0
var _stun_time_left: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _defeated: bool = false
var _hold_time_left: float = 0.0

# 回傳這個敵人是不是已經被打倒了，攻擊組件用這個決定要不要停手
func is_defeated() -> bool:
	return _defeated

# 回傳目前巡邏的方向（-1 左、1 右），攻擊組件「朝面向方向」用這個
func get_facing() -> int:
	return _direction

# 原地停下幾秒（不巡邏，仍受重力），攻擊組件射擊前用這個讓玩家看得出牠要開槍了
func hold_still(duration: float) -> void:
	_hold_time_left = maxf(_hold_time_left, duration)

# 被推一下（不扣血），推力器這類零件用這個；推的這一小段時間不巡邏，不然速度馬上被蓋掉
func add_impulse(v: Vector2) -> void:
	velocity += v
	_stun_time_left = _STUN_DURATION

# 被攻擊打到：扣血並被擊退一下，歸零時消失
func take_hit(hit_damage: int, knockback: Vector2, source: Node) -> void:
	Events.hit.emit(self, source)
	_health_left -= maxi(hit_damage, 1)
	velocity += knockback
	_stun_time_left = _STUN_DURATION
	if _health_left <= 0:
		_defeat()

# 被打倒：藏起來、關掉碰撞與傷害判定、停止巡邏（不刪除節點，重生時才能復活）
func _defeat() -> void:
	if _defeated:
		return
	_defeated = true
	defeated.emit()
	Events.enemy_died.emit(global_position)
	remove_from_group("enemy")
	_set_alive(false)

# 把自己恢復到關卡開始時的狀態：回到原位、血量補滿、被打倒的話復活（重生處理者呼叫）
func reset() -> void:
	global_position = _start_position
	velocity = Vector2.ZERO
	_direction = 1
	_health_left = health
	_stun_time_left = 0.0
	_hold_time_left = 0.0
	for child in get_children():
		if child.has_method("on_reset"):
			child.on_reset()
	if _defeated:
		_defeated = false
		add_to_group("enemy")
		_set_alive(true)

# 切換「活著」的狀態：看不看得見、有沒有碰撞、會不會傷害玩家、會不會動
func _set_alive(alive: bool) -> void:
	visible = alive
	$CollisionShape2D.set_deferred("disabled", not alive)
	_hurtbox.set_deferred("monitoring", alive)
	set_physics_process(alive)

# 加入 enemy group，設定碰撞層／遮罩、Hurtbox，套用一開始的血量
func _ready() -> void:
	add_to_group("enemy")
	_health_left = health
	_start_position = global_position
	collision_layer = Layers.ENEMY
	collision_mask = Layers.PLAYER | Layers.TERRAIN | Layers.BOX
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = Layers.PLAYER
	_hurtbox.body_entered.connect(_on_hurtbox_entered)
	for child in get_children():
		_try_setup(child)
	child_entered_tree.connect(_try_setup)

# 子節點有 setup() 的就是攻擊組件，把自己交給它（沒有 setup() 的是碰撞形狀、偵測線這類，跳過）
func _try_setup(child: Node) -> void:
	if child.has_method("setup"):
		child.setup(self)

# 碰到玩家：打玩家一下（扣血＋把玩家往外、往上彈開），碰一次算一次
func _on_hurtbox_entered(body: Node) -> void:
	var player := body as CharacterBody2D
	if player == null or not player.is_in_group("player") or not player.has_method("take_hit"):
		return
	var away := (player.global_position - global_position).normalized()
	var direction := (away + player.up_direction * 0.5).normalized()
	player.take_hit(damage, direction * knockback, self)

# 每個物理幀：套用重力、往目前方向移動，撞牆或走到懸崖邊就轉身；
# 被擊退期間（_stun_time_left > 0）先不控制水平速度，讓擊退看得出來；
# hold_still() 停下期間原地不動、也不轉身
func _physics_process(delta: float) -> void:
	velocity.y += _GRAVITY * delta
	if _stun_time_left > 0.0:
		_stun_time_left -= delta
	elif _hold_time_left > 0.0:
		_hold_time_left -= delta
		velocity.x = 0.0
	else:
		velocity.x = _direction * speed
	move_and_slide()
	if _stun_time_left <= 0.0 and _hold_time_left <= 0.0:
		if is_on_wall():
			_turn_around()
		elif turn_at_ledge and not _has_ground_ahead():
			_turn_around()

# 檢查目前前進方向的懸崖偵測線有沒有踩到地板
func _has_ground_ahead() -> bool:
	var ray := _ledge_check_right if _direction > 0 else _ledge_check_left
	ray.force_raycast_update()
	return ray.is_colliding()

# 反轉巡邏方向
func _turn_around() -> void:
	_direction *= -1
