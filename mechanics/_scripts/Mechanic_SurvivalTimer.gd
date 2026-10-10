extends MechanicBase

# 存活計時：從掛上這張卡開始計時，存活到 target_seconds 就算過關，發出
# Events.level_cleared。倒數計時 UI 由組件自己加到畫面右上角的共用容器，學員不用擺。
# 拖進 Player → Mechanics 底下就能用，不用連任何線。

## 存活幾秒後算過關
@export_range(5.0, 60.0) var target_seconds: float = 10.0

## 要不要在畫面上顯示倒數計時
@export var show_timer: bool = true

## 存活時間到、過關時發出
signal cleared

var _elapsed: float = 0.0
var _cleared: bool = false

var _label: Label = null

# 視需要生成倒數計時的 UI，把剩餘秒數公開給 HUD
func _on_setup() -> void:
	if show_timer:
		_ensure_hud()
	_refresh_label()

# 累計存活時間，達標就發出過關事件，只觸發一次
func apply(ctx: MoveContext) -> void:
	if _cleared:
		return
	_elapsed = minf(target_seconds, _elapsed + ctx.delta)
	_refresh_label()
	if _elapsed >= target_seconds:
		_cleared = true
		Events.level_cleared.emit()
		cleared.emit()
		Events.mechanic_event.emit("Mechanic_SurvivalTimer", "cleared")

# 重生時計時歸零重新開始
func on_respawn() -> void:
	_elapsed = 0.0
	_cleared = false
	_refresh_label()

# 在畫面右上角的共用容器加一行倒數計時，避免跟 Stats HUD（左上角）、其他卡的預設 UI 疊在一起
func _ensure_hud() -> void:
	if _label != null:
		return
	_label = Label.new()
	StatsHud.get_corner(StatsHud.CORNER_TOP_RIGHT).add_child(_label)

# 把剩餘秒數公開給 HUD，並同步預設的倒數計時文字；學員的 HUD 有顯示存活倒數時預設的讓位
func _refresh_label() -> void:
	var remaining: float = maxf(0.0, target_seconds - _elapsed)
	HudData.publish(HudData.SURVIVAL, remaining, target_seconds)
	if _label == null:
		return
	_label.text = "存活 %.1f" % remaining
	_label.visible = not HudData.is_claimed(HudData.SURVIVAL)

# 卡片被拔掉時，存活倒數不再是顯示來源，右上角的倒數計時也一起拿掉
func _exit_tree() -> void:
	HudData.remove_source(HudData.SURVIVAL)
	if is_instance_valid(_label):
		_label.queue_free()
