extends MechanicBase

# 移動會扣血（其實扣的是體力，不是 Stats 血量）：角色移動時持續消耗體力，停下來才會
# 回復；體力歸零後依 penalty_mode 走不動或變很慢，回到 30% 才解除懲罰。
# 拖進 Player → Mechanics 底下就能用，不用連任何線。

## 體力可以支撐移動幾秒
@export_range(1.0, 10.0) var stamina_seconds: float = 3.0

## 停下來時體力回復的速度倍率
@export_range(0.5, 3.0) var regen_rate: float = 1.0

## 體力耗盡時的懲罰方式
@export_enum("走不動", "變很慢") var penalty_mode: int = 0

## 要不要在畫面上顯示體力條
@export var show_stamina_bar: bool = true

## 體力用光、開始懲罰時發出
signal exhausted
## 體力回復、解除懲罰時發出
signal recovered

const _MOVE_EPSILON := 5.0
const _RECOVER_RATIO := 0.3
const _SLOW_SCALE := 0.3
# 只能往前搭配時，角色永遠在動、沒有「停下來」可言，改成每次跳躍固定扣這個比例的體力，
# 並且不管有沒有在動都持續回復，不然體力扣光後會卡死在懲罰狀態永遠回不來
const _JUMP_DRAIN_RATIO := 1.0 / 3.0
const _AUTO_RUN_SCRIPT := "res://mechanics/_scripts/Mechanic_AutoRun.gd"

var _stamina: float = 0.0
var _exhausted: bool = false
var _jump_drain_mode: bool = false

var _row: HBoxContainer = null
var _bar: ProgressBar = null

# 套用滿體力、偵測「只能往前」要不要換成跳躍扣體力模式、視需要生成體力條
func _on_setup() -> void:
	_stamina = stamina_seconds
	if _has_sibling(_AUTO_RUN_SCRIPT):
		_jump_drain_mode = true
		player.jumped.connect(_on_player_jumped)
		print("[移動會扣血] 偵測到「只能往前」，改成每次跳躍固定扣體力，體力會持續慢慢回復")
	if show_stamina_bar:
		_ensure_hud()
		_refresh_bar()

# 依模式扣體力或回體力，耗盡與解除懲罰的判斷，同步體力條畫面
func apply(ctx: MoveContext) -> void:
	if _jump_drain_mode:
		_stamina = minf(stamina_seconds, _stamina + regen_rate * ctx.delta)
	else:
		var moving: bool = absf(player.velocity.x) > _MOVE_EPSILON
		if moving:
			_stamina = maxf(0.0, _stamina - ctx.delta)
		else:
			_stamina = minf(stamina_seconds, _stamina + regen_rate * ctx.delta)

	if _stamina <= 0.0 and not _exhausted:
		_exhausted = true
		exhausted.emit()
		Events.mechanic_event.emit("Mechanic_Stamina", "exhausted")
	elif _exhausted and _stamina >= stamina_seconds * _RECOVER_RATIO:
		_exhausted = false
		recovered.emit()
		Events.mechanic_event.emit("Mechanic_Stamina", "recovered")

	if _exhausted:
		ctx.speed_scale *= 0.0 if penalty_mode == 0 else _SLOW_SCALE

	_refresh_bar()

# 重生時體力補滿、解除耗盡懲罰
func on_respawn() -> void:
	_stamina = stamina_seconds
	_exhausted = false
	_refresh_bar()

# 跳躍扣體力模式下，Player 每跳一次就扣一次固定體力
func _on_player_jumped() -> void:
	_stamina = maxf(0.0, _stamina - stamina_seconds * _JUMP_DRAIN_RATIO)

# 檢查 Mechanics 容器裡有沒有掛著某個腳本路徑對應的卡
func _has_sibling(script_path: String) -> bool:
	if not player.has_node("Mechanics"):
		return false
	for child in player.get_node("Mechanics").get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path == script_path:
			return true
	return false

# 在畫面左下角的共用容器加一列體力條，避免跟 Stats HUD（左上角）、其他卡的預設 UI 疊在一起
func _ensure_hud() -> void:
	if _row != null:
		return
	_row = HBoxContainer.new()
	var title := Label.new()
	title.text = "體力"
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(80, 12)
	_bar.show_percentage = false
	_bar.max_value = stamina_seconds
	_row.add_child(title)
	_row.add_child(_bar)
	StatsHud.get_corner(StatsHud.CORNER_BOTTOM_LEFT).add_child(_row)

# 把體力公開給 HUD，並把預設體力條同步成目前的體力值；學員的 HUD 有顯示體力時預設體力條讓位
func _refresh_bar() -> void:
	HudData.publish(HudData.STAMINA, _stamina, stamina_seconds)
	if _bar == null:
		return
	_bar.value = _stamina
	_row.visible = not HudData.is_claimed(HudData.STAMINA)

# 卡片被拔掉時，體力不再是顯示來源，左下角的體力條也一起拿掉
func _exit_tree() -> void:
	HudData.remove_source(HudData.STAMINA)
	if is_instance_valid(_row):
		_row.queue_free()
