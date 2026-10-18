class_name PushBlock
extends RefCounted

# 推得動的東西（箱子、殼）共用：頂端加一片可以站的薄平台，貼著牆時打開一塊實心擋板讓玩家推不動。
# 玩家本來就不會被箱子類的東西擋住（是物理引擎把箱子從玩家身上擠開，玩家的力氣等於無限大），
# 所以沒有這兩片碰撞的話，站上去會把箱子往下壓、推到牆邊會把箱子硬擠進牆裡。
# 用法：箱子在 _ready() 裡 PushBlock.new(self, 大小)，每個物理幀呼叫 update()。

# 頂端平台的厚度
const TOP_THICKNESS := 2.0
# 檢查左右有沒有貼著牆時，往外多看幾像素；上下各縮一點，才不會把地板、天花板當成牆
const _WALL_CHECK := 1.5
const _WALL_CHECK_TRIM := 2.0

# 頂端平台、貼牆擋板用的碰撞：子彈打到時照箱子自己的「擋子彈」設定
class Part extends AnimatableBody2D:
	var helper: PushBlock = null
	var block_bullets: bool:
		get:
			var source := helper.body
			return not ("block_bullets" in source) or source.block_bullets

var body: RigidBody2D = null
var top: Part = null
var wall_block: Part = null
var wall_sides: int = 0    # 哪幾邊貼著牆：1 是左邊、2 是右邊，兩邊都貼就是 3
var _size: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO
var _removed_player_mask: bool = false

# 幫推得動的東西建好頂端平台和貼牆擋板（offset 是碰撞形狀中心相對於本體的位置）
func _init(owner_body: RigidBody2D, size: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	body = owner_body
	_size = size
	_offset = offset
	top = _make_part("Top", true)
	wall_block = _make_part("WallBlock", false)
	(wall_block.get_child(0) as CollisionShape2D).disabled = true
	_resize()
	update()

# 改大小（像素），殼跟著玩家體型變大小時用這個
func set_size(size: Vector2) -> void:
	_size = size
	_resize()
	_move_parts()

# 每個物理幀呼叫：讓平台、擋板跟著本體走，檢查有沒有貼著牆
func update() -> void:
	if not is_instance_valid(body):
		return
	_move_parts()
	var sides := 0
	if _touching_wall(-1):
		sides |= 1
	if _touching_wall(1):
		sides |= 2
	var was_blocking := wall_sides != 0
	wall_sides = sides
	if (sides != 0) == was_blocking:
		return
	(wall_block.get_child(0) as CollisionShape2D).set_deferred("disabled", sides == 0)
	# 貼著牆時本體不再被玩家擠動（玩家改成被擋板擋住）；離開牆就恢復
	if sides != 0 and body.collision_mask & Layers.PLAYER:
		body.collision_mask &= ~Layers.PLAYER
		_removed_player_mask = true
	elif sides == 0 and _removed_player_mask:
		body.collision_mask |= Layers.PLAYER
		_removed_player_mask = false

# 是不是正貼著牆、推不動
func is_against_wall() -> bool:
	return wall_sides != 0

# 平台跟擋板（暫時不互撞這類設定要一起套用）
func parts() -> Array[PhysicsBody2D]:
	var result: Array[PhysicsBody2D] = [top, wall_block]
	return result

# 本體跟平台、擋板的 RID，查詢時排除自己用
func rids() -> Array[RID]:
	var result: Array[RID] = [body.get_rid(), top.get_rid(), wall_block.get_rid()]
	return result

# 建一片跟著本體走的碰撞（地形層，玩家會被擋住）；本體被物理引擎移動時不會帶著子節點一起動，
# 所以設成獨立的，每幀由 update() 擺到正確位置
func _make_part(part_name: String, one_way: bool) -> Part:
	var part := Part.new()
	part.helper = self
	part.name = part_name
	part.collision_layer = Layers.TERRAIN
	part.collision_mask = 0
	var col := CollisionShape2D.new()
	col.shape = RectangleShape2D.new()
	col.one_way_collision = one_way
	part.add_child(col)
	part.top_level = true
	body.add_child(part)
	body.add_collision_exception_with(part)
	return part

# 依大小調整平台、擋板
func _resize() -> void:
	((top.get_child(0) as CollisionShape2D).shape as RectangleShape2D).size = Vector2(_size.x, TOP_THICKNESS)
	((wall_block.get_child(0) as CollisionShape2D).shape as RectangleShape2D).size = _size

# 本體碰撞形狀現在的中心位置
func _center() -> Vector2:
	return body.global_position + _offset

# 平台擺到本體上緣再往上一點，擋板擺在本體的位置
func _move_parts() -> void:
	var center := _center()
	top.global_position = center + Vector2(0.0, -_size.y / 2.0 - TOP_THICKNESS / 2.0)
	wall_block.global_position = center

# 某一邊（-1 左、1 右）是不是貼著牆：一般地形、推不動的殼都算；
# 別的箱子、殼的擋板只有在它也是同一邊貼著牆時才算（一排箱子推到牆邊時整排都推不動），
# 不然兩個箱子互相把對方當成牆，牆不見了也會一直卡著；別人的頂端平台不算
func _touching_wall(side: int) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_WALL_CHECK + 0.5, maxf(_size.y - _WALL_CHECK_TRIM * 2.0, 1.0))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	# 從邊緣往內 0.5 像素開始看，已經稍微陷進牆裡也查得到
	query.transform = Transform2D(0.0, _center() + Vector2(side * (_size.x / 2.0 + _WALL_CHECK / 2.0 - 0.25), 0.0))
	query.collision_mask = Layers.TERRAIN
	query.exclude = rids()
	var bit := 1 if side < 0 else 2
	for hit in body.get_world_2d().direct_space_state.intersect_shape(query, 8):
		var collider: Object = hit.collider
		if collider == null:
			continue
		if not (collider is Part):
			return true
		var other := (collider as Part).helper
		if collider == other.wall_block and other.wall_sides & bit:
			return true
	return false
