@tool
class_name Shell
extends RigidBody2D

# 殼：脫殼卡脫下來的東西，預設跟箱子一樣會往下掉、可以推。
# 殼的特性用特性組件（ShellTrait）組合：把 Trait_* 拖進殼底下就會生效，不用連任何線。
# 想換外觀就在殼底下加自己的 Sprite2D，沒有的話會畫一個預設顏色的方框。

@export_group("物理")
## 會不會受重力往下掉（關掉的話殼會停在脫下來的地方，推了會慢慢停下）
@export var use_gravity: bool = true
## 玩家能不能推動（關掉的話殼會固定在原地、變成實心的，玩家可以站在上面）
@export var can_push: bool = true

@export_group("數量限制")
## 同一種殼最多可以同時存在幾顆
@export_range(1, 5) var max_count: int = 1
## 上面的數量怎麼算：每個房間各自算，還是整個關卡一起算
@export_enum("每個房間", "整個關卡") var count_scope: int = 0
## 數量滿了之後再脫殼會怎樣
@export_enum("最舊的碎掉", "不能再脫") var when_full: int = 0
## 這種殼總共可以脫幾次，0 表示不限次數
@export_range(0, 20) var max_uses: int = 0

@export_group("外觀")
## 預設方框的顏色（殼底下有自己的圖片時不會用到）；選「自訂」可以用調色盤挑顏色或貼色碼
@export_enum("琥珀", "藍", "綠", "灰", "紅", "紫", "自訂") var color: int = 0:
	set(value):
		color = value
		notify_property_list_changed()
		queue_redraw()

## 自訂的顏色，點色塊開調色盤，可以直接貼色碼（例如 ff8800）（「顏色」選自訂時才會顯示這一欄）
@export var custom_color: Color = Color(0.85, 0.65, 0.3):
	set(value):
		custom_color = value
		queue_redraw()

## 殼碎掉時發出，給學員自己接特效／音效用
signal broken

const _COLORS := [
	Color(0.85, 0.65, 0.3),
	Color(0.35, 0.6, 0.9),
	Color(0.4, 0.8, 0.45),
	Color(0.6, 0.6, 0.6),
	Color(0.9, 0.35, 0.35),
	Color(0.7, 0.45, 0.9),
]
const _CUSTOM_COLOR := 6
const _DEFAULT_SIZE := Vector2(16, 32)
const _MASS := 1.0
# 不受重力時推完會慢慢停下，不會一直飄走
const _FLOAT_DAMP := 3.0

var _size: Vector2 = _DEFAULT_SIZE
var _is_broken: bool = false
# 推得動的殼用的頂端平台（可以站上去）和貼牆擋板（推到牆邊就推不動），推不動的殼沒有
var _push_block: PushBlock = null
var _ignored: Array[PhysicsBody2D] = []

# 「顏色」沒選自訂時隱藏自訂顏色欄位
func _validate_property(property: Dictionary) -> void:
	if property.name == "custom_color" and color != _CUSTOM_COLOR:
		property.usage = PROPERTY_USAGE_NONE

# 套用物理設定、加入群組，讓底下的特性組件生效
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("shell")
	# 也算箱子：按鈕、傳送門、崩塌地板、彈射台這些認箱子的零件，對殼一樣有效
	add_to_group("box")
	_make_own_shape()
	_apply_physics()
	if can_push:
		_push_block = PushBlock.new(self, _size)
	for child in get_children():
		if child is ShellTrait:
			child.setup(self)

# 設定殼的大小（像素），脫殼卡用這個讓殼跟玩家脫殼當下一樣大
func set_body_size(size: Vector2) -> void:
	_size = size
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null and col.shape is RectangleShape2D:
		(col.shape as RectangleShape2D).size = size
	if _push_block != null:
		_push_block.set_size(size)
	queue_redraw()

# 取得殼的大小（像素）
func get_body_size() -> Vector2:
	return _size

# 讓殼碎掉：直接消失（碎掉的特效之後由學員接 broken 訊號自己做）
func break_shell() -> void:
	if _is_broken:
		return
	_is_broken = true
	broken.emit()
	queue_free()

# 取得殼的顏色（下拉選的顏色或自訂顏色），脫殼卡顯示目前選中哪種殼用這個
func get_color() -> Color:
	var c: Color = custom_color if color == _CUSTOM_COLOR else _COLORS[clampi(color, 0, _COLORS.size() - 1)]
	c.a = 1.0
	return c

# 殼是不是已經碎掉了
func is_broken() -> bool:
	return _is_broken

# 暫時不跟某個東西互撞，等兩邊分開了才恢復；脫殼卡用這個讓剛脫下的殼不會把玩家擠開
func ignore_until_apart(body: PhysicsBody2D) -> void:
	if body == null or body in _ignored:
		return
	_ignored.append(body)
	add_collision_exception_with(body)
	body.add_collision_exception_with(self)
	for part in _parts():
		part.add_collision_exception_with(body)
		body.add_collision_exception_with(part)

# 殼是不是正貼著牆、推不動（貼著牆時玩家會被殼擋住，不會把殼擠進牆裡），特性組件用這個
func is_against_wall() -> bool:
	return _push_block != null and _push_block.is_against_wall()

# 某個東西現在是不是暫時不跟殼互撞（剛脫殼、還沒鑽出來），特性組件用這個避免對它起作用
func is_ignoring(body: Node) -> bool:
	return body in _ignored

# 檢查暫時不互撞的東西是不是已經離開殼了，離開的就恢復碰撞
func _update_ignored() -> void:
	if _ignored.is_empty():
		return
	var touching := _overlapping_bodies()
	for body in _ignored.duplicate():
		if is_instance_valid(body) and body in touching:
			continue
		_ignored.erase(body)
		if not is_instance_valid(body):
			continue
		remove_collision_exception_with(body)
		body.remove_collision_exception_with(self)
		for part in _parts():
			part.remove_collision_exception_with(body)
			body.remove_collision_exception_with(part)

# 殼自己附帶的碰撞（頂端平台、貼牆擋板），推得動的殼才有
func _parts() -> Array[PhysicsBody2D]:
	var result: Array[PhysicsBody2D] = []
	if _push_block != null:
		result = _push_block.parts()
	return result

# 查詢時要排除的碰撞：殼本體跟自己附帶的碰撞
func _own_rids() -> Array[RID]:
	var result: Array[RID] = [get_rid()]
	if _push_block != null:
		result = _push_block.rids()
	return result

# 用殼本體的範圍查一次現在跟哪些東西重疊（稍微縮小一點，只是貼著邊、站在上面不算重疊）
func _overlapping_bodies() -> Array[Node]:
	var result: Array[Node] = []
	var shape := RectangleShape2D.new()
	shape.size = (_size - Vector2(2.0, 2.0)).max(Vector2.ONE)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 0xFFFFFFFF
	query.exclude = _own_rids()
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		if hit.collider is Node:
			result.append(hit.collider)
	return result

# 每顆殼用自己的碰撞形狀，複製出來的殼改大小時才不會互相影響
func _make_own_shape() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		push_warning("[殼] %s 少了 CollisionShape2D，不會擋東西" % name)
		return
	var shape := RectangleShape2D.new()
	shape.size = _size
	col.shape = shape

# 依勾選框設定重力、能不能推：推得動的跟箱子同一層，推不動的固定住、當成地形讓玩家站
func _apply_physics() -> void:
	mass = _MASS
	lock_rotation = true
	gravity_scale = 1.0 if use_gravity else 0.0
	linear_damp = 0.0 if use_gravity else _FLOAT_DAMP
	if can_push:
		freeze = false
		collision_layer = Layers.BOX
		collision_mask = Layers.PLAYER | Layers.TERRAIN | Layers.BOX
	else:
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true
		collision_layer = Layers.TERRAIN
		collision_mask = 0

# 每幀讓頂端平台、貼牆擋板跟著殼走（平台會算出自己的速度，站在上面的玩家會被帶著走），
# 檢查殼有沒有貼著牆，並檢查暫時不互撞的東西離開了沒
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _push_block != null:
		_push_block.update()
	_update_ignored()

# 沒有自己的圖片時，畫一個預設顏色的方框
func _draw() -> void:
	if _has_custom_visual():
		return
	var rect := Rect2(-_size / 2.0, _size)
	var c := get_color()
	draw_rect(rect, Color(c, 0.75))
	draw_rect(rect, c.darkened(0.4), false, 2.0)

# 殼底下有沒有學員自己放的圖片（特性組件、碰撞形狀、頂端平台不算）
func _has_custom_visual() -> bool:
	for child in get_children():
		if child is ShellTrait or child is CollisionShape2D or child is CollisionPolygon2D or child is CollisionObject2D:
			continue
		if child is CanvasItem:
			return true
	return false

# 編輯器裡加減子節點時重畫，放了自己的圖片就不畫預設方框
func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		queue_redraw()
