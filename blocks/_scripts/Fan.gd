extends Area2D

# 風扇：感應，範圍內的玩家持續受到指定方向的風力。範圍會依 range_tiles 從風扇本體
# 往吹的方向延伸，範圍區塊會用淡色半透明方框顯示，讓學員看得到風力影響到哪裡。

## 吹的方向：上、下、左、右
@export_enum("上", "下", "左", "右") var direction: int = 0

## 風力大小，數值越大吹得越用力
@export_range(50.0, 800.0) var force: float = 300.0

## 影響範圍，單位是格（1 格 = 16 像素），從風扇本體往吹的方向延伸
@export_range(1, 20) var range_tiles: int = 5

## 一開始就是開著的
@export var start_on: bool = true

const _TILE_SIZE := 16.0
const _ZONE_WIDTH := 32.0
const _DIR_LEFT := 2
const _DIRECTIONS := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _zone_visual: ColorRect = $ZoneVisual

var _active: bool = true
var _skin: SkinLink = null
var _overlapping_players: Array[Node] = []

## 開始吹風
func activate() -> void:
	_set_active(true)

## 停止吹風
func deactivate() -> void:
	_set_active(false)

## 切換
func toggle() -> void:
	_set_active(not _active)

# 設定碰撞層／遮罩，依方向與範圍格數算出感應區域，套用一開始要不要開；
# 本體底下有皮就換上皮（風力範圍的半透明框照舊顯示）
func _ready() -> void:
	add_to_group("signal_source")
	_skin = SkinLink.new(self, $BodyVisual)
	collision_layer = Layers.SENSOR
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_zone_shape()
	_set_active(start_on)

# 依方向與範圍格數算出感應區域的大小跟位置，讓風力區從風扇本體往外延伸
func _apply_zone_shape() -> void:
	var length := range_tiles * _TILE_SIZE
	var dir: Vector2 = _DIRECTIONS[direction]
	var size := Vector2(length, _ZONE_WIDTH) if direction >= _DIR_LEFT else Vector2(_ZONE_WIDTH, length)
	var center := dir * length * 0.5
	var shape := RectangleShape2D.new()
	shape.size = size
	_shape.shape = shape
	_shape.position = center
	_zone_visual.size = size
	_zone_visual.position = center - size * 0.5

# 有玩家進到風力範圍
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_overlapping_players.append(body)

# 玩家離開風力範圍
func _on_body_exited(body: Node) -> void:
	_overlapping_players.erase(body)

# 每個物理幀對範圍內的玩家施加風力。左右方向要額外補償玩家自己的地面摩擦力，
# 不然玩家沒按方向鍵時，摩擦力每幀都會把速度拉回 0，風力多半還沒生效就被吃光；
# 玩家自己按著方向鍵走的話，風不會蓋過操作，效果跟真的迎風前進一樣。
func _physics_process(delta: float) -> void:
	if not _active or _overlapping_players.is_empty():
		return
	var dir: Vector2 = _DIRECTIONS[direction]
	for body in _overlapping_players:
		if not is_instance_valid(body) or not body.has_method("add_impulse"):
			continue
		var push := dir * force * delta
		if direction >= _DIR_LEFT:
			push += dir * _friction_pushback(body, delta)
		body.add_impulse(push)

# 算出玩家這一幀的地面摩擦力大概會拉走多少速度，讓水平風力可以補償回來
func _friction_pushback(body: Node, delta: float) -> float:
	var move_speed: float = body.get("move_speed") if body.get("move_speed") != null else 0.0
	var ground_friction: float = body.get("ground_friction") if body.get("ground_friction") != null else 0.0
	return move_speed * lerpf(2.0, 20.0, ground_friction) * delta

# 真正切換開關狀態並更新外觀（本體有皮就換皮的樣子，關掉算「狀態改變後」）
func _set_active(is_active: bool) -> void:
	_active = is_active
	_skin.show_state(not _active, Color(0.3, 0.85, 0.35) if _active else Color(0.55, 0.55, 0.55))
	_zone_visual.color = Color(0.4, 0.8, 1.0, 0.35) if _active else Color(0.4, 0.8, 1.0, 0.08)
