@tool
extends JuiceBase

# 傾斜：跑步時身體往前傾，越快傾越多，停下來慢慢回正。拖進 Player → Juice 底下就一直作用（持續型）。
# 以腳底為中心傾斜；重力翻轉、自動奔跑翻面後一樣是往前進的方向傾。

## 跑到最快時往前傾幾度
@export_range(0.0, 30.0) var strength: float = 12.0
## 傾斜、回正要花多久（秒），數值越小反應越快
@export_range(0.03, 0.5) var duration: float = 0.12
## 勾選時在空中也會傾斜；不勾的話跳起來就回正
@export var in_air: bool = true

var _angle: float = 0.0

# 持續型：拖進來就一直作用
func _is_continuous() -> bool:
	return true

# 每幀把傾斜角度慢慢追向目標：水平速度越快越傾，停下來回到 0
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(player) or player.visual == null:
		return
	if not _is_juice_on():
		if _angle != 0.0:
			_on_reset()
			player.clear_juice(self)
		return
	var target := 0.0
	if not player.is_dead() and (in_air or player.is_on_ground()):
		target = _target_angle()
	_angle = lerpf(_angle, target, 1.0 - exp(-delta / maxf(duration, 0.01) * 3.0))
	if absf(_angle) < 0.001 and target == 0.0:
		if _angle != 0.0:
			_angle = 0.0
			player.clear_juice(self)
		return
	player.set_juice_tilt(self, _angle)

# 依水平速度算出要傾幾度（弧度），換成角色圖自己的方向：
# 畫面上「頭往前進方向倒」，重力翻轉（頭朝下）、左右翻面時方向要跟著換
func _target_angle() -> float:
	var speed_ratio := clampf(player.velocity.x / maxf(player.move_speed, 1.0), -1.0, 1.0)
	var screen_angle := deg_to_rad(strength) * speed_ratio
	if player.up_direction.y > 0.0:
		screen_angle = -screen_angle
	var t: Transform2D = player.visual.get_global_transform()
	if t.determinant() < 0.0:
		screen_angle = -screen_angle
	return screen_angle

# 重生、關掉時立刻回正
func _on_reset() -> void:
	_angle = 0.0
