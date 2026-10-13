@tool
extends Node2D

# 崩塌地板：實心，踩上去後先抖動提示，過 break_delay 秒後碎裂消失；依 respawn_time
# 決定要不要重生（0 表示不重生）。拖進場景就能用，不用連任何線。

## 踩上去後幾秒碎裂
@export_range(0.1, 5.0) var break_delay: float = 0.6

## 碎裂後幾秒重生，0 表示不會重生
@export_range(0.0, 10.0) var respawn_time: float = 3.0

## 誰踩得動：只有玩家會觸發、任何物體（含箱子）都會觸發
@export_enum("只有玩家", "任何物體") var triggered_by: int = 0

## 開始碎裂時發出，給學員自己接特效／音效用
signal crumbled

const _WHO_PLAYER_ONLY := 0
const _SHAKE_AMOUNT := 2.0

@onready var _shape: CollisionShape2D = $Body/CollisionShape2D
@onready var _detector: Area2D = $Detector

var _skin: SkinLink = null
var _is_triggered: bool = false
var _is_broken: bool = false
var _shake_time_left: float = 0.0
var _generation: int = 0  # 每次 reset() 加一，讓 reset 之前排好的碎裂／重生計時器失效

# 設定碰撞層／遮罩；底下有皮就換上皮
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("signal_source")
	_skin = SkinLink.new(self, $Visual)
	_detector.collision_layer = 0
	_detector.collision_mask = Layers.PLAYER | Layers.BOX
	_detector.body_entered.connect(_on_detector_entered)

# 判斷這個 body 算不算踩得動，依 triggered_by 過濾
func _is_valid(body: Node) -> bool:
	if triggered_by == _WHO_PLAYER_ONLY:
		return body.is_in_group("player")
	return body.is_in_group("player") or body.is_in_group("box")

# 有東西踩上來：開始倒數，過 break_delay 秒後碎裂
func _on_detector_entered(body: Node) -> void:
	if _is_triggered or _is_broken or not _is_valid(body):
		return
	_is_triggered = true
	_shake_time_left = break_delay
	_after(break_delay, _break)

# 過 seconds 秒後呼叫 callback；中間如果被 reset() 過就取消
func _after(seconds: float, callback: Callable) -> void:
	var generation := _generation
	get_tree().create_timer(seconds).timeout.connect(func():
		if generation == _generation:
			callback.call()
	)

# 把自己恢復到關卡開始時的狀態：取消抖動與碎裂倒數、碎掉的長回來（重生處理者呼叫）
func reset() -> void:
	_generation += 1
	_shake_time_left = 0.0
	_respawn()

# 倒數期間讓外觀（有皮就是皮）小幅度隨機抖動，給玩家看得到的碎裂提示；編輯畫面則持續請求重畫，
# 讓訊號連接的虛線跟著變化即時更新
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if _shake_time_left <= 0.0:
		return
	_shake_time_left -= delta
	if _shake_time_left <= 0.0:
		_skin.set_shake(Vector2.ZERO)
		return
	_skin.set_shake(Vector2(
		randf_range(-_SHAKE_AMOUNT, _SHAKE_AMOUNT),
		randf_range(-_SHAKE_AMOUNT, _SHAKE_AMOUNT)
	))

# 真正碎裂：關閉碰撞、隱藏外觀、發出訊號，依 respawn_time 決定要不要重生
func _break() -> void:
	if _is_broken:
		return
	_is_broken = true
	_shape.disabled = true
	_skin.set_visible(false)
	crumbled.emit()
	if respawn_time > 0.0:
		_after(respawn_time, _respawn)

# 重生：恢復碰撞、外觀與觸發狀態
func _respawn() -> void:
	_is_broken = false
	_is_triggered = false
	_shape.set_deferred("disabled", false)
	_skin.set_visible(true)
	_skin.set_shake(Vector2.ZERO)

# 編輯畫面用：幫這個零件自己發出的每個訊號的每條連接畫一條虛線到目標節點
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	SignalLines.draw(self, crumbled)
