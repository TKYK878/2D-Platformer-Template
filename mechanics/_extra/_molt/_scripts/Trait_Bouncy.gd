extends ShellTrait

# 彈彈的殼：玩家、箱子、其他殼從上面落到這顆殼上，會自動被彈起來（比一般跳躍高）。
# 拖進殼（Shell）底下就能用，不用連任何線。

## 彈起來的力道，玩家一般跳躍大約是 400
@export_range(300.0, 900.0) var strength: float = 600.0

## 有東西被彈起來時發出，給學員自己接特效／音效用
signal bounced

# 感應區的厚度（殼頂端平台再往上這麼多像素內算「落到殼上」）
const _SENSOR_THICKNESS := 6.0
# 往上的速度超過這個值就當作正在往上穿過，不彈（例如玩家從殼裡鑽出來）
const _RISING_SPEED := 10.0
# 玩家的腳底要在殼頂端往下這麼多像素以內才算「落到殼上」，從側面擠進殼的範圍時不會被彈起來
const _FEET_TOLERANCE := 6.0
# 殼頂端平台的厚度（跟 Shell.gd 的頂端平台一樣）
const _TOP_THICKNESS := 2.0

var _sensor: Area2D = null
var _sensor_shape: RectangleShape2D = null
var _sensor_width: float = -1.0

# 在殼的頂端建立感應區，偵測落上來的玩家、箱子、其他殼
func _on_setup() -> void:
	add_to_group("signal_source")
	_sensor = Area2D.new()
	_sensor.name = "BounceSensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = Layers.PLAYER | Layers.BOX
	_sensor_shape = RectangleShape2D.new()
	var col := CollisionShape2D.new()
	col.shape = _sensor_shape
	_sensor.add_child(col)
	# 殼被物理引擎移動時不會帶著子節點一起動，所以感應區自己獨立，每幀擺到殼的頂端
	_sensor.top_level = true
	add_child(_sensor)
	_sensor.body_entered.connect(_on_body_entered)
	_follow_shell()

# 每幀讓感應區跟著殼走，殼的大小變了就跟著改
func _physics_process(_delta: float) -> void:
	if shell != null and _sensor != null:
		_follow_shell()

# 把感應區擺到殼頂端（頂端平台再往上一點），寬度跟殼一樣
func _follow_shell() -> void:
	var size := shell.get_body_size()
	if size.x != _sensor_width:
		_sensor_width = size.x
		_sensor_shape.size = Vector2(size.x, _SENSOR_THICKNESS)
	_sensor.global_position = shell.global_position + Vector2(0.0, -size.y / 2.0 - _SENSOR_THICKNESS / 2.0)

# 殼頂端（頂端平台上緣）的高度
func _shell_top() -> float:
	return shell.global_position.y - shell.get_body_size().y / 2.0 - _TOP_THICKNESS

# 有東西落到殼上：往上彈起來（往上穿過的、從側面撞進來的、自己這顆殼、剛脫殼還沒鑽出來的玩家不算）
func _on_body_entered(body: Node) -> void:
	if body == shell or shell.is_broken() or shell.is_ignoring(body):
		return
	if body is CharacterBody2D and body.has_method("add_impulse"):
		var velocity: Vector2 = body.velocity
		if velocity.y < -_RISING_SPEED:
			return
		if body.has_method("get_feet_position") and body.get_feet_position().y > _shell_top() + _FEET_TOLERANCE:
			return
		body.add_impulse(Vector2.UP * (strength + velocity.y))
	elif body is RigidBody2D and not (body as RigidBody2D).freeze:
		var rigid := body as RigidBody2D
		if rigid.linear_velocity.y < -_RISING_SPEED:
			return
		rigid.linear_velocity.y = -strength
	else:
		return
	bounced.emit()
