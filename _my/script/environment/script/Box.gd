extends RigidBody2D

# 箱子：會動，是實體（擋得住玩家、站得上去），玩家從側面走過去就會推著走（Player 呼叫 push()），卡在牆角就推不動；
# 被攻擊時只會被擊退，不會受傷、沒有耐久。
# 被推的時候前面的地面高出 1 像素以內就直接抬上去，不會卡在圖塊接縫上。
# 拖進場景就能用，不用連任何線。

## 推得動：取消勾的話變成固定在原地的實心方塊，站得上去、推不動（攻擊、推力器、彈射台、磁鐵也推不動），但還是算箱子（可以踩按鈕）
@export var can_push: bool = true

## 重量：輕的比較好推、重的比較不好推（推不動的箱子用不到）
@export_enum("輕", "重") var weight: int = 0

## 會不會擋子彈：關掉的話子彈（玩家的、敵人的都一樣）會直接穿過去
@export var block_bullets: bool = true

const _LIGHT_MASS := 1.0
const _HEAVY_MASS := 4.0
# 被玩家推的時候，箱子的速度是玩家走路速度的幾倍（重的推得比較慢）
const _LIGHT_PUSH := 0.8
const _HEAVY_PUSH := 0.4
# 速度上限（像素／秒）：一格是 16 像素，960 差不多每幀走一格，再快就可能一幀跳過整面牆（穿牆）
const _MAX_SPEED := 960.0
# 被推的時候前面的地面比腳下的地面高不到這麼多像素，就把箱子抬上去（圖塊接縫、零件接縫的小高低差）
const _STEP_HEIGHT := 1.0
# 抬上去的時候多抬一點點，確定底部的角越過那條邊
const _STEP_EXTRA := 0.075
# 最多回報幾個接觸點（地板兩個角、側面兩個角、上面疊的東西）
const _MAX_CONTACTS := 8

var _start_position: Vector2 = Vector2.ZERO
var _push_dir: int = 0    # 這一幀被推的方向（-1 左、1 右、0 沒被推），物理幀處理完就清掉
var _pushed_frame: int = -1   # 最後一次被推是第幾個物理幀，同一幀不重複處理（一排箱子互相傳推力時用）

# 依重量套用質量，鎖住旋轉讓箱子不會被撞得團團轉，加入 box group 讓其他系統辨識；底下有皮就換上皮；
# 開連續碰撞偵測、不休眠；跟玩家、地形、別的箱子、敵人都會互相擋住
#（箱子沒有狀態變化，不用留著 SkinLink）
func _ready() -> void:
	add_to_group("box")
	SkinLink.new(self, $Visual)
	mass = _LIGHT_MASS if weight == 0 else _HEAVY_MASS
	lock_rotation = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	# 不休眠：休眠的箱子不會被移動平台帶著走，平台開走、地板碎掉時會浮在半空中
	can_sleep = false
	# 回報接觸點：抬過圖塊接縫要看側面撞到的是不是底部的邊，沒開的話物理引擎不會告訴我們接觸點
	contact_monitor = true
	max_contacts_reported = _MAX_CONTACTS
	collision_layer = Layers.BOX
	collision_mask = Layers.PLAYER | Layers.TERRAIN | Layers.BOX | Layers.ENEMY
	if not can_push:
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true
	_start_position = global_position

# 把自己恢復到關卡開始時的狀態：回到原位、停止移動（重生處理者呼叫）
func reset() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, _start_position))
	global_position = _start_position

# 每個物理幀把速度限制在上限以內，被推力器、彈射台推得再快也不會穿牆；被推的時候處理小台階
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.linear_velocity = state.linear_velocity.limit_length(_MAX_SPEED)
	if _push_dir != 0:
		_step_up(state, _push_dir)
		_push_dir = 0

# 被推的方向上，側面被底部附近的東西擋住（例如圖塊接縫的邊）、前面的地面又比腳下的地面高不到 _STEP_HEIGHT 時，
# 把箱子抬到剛好越過那條邊；真的牆壁、比較高的台階照舊推不動
func _step_up(state: PhysicsDirectBodyState2D, dir: int) -> void:
	var half := _half_size()
	var bottom := state.transform.origin.y + half.y
	var blocked := false
	for i in state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		var point := state.get_contact_local_position(i)
		if normal.x * dir < -0.7 and bottom - point.y < _STEP_HEIGHT + 0.5:
			blocked = true
			break
	if not blocked:
		return
	# 箱子正中間往下看腳下地面的高度（箱子會稍微陷進地面一點），再從前緣外面一點點往下看前面地面的高度
	var floor_y: Variant = _ground_y(state, state.transform.origin.x, bottom)
	var front_y: Variant = _ground_y(state, state.transform.origin.x + dir * (half.x + 0.5), bottom)
	if front_y == null:
		return
	var step: float = (bottom if floor_y == null else float(floor_y)) - float(front_y)
	if step >= _STEP_HEIGHT:
		return
	var lift_height: float = bottom - float(front_y) + _STEP_EXTRA
	if lift_height <= 0.0:
		return
	# 頭頂被固定的東西（地形、天花板）擋住就不抬：查箱子正上方抬起來會佔到的那一條（左右各縮一點，不把旁邊的牆算進去）；
	# 疊在上面的箱子、殼、站在上面的玩家不算，它們會跟著被抬起來
	var top_check := RectangleShape2D.new()
	top_check.size = Vector2(half.x * 2.0 - 1.0, lift_height)
	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = top_check
	shape_query.transform = Transform2D(0.0, state.transform.origin + Vector2(0.0, -half.y - lift_height / 2.0))
	shape_query.collision_mask = collision_mask
	shape_query.exclude = [get_rid()]
	for hit in state.get_space_state().intersect_shape(shape_query, 8):
		if not _rides_along(hit["collider"]):
			return
	state.transform = state.transform.translated(Vector2(0.0, -lift_height))

# 抬箱子時會跟著被抬起來、不算擋住頭頂的東西：沒固定住的箱子和殼、玩家
func _rides_along(body: Object) -> bool:
	if body is CharacterBody2D:
		return true
	return body is RigidBody2D and not (body as RigidBody2D).freeze

# 在 x 這個位置，從箱子底部上面一點往下看，回傳碰到的地面高度；底部附近沒有地面回傳 null
func _ground_y(state: PhysicsDirectBodyState2D, x: float, bottom: float) -> Variant:
	var query := PhysicsRayQueryParameters2D.create(Vector2(x, bottom - _STEP_HEIGHT - 1.0), Vector2(x, bottom + 1.0), collision_mask, [get_rid()])
	var hit := state.get_space_state().intersect_ray(query)
	if hit.is_empty():
		return null
	return hit["position"].y

# 箱子碰撞形狀的一半大小（不是長方形就當作 16×16）
func _half_size() -> Vector2:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null and col.shape is RectangleShape2D:
		return (col.shape as RectangleShape2D).size / 2.0
	return Vector2(8.0, 8.0)

# 被玩家推：往 dir（-1 左、1 右）的方向動，speed 是玩家這一幀要走的速度，輕的跟得上、重的比較慢；
# 正前方貼著的箱子也一起推（一排箱子每一個都會處理圖塊接縫，不會被最前面那個卡住整排）
func push(dir: int, speed: float) -> void:
	if not can_push:
		return
	var physics_frame := Engine.get_physics_frames()
	if _pushed_frame == physics_frame:
		return
	_pushed_frame = physics_frame
	sleeping = false
	linear_velocity.x = dir * speed * (_LIGHT_PUSH if weight == 0 else _HEAVY_PUSH)
	_push_dir = dir
	for body in get_colliding_bodies():
		if body != self and body.has_method("push") and _is_in_front(body, dir):
			body.push(dir, speed)

# 某個東西是不是貼在這個箱子的正前方（往 dir 方向、高度差不到半個箱子），疊在上面、壓在下面的不算
func _is_in_front(body: Node, dir: int) -> bool:
	if not (body is Node2D):
		return false
	var offset: Vector2 = (body as Node2D).global_position - global_position
	return offset.x * dir > 0.0 and absf(offset.y) < _half_size().y

# 被攻擊打到：只受擊退，不扣血、沒有耐久
func take_hit(_damage: int, knockback: Vector2, source: Node) -> void:
	Events.hit.emit(self, source)
	apply_central_impulse(knockback)
