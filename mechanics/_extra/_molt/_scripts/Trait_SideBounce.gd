extends ShellTrait

# 側面彈開的殼：玩家從左右兩邊撞上這顆殼時，玩家跟殼會往相反方向彈開，像撞到橡膠一樣。
# 殼貼著牆時殼本身不會動，只有玩家被彈回去。
# 拖進殼（Shell）底下就能用，不用連任何線。

## 玩家被彈回去的力道，玩家一般跑速大約是 200
@export_range(100.0, 800.0) var strength: float = 300.0
## 殼被彈出去的力道，0 表示殼不動、只彈玩家
@export_range(0.0, 800.0) var shell_strength: float = 250.0

## 玩家被彈開時發出，給學員自己接特效／音效用
signal bounced

# 感應區的寬度（殼左右兩邊再往外這麼多像素內算「撞到側面」），以及上下各縮多少（站在殼上面不算）
const _SENSOR_WIDTH := 4.0
const _SENSOR_TRIM := 4.0
# 玩家往殼的方向比殼快這麼多（或按著往殼的方向鍵）才算撞上來，往外走的不算
const _APPROACH_SPEED := 20.0
# 同一個人彈開後這段時間內不再彈，避免連續觸發
const _COOLDOWN := 0.2
# 彈開後鎖住方向鍵的時間，不然按著方向鍵會馬上把彈回去的速度蓋掉
const _LOCK_TIME := 0.2

var _sensors: Array[Area2D] = []
var _sensor_shapes: Array[RectangleShape2D] = []
var _cooldowns: Dictionary = {}

# 在殼的左右兩邊各建一個感應區，偵測撞上來的玩家
func _on_setup() -> void:
	add_to_group("signal_source")
	for side in [-1, 1]:
		var sensor := Area2D.new()
		sensor.name = "SideSensorLeft" if side < 0 else "SideSensorRight"
		sensor.collision_layer = 0
		sensor.collision_mask = Layers.PLAYER
		var shape := RectangleShape2D.new()
		var col := CollisionShape2D.new()
		col.shape = shape
		sensor.add_child(col)
		# 殼被物理引擎移動時不會帶著子節點一起動，所以感應區自己獨立，每幀擺到殼的兩側
		sensor.top_level = true
		add_child(sensor)
		_sensors.append(sensor)
		_sensor_shapes.append(shape)
	_follow_shell()

# 每幀讓感應區跟著殼走，並檢查有沒有玩家撞上側面
func _physics_process(delta: float) -> void:
	if shell == null or _sensors.is_empty():
		return
	_follow_shell()
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	if shell.is_broken():
		return
	for i in _sensors.size():
		# 左邊的感應區抓到的人是往右撞上來，右邊的是往左
		var into := 1.0 if i == 0 else -1.0
		for body in _sensors[i].get_overlapping_bodies():
			_try_bounce(body, into)

# 把感應區擺到殼的左右兩側（稍微蓋進殼裡一點），大小跟著殼變
func _follow_shell() -> void:
	var size := shell.get_body_size()
	for i in _sensors.size():
		var side := -1.0 if i == 0 else 1.0
		_sensor_shapes[i].size = Vector2(_SENSOR_WIDTH + 1.0, maxf(size.y - _SENSOR_TRIM * 2.0, 1.0))
		_sensors[i].global_position = shell.global_position + Vector2(side * (size.x / 2.0 + _SENSOR_WIDTH / 2.0 - 0.5), 0.0)

# 玩家往殼的方向撞上來：玩家往反方向彈回去，殼往被撞的方向彈出去
# （剛脫殼還沒鑽出來的玩家、往外走的玩家、冷卻中的玩家不算）
func _try_bounce(body: Node, into: float) -> void:
	if not (body is CharacterBody2D and body.has_method("add_impulse")):
		return
	if shell.is_ignoring(body) or _cooldowns.has(body.get_instance_id()):
		return
	if body.has_method("is_dead") and body.is_dead():
		return
	var velocity: Vector2 = body.velocity
	var approach: float = (velocity.x - shell.linear_velocity.x) * into
	var pressing: bool = body.has_method("get_move_input") and body.get_move_input() * into > 0.0
	if approach < _APPROACH_SPEED and not pressing:
		return
	_cooldowns[body.get_instance_id()] = _COOLDOWN
	body.add_impulse(Vector2(-into * strength - velocity.x, 0.0))
	if body.has_method("lock_move_input"):
		body.lock_move_input(_LOCK_TIME)
	if shell_strength > 0.0:
		shell.linear_velocity.x = into * shell_strength
	bounced.emit()
