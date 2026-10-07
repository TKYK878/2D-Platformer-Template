@tool
extends Node2D

# 崩塌地板：實心，踩上去後過 break_delay 秒後碎裂消失；依 respawn_time
# 決定要不要重生（0 表示不重生）。拖進場景就能用，不用連任何線。

## 踩上去後幾秒碎裂（正式倒數時間）
@export_range(0.1, 5.0) var break_delay: float = 0.6

## 碎裂後幾秒重生，0 表示不會重生
@export_range(0.0, 10.0) var respawn_time: float = 3.0

## 誰踩得動：只有玩家會觸發、任何物體（含箱子）都會觸發
@export_enum("只有玩家", "任何物體") var triggered_by: int = 0

## 開始碎裂時發出，給學員自己接特效／音效用
signal crumbled

const _WHO_PLAYER_ONLY := 0
const _SHAKE_AMOUNT := 2.0
const _SIGNAL_LINE_COLOR := Color(1.0, 0.85, 0.2, 0.85)

@onready var _shape: CollisionShape2D = $Body/CollisionShape2D
@onready var _visual: ColorRect = $Visual
@onready var _detector: Area2D = $Detector

var _visual_origin: Vector2
var _is_triggered: bool = false
var _is_broken: bool = false
var _shake_time_left: float = 0.0
var _generation: int = 0  # 每次 reset() 加一，讓 reset 之前排好的碎裂／重生計時器失效

# 設定碰撞層／遮罩，記住外觀原始位置
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("signal_source")
	_visual_origin = _visual.position
	_detector.collision_layer = 0
	_detector.collision_mask = (1 << 0) | (1 << 2)  # 圖層 1「玩家」、圖層 3「箱子」
	_detector.body_entered.connect(_on_detector_entered)

# 判斷這個 body 算不算踩得動，依 triggered_by 過濾
func _is_valid(body: Node) -> bool:
	if triggered_by == _WHO_PLAYER_ONLY:
		if not body.is_in_group("player"):
			return false
		var player_size_factor = body.get("size_factor")
		# 確保必須確實取得 size_factor 且大於 1.0 才能踩碎
		if player_size_factor == null or player_size_factor <= 1.0:
			return false
		return true
	return body.is_in_group("player") or body.is_in_group("box")

# 有東西踩上來：直接開始碎裂倒數
func _on_detector_entered(body: Node) -> void:
	if _is_triggered or _is_broken or not _is_valid(body):
		return
	_is_triggered = true
	_start_break_countdown()

# 開始正式的碎裂倒數
func _start_break_countdown() -> void:
	if _is_broken:
		return
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

# 倒數期間讓外觀小幅度隨機抖動
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if _shake_time_left <= 0.0:
		return
	_shake_time_left -= delta
	if _shake_time_left <= 0.0:
		_visual.position = _visual_origin
		return
		
	_visual.position = _visual_origin + Vector2(
		randf_range(-_SHAKE_AMOUNT, _SHAKE_AMOUNT),
		randf_range(-_SHAKE_AMOUNT, _SHAKE_AMOUNT)
	)

# 真正碎裂：關閉碰撞、隱藏外觀、發出訊號，依 respawn_time 決定要不要重生
func _break() -> void:
	if _is_broken:
		return
	_is_broken = true
	_shape.disabled = true
	_visual.visible = false
	crumbled.emit()
	if respawn_time > 0.0:
		_after(respawn_time, _respawn)

# 重生：恢復碰撞、外觀與觸發狀態
func _respawn() -> void:
	_is_broken = false
	_is_triggered = false
	_shape.set_deferred("disabled", false)
	_visual.visible = true
	_visual.position = _visual_origin

# 編輯畫面用：幫這個零件自己發出的每個訊號的每條連接畫一條虛線到目標節點
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	_draw_signal_lines(crumbled)

# 畫某個訊號目前所有連接的虛線
func _draw_signal_lines(sig: Signal) -> void:
	for conn in sig.get_connections():
		var callable: Callable = conn["callable"]
		var target: Object = callable.get_object()
		if target is Node2D:
			var target_node: Node2D = target
			draw_dashed_line(Vector2.ZERO, to_local(target_node.global_position), _SIGNAL_LINE_COLOR, 2.0, 6.0)
