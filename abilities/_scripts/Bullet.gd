class_name Bullet
extends Area2D

# 子彈：往發射方向飛行，撞到地形或有 take_hit() 的東西就消失；gravity_enabled 開啟時
# 會像拋物線一樣往下墜；存在超過 lifetime_left 秒、或飛超過 max_distance 像素（0 代表不限制）也會自動消失。
# 子彈分陣營：玩家方打敵人跟物件，敵方打玩家；敵方子彈只有 hit_objects 開啟時才會打壞物件。
# 不是拖進場景用的零件，一律用 Bullet.spawn() 產生（遠程能力、敵人射擊都用這個）。
# 生它的人有放 bullet_texture 時用 set_texture() 換成那張圖（圖畫成朝右飛，飛行時跟著方向轉）。

# 陣營：玩家方
const TEAM_PLAYER := 0
# 陣營：敵方
const TEAM_ENEMY := 1

const _SCENE_PATH := "res://abilities/Bullet.tscn"
const _GRAVITY := 980.0
const _KNOCKBACK_FORCE := 150.0

var velocity: Vector2 = Vector2.ZERO
var gravity_enabled: bool = false
var lifetime_left: float = 2.0
var max_distance: float = 0.0
var damage: int = 1
var team: int = TEAM_PLAYER
var hit_objects: bool = true
var shooter: Node = null
var _traveled: float = 0.0
var _sprite: Sprite2D = null

# 從 shooter 的位置朝 direction 發射一顆子彈，放進目前的關卡場景並回傳它；
# 其他選項（重力、存在秒數、飛行距離、傷害…）拿到回傳值之後再設定
static func spawn(from: Node2D, direction: Vector2, speed: float, bullet_team: int) -> Bullet:
	var bullet := (load(_SCENE_PATH) as PackedScene).instantiate() as Bullet
	bullet.team = bullet_team
	bullet.shooter = from
	bullet.global_position = from.global_position
	bullet.velocity = direction.normalized() * speed
	from.get_tree().current_scene.add_child(bullet)
	return bullet

# 把子彈換成一張圖（藏起原本的色塊）；圖畫成朝右飛，飛行時跟著方向轉。tex 空白就照舊顯示色塊
func set_texture(tex: Texture2D) -> void:
	if tex == null:
		return
	$Visual.visible = false
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.rotation = velocity.angle()
	add_child(_sprite)

# 依陣營設定碰撞層／遮罩，監聽撞到東西；敵方子彈在玩家重生時自動消失，不會一重生就被舊子彈打到
func _ready() -> void:
	collision_layer = Layers.ATTACK
	if team == TEAM_ENEMY:
		collision_mask = Layers.PLAYER | Layers.TERRAIN | Layers.BOX | Layers.SENSOR
		Events.player_respawned.connect(func(_p): queue_free())
	else:
		collision_mask = Layers.TERRAIN | Layers.BOX | Layers.ENEMY | Layers.SENSOR
	body_entered.connect(_on_body_entered)

# 每個物理幀往飛行方向移動，開啟重力就持續往下加速，存在時間到了或飛太遠就消失
func _physics_process(delta: float) -> void:
	if gravity_enabled:
		velocity.y += _GRAVITY * delta
	global_position += velocity * delta
	if _sprite != null:
		_sprite.rotation = velocity.angle()
	_traveled += velocity.length() * delta
	lifetime_left -= delta
	if lifetime_left <= 0.0 or (max_distance > 0.0 and _traveled >= max_distance):
		queue_free()

# 撞到東西：對方設定不擋子彈（block_bullets 關掉）就直接穿過去；
# 否則打得到就呼叫 take_hit()，不管有沒有打到都消失
func _on_body_entered(body: Node) -> void:
	if "block_bullets" in body and not body.block_bullets:
		return
	if body != shooter and _can_hit(body):
		body.take_hit(damage, velocity.normalized() * _KNOCKBACK_FORCE, shooter)
	queue_free()

# 這個陣營的子彈能不能對 body 造成效果：敵方子彈一定打玩家，其他物件看 hit_objects，不打其他敵人
func _can_hit(body: Node) -> bool:
	if not body.has_method("take_hit"):
		return false
	if team != TEAM_ENEMY:
		return true
	if body.is_in_group("player"):
		return true
	if body.is_in_group("enemy"):
		return false
	return hit_objects
