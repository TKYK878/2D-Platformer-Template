@tool
extends JuiceBase

# 咕嚕眼：在角色臉上黏一對（或一隻）會亂晃的玩具眼睛。拖進 Player → Juice 底下就一直作用（持續型）。
# 眼睛的位置＝這個節點的位置：在編輯器裡直接把節點拖到臉上（編輯器裡就畫得出眼睛）。
# 執行時眼睛會搬進 Visual 底下畫，所以跟著角色的朝向、體型、擠壓、閃色一起變；
# 眼珠有慣性（牛頓第一定律）：角色起跑時眼珠留在原地、看起來往後甩；急停、落地時眼珠繼續往前衝，
# 碰到眼眶會彈回來，停下來慢慢回正。選「跟著移動方向轉頭」時，眼睛整組滑到臉朝前進方向的那一側。

## 眼睛要不要跟著移動方向轉頭：轉頭＝往右走時眼睛滑到臉的右邊，停下來留在最後看的那一側；擺正＝一直在節點的位置
@export_enum("跟著移動方向轉頭", "擺正中間") var look: int = 0
## 一隻眼睛還是兩隻眼睛
@export_enum("一隻", "兩隻") var eye_count: int = 1:
	set(value):
		eye_count = value
		queue_redraw()
## 眼睛有多大（眼白的半徑，像素）
@export_range(2.0, 16.0, 0.5) var eye_size: float = 5.0:
	set(value):
		eye_size = value
		queue_redraw()
## 眼珠佔眼白的比例，數值越大眼珠越大
@export_range(0.2, 0.9) var pupil_size: float = 0.45:
	set(value):
		pupil_size = value
		queue_redraw()
## 眼珠晃動的程度：0 = 幾乎不動，1 = 跑跳時亂甩、彈很久才停
@export_range(0.0, 1.0) var wobble: float = 0.6

const _LOOK_TURN := 0
const _ONE_EYE := 0
# 兩隻眼睛之間的空隙（眼白半徑的倍數）
const _GAP := 0.25
const _OUTLINE := 1.0
# 轉頭時眼睛滑多遠（眼白半徑的倍數）、滑過去的快慢
const _TURN_DISTANCE := 0.75
const _TURN_SPEED := 12.0
# 眼珠的物理：角色速度變化多少（像素／秒）會讓眼珠以「整個眼眶寬／秒」的速度甩出去、
# 拉回中間的彈簧力道、摩擦、往下垂的力道、碰到眼眶反彈保留多少速度
const _SWING_REFERENCE := 25.0
const _STIFFNESS := 12.0
const _MIN_DAMPING := 1.5
const _MAX_DAMPING := 10.0
const _SAG := 3.0
const _BOUNCE := 0.5
# 兩隻眼睛的晃法稍微不一樣，看起來才像真的玩具眼睛
const _EYE_VARIATION := [Vector2(1.0, 1.0), Vector2(0.85, 1.15)]
# 一幀內速度變化超過這個值就當作瞬間移動（重生、傳送），不拿來甩眼珠
const _TELEPORT_SPEED := 2000.0

var _drawer: Node2D = null
var _pupils: Array = [Vector2.ZERO, Vector2.ZERO]   # 眼珠偏離中心多少（眼眶可活動範圍 = 1），用畫面上的方向記
var _pupil_speeds: Array = [Vector2.ZERO, Vector2.ZERO]
var _last_velocity: Vector2 = Vector2.ZERO
var _look_dir: int = 0              # 最後一次移動的方向（畫面上的左 -1／右 1），還沒動過是 0
var _turn_offset: Vector2 = Vector2.ZERO   # 轉頭時眼睛整組偏移多少（畫眼睛那個節點自己的座標）

# 持續型：拖進來就一直作用
func _is_continuous() -> bool:
	return true

# 在 Visual 底下建一個畫眼睛用的節點，放在這個組件現在的位置上（跟著 Visual 翻轉、縮放）
func _on_setup() -> void:
	if player.visual == null:
		push_warning("[%s] 找不到角色的 Visual 節點，咕嚕眼畫不出來" % name)
		printerr("⚠ [%s] 請先在 Player 底下放一個 Visual 節點，裡面放角色圖" % name)
		return
	if _drawer == null or not is_instance_valid(_drawer):
		_drawer = Node2D.new()
		_drawer.name = "%s_Eyes" % name
		_drawer.draw.connect(func(): _draw_eyes(_drawer, _local_pupils(_drawer), _turn_offset))
		player.visual.add_child(_drawer)
	var visual_scale: Vector2 = player.visual.scale.abs()
	_drawer.position = player.visual.to_local(global_position)
	_drawer.scale = Vector2(1.0 / maxf(visual_scale.x, 0.01), 1.0 / maxf(visual_scale.y, 0.01))
	_listen(player.direction_changed, func(dir: int): _look_dir = dir)
	_reset_pupils()

# 每個物理幀：眼睛滑向臉朝前進方向的那一側；眼珠有慣性，角色速度一變就往反方向甩，彈簧慢慢拉回中間，碰到眼眶反彈
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _drawer == null or not is_instance_valid(player):
		return
	_drawer.visible = _is_juice_on()
	if not _drawer.visible:
		return
	_update_turn(delta)
	var velocity: Vector2 = player.velocity
	var change: Vector2 = velocity - _last_velocity
	_last_velocity = velocity
	if change.length() > _TELEPORT_SPEED:
		change = Vector2.ZERO
	var down: Vector2 = -player.up_direction
	var damping := lerpf(_MAX_DAMPING, _MIN_DAMPING, wobble)
	for i in 2:
		var variation: Vector2 = _EYE_VARIATION[i]
		var speed: Vector2 = _pupil_speeds[i]
		var pos: Vector2 = _pupils[i]
		# 慣性：角色往哪邊加速，眼珠相對眼眶就往反方向跑
		speed -= change / _SWING_REFERENCE * wobble * variation.x
		speed += (down * _SAG - pos * _STIFFNESS * variation.y - speed * damping) * delta
		pos += speed * delta
		if pos.length() > 1.0:
			var normal := pos.normalized()
			pos = normal
			var outward := speed.dot(normal)
			if outward > 0.0:
				speed -= normal * outward * (1.0 + _BOUNCE)
		_pupils[i] = pos
		_pupil_speeds[i] = speed
	_drawer.queue_redraw()

# 轉頭：眼睛整組慢慢滑到最後移動方向那一側（畫面上的方向，角色翻面時一樣滑向前進的那邊）；擺正中間時滑回原位
func _update_turn(delta: float) -> void:
	var target := Vector2.ZERO
	if look == _LOOK_TURN and _look_dir != 0:
		var side: Vector2 = _to_local_direction(_drawer, Vector2(_look_dir, 0.0))
		target = Vector2(signf(side.x), 0.0) * eye_size * _TURN_DISTANCE
	_turn_offset = _turn_offset.lerp(target, 1.0 - exp(-_TURN_SPEED * delta))

# 眼珠回到中間、停止晃動，眼睛回到原位
func _reset_pupils() -> void:
	for i in 2:
		_pupils[i] = Vector2.ZERO
		_pupil_speeds[i] = Vector2.ZERO
	_look_dir = 0
	_turn_offset = Vector2.ZERO
	_last_velocity = player.velocity if is_instance_valid(player) else Vector2.ZERO

# 重生時眼珠回正
func _on_reset() -> void:
	_reset_pupils()

# 把畫面上的眼珠偏移換成畫眼睛那個節點自己的方向（角色左右、上下翻面時眼珠才會往畫面上正確的方向甩）
func _local_pupils(canvas: Node2D) -> Array:
	var result := []
	for p in _pupils:
		result.append(_to_local_direction(canvas, p))
	return result

# 把畫面上的方向換成某個節點自己的方向（含左右、上下翻面與傾斜，不含縮放）
func _to_local_direction(canvas: Node2D, v: Vector2) -> Vector2:
	var t := canvas.get_global_transform()
	return Vector2(t.x.normalized().dot(v), t.y.normalized().dot(v))

# 在指定的節點上畫眼睛：眼白（白圓＋黑框）＋黑眼珠，pupils 是每隻眼睛的眼珠偏移（可活動範圍 = 1），offset 是轉頭的偏移
func _draw_eyes(canvas: CanvasItem, pupils: Array, offset: Vector2) -> void:
	var pupil_radius := eye_size * pupil_size
	var room := maxf(eye_size - pupil_radius - _OUTLINE * 0.5, 0.0)
	var centers := _eye_centers()
	for i in centers.size():
		var center: Vector2 = centers[i] + offset
		canvas.draw_circle(center, eye_size, Color.WHITE)
		canvas.draw_arc(center, eye_size, 0.0, TAU, 24, Color.BLACK, _OUTLINE)
		canvas.draw_circle(center + pupils[i] * room, pupil_radius, Color.BLACK)

# 回傳每隻眼睛的中心（相對於這個組件的位置）
func _eye_centers() -> Array:
	if eye_count == _ONE_EYE:
		return [Vector2.ZERO]
	var half := eye_size * (1.0 + _GAP * 0.5)
	return [Vector2(-half, 0.0), Vector2(half, 0.0)]

# 編輯器裡直接畫出眼睛（眼珠稍微往下垂），拖節點就能決定眼睛的位置；執行時改由 Visual 底下的節點畫
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var sag := Vector2(0.0, _SAG / _STIFFNESS)
	_draw_eyes(self, [sag, sag], Vector2.ZERO)

# 拔掉組件時把畫在 Visual 底下的眼睛一起拿掉
func _exit_tree() -> void:
	super()
	if Engine.is_editor_hint():
		return
	if _drawer and is_instance_valid(_drawer):
		_drawer.queue_free()
	_drawer = null
