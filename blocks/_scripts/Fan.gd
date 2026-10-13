@tool
extends Area2D

# 風扇：感應，範圍內的玩家持續受到指定方向的風力。範圍會依 range_tiles 從風扇本體
# 往吹的方向延伸，範圍區塊會用淡色半透明方框顯示，讓學員看得到風力影響到哪裡（編輯器裡也畫得出來，含箭頭）。
# 風扇節點被旋轉、翻面的話，風也跟著轉，吹的方向永遠跟畫面上看到的一樣。
# 吹法有兩種：「越吹越快」（舊的，待越久速度越快）和「固定速度」（順著風的速度拉到每秒幾格就不再變快）。

## 吹的方向：上、下、左、右（把風扇整個旋轉也可以，風會跟著轉）
@export_enum("上", "下", "左", "右") var direction: int = 0:
	set(value):
		direction = value
		_apply_zone_shape()

## 吹法：越吹越快＝待在風裡越久飛越快；固定速度＝順著風每秒推固定的格數，不會越來越快
@export_enum("越吹越快", "固定速度") var mode: int = 0:
	set(value):
		mode = value
		notify_property_list_changed()

## 風力大小，數值越大吹得越用力（吹法選「越吹越快」才用到）
@export_range(50.0, 800.0) var force: float = 300.0

## 每秒推幾格（1 格 = 16 像素），往上吹時會抵銷重力慢慢飄上去（吹法選「固定速度」才用到）
@export_range(0.0, 30.0, 0.001, "or_greater") var speed: float = 5.0

## 勾起來：人在風裡也有地面摩擦力，左右吹的力道就是 force；不勾：風裡沒有摩擦力，左右吹會特別大力（原本的樣子）。
## 吹法選「越吹越快」才用到（固定速度本來就會把速度拉到每秒幾格，摩擦力沒有意義）
@export var friction_enabled: bool = false

## 影響範圍，單位是格（1 格 = 16 像素），從風扇本體往吹的方向延伸
@export_range(1, 20) var range_tiles: int = 5:
	set(value):
		range_tiles = value
		_apply_zone_shape()

## 一開始就是開著的
@export var start_on: bool = true

const _TILE_SIZE := 16.0
const _ZONE_WIDTH := 32.0
const _DIR_LEFT := 2
const _MODE_FIXED := 1
# 固定速度：速度往目標靠近的快慢，數字越大越快到目標速度（10 大約 0.3 秒就到）
const _FIXED_CATCH_UP := 10.0
const _DIRECTIONS := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
# 編輯器預覽的顏色：範圍跟遊戲中一樣的淡藍色，箭頭深一點
const _PREVIEW_FILL := Color(0.4, 0.8, 1.0, 0.35)
const _PREVIEW_ARROW := Color(0.15, 0.5, 0.9, 0.9)

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
	_apply_zone_shape()
	if Engine.is_editor_hint():
		return
	add_to_group("signal_source")
	_skin = SkinLink.new(self, $BodyVisual)
	collision_layer = Layers.SENSOR
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_zone_visual.visible = true
	_set_active(start_on)

# 依方向與範圍格數算出感應區域的大小跟位置，讓風力區從風扇本體往外延伸。碰撞範圍由程式建
# （內部節點，不會存進場景），編輯器裡改方向、格數時碰撞框也會跟著變
func _apply_zone_shape() -> void:
	if not is_inside_tree():
		return
	var rect := _zone_rect()
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node, false, Node.INTERNAL_MODE_FRONT)
	if not shape_node.shape is RectangleShape2D:
		shape_node.shape = RectangleShape2D.new()
	(shape_node.shape as RectangleShape2D).size = rect.size
	shape_node.position = rect.get_center()
	if not Engine.is_editor_hint():
		_zone_visual.size = rect.size
		_zone_visual.position = rect.position
	queue_redraw()

# 風力範圍在風扇自己座標裡的方框（還沒算旋轉），遊戲中的碰撞範圍跟編輯器預覽共用
func _zone_rect() -> Rect2:
	var length := range_tiles * _TILE_SIZE
	var dir: Vector2 = _DIRECTIONS[direction]
	var size := Vector2(length, _ZONE_WIDTH) if direction >= _DIR_LEFT else Vector2(_ZONE_WIDTH, length)
	return Rect2(dir * length * 0.5 - size * 0.5, size)

# 實際吹的方向：下拉選的方向再套上風扇節點的旋轉、翻面，跟畫面上看到的範圍一致
func _wind_direction() -> Vector2:
	return global_transform.basis_xform(_DIRECTIONS[direction]).normalized()

# 編輯器裡畫出風力範圍和吹的方向箭頭（遊戲中由 ZoneVisual 顯示範圍，這裡不畫）
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := _zone_rect()
	draw_rect(rect, _PREVIEW_FILL)
	var dir: Vector2 = _DIRECTIONS[direction]
	var length := range_tiles * _TILE_SIZE
	var tail := dir * minf(length * 0.2, 12.0)
	var tip := dir * (length - minf(length * 0.1, 4.0))
	var side := dir.orthogonal() * 5.0
	draw_line(tail, tip, _PREVIEW_ARROW, 2.0)
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 8.0 + side, tip - dir * 8.0 - side]), _PREVIEW_ARROW)

# 有玩家進到風力範圍
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_overlapping_players.append(body)

# 玩家離開風力範圍
func _on_body_exited(body: Node) -> void:
	_overlapping_players.erase(body)

# 每個物理幀對範圍內的玩家施加風力，依吹法分成「越吹越快」和「固定速度」兩種算法
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _active or _overlapping_players.is_empty():
		return
	var dir := _wind_direction()
	for body in _overlapping_players:
		if not is_instance_valid(body) or not body.has_method("add_impulse"):
			continue
		var push: Vector2
		if mode == _MODE_FIXED:
			push = _fixed_speed_push(body, dir, delta)
		else:
			# 越吹越快（舊的算法，已經做好的遊戲靠這個手感，不要改）：左右方向額外補償玩家的地面摩擦力。
			# 不勾摩擦力時風裡本來就沒有摩擦力，這筆補償等於多推一把（左右吹特別大力就是這個）；
			# 勾了摩擦力時補償剛好抵掉摩擦力，左右吹的力道就是 force。斜著吹（旋轉過）只補償水平的那一份
			push = dir * force * delta
			push.x += dir.x * _friction_pushback(body, delta)
		if friction_enabled and mode != _MODE_FIXED:
			body.add_impulse(push, true)
		else:
			body.add_impulse(push)

# 固定速度：把玩家順著風的那個方向的速度慢慢拉到 speed 格／秒，到了就不再加快；
# 順著風的那一份重力先抵銷掉，所以往上吹再慢都飄得起來。跟風垂直的速度不動（左右吹照樣會往下掉）
func _fixed_speed_push(body: Node, dir: Vector2, delta: float) -> Vector2:
	var velocity: Vector2 = body.get("velocity")
	var along := velocity.dot(dir)
	var target := speed * _TILE_SIZE
	var push := dir * (target - along) * minf(_FIXED_CATCH_UP * delta, 1.0)
	var gravity: float = body.get("gravity") if body.get("gravity") != null else 0.0
	var up: Vector2 = body.get("up_direction") if body.get("up_direction") != null else Vector2.UP
	push -= dir * (-up * gravity).dot(dir) * delta
	return push

# 吹法沒選到的欄位藏起來：越吹越快只看到 force、friction_enabled，固定速度只看到 speed
func _validate_property(property: Dictionary) -> void:
	if (property.name == "force" or property.name == "friction_enabled") and mode == _MODE_FIXED:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "speed" and mode != _MODE_FIXED:
		property.usage = PROPERTY_USAGE_NONE

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
