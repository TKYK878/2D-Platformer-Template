@tool
extends Node2D

# 崩塌地板：實心，踩上去後過 break_delay 秒後碎裂消失；依 respawn_time
# 決定要不要重生（0 表示不重生）。拖進場景就能用，不用連任何線。

## 踩上去後幾秒碎裂（正式倒數時間）
@export_range(0.1, 5.0) var break_delay: float = 0.6

## 碎裂後幾秒重生，0 表示不會重生
@export_range(0.0, 10.0) var respawn_time: float = 3.0

## 誰踩得動：只有玩家／任何物體（玩家與箱子）／除了玩家／自訂物件（依群組）
@export_enum("只有玩家", "任何物體", "除了玩家", "自訂物件") var triggered_by: int = 0:
	set(value):
		triggered_by = value
		notify_property_list_changed()  # 切換時刷新 Inspector，顯示／隱藏附加欄位

## 選「自訂物件」時，只有屬於這個群組的物體會觸發
var custom_group: StringName = &""

## 選「只有玩家」或「任何物體」時可用：開啟後玩家必須變大（size_factor > 1.0）才能觸發
var check_player_size: bool = true

## 開始碎裂時發出，給學員自己接特效／音效用
signal crumbled

const _WHO_PLAYER_ONLY := 0
const _WHO_ANY := 1
const _WHO_EXCEPT_PLAYER := 2
const _WHO_CUSTOM := 3
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

# 依 triggered_by 動態顯示欄位：
# custom_group 只在「自訂物件」顯示；check_player_size 只在「只有玩家／任何物體」顯示
func _get_property_list() -> Array[Dictionary]:
	var group_usage := PROPERTY_USAGE_DEFAULT if triggered_by == _WHO_CUSTOM else PROPERTY_USAGE_STORAGE
	var size_usage := PROPERTY_USAGE_DEFAULT if (triggered_by == _WHO_PLAYER_ONLY or triggered_by == _WHO_ANY) else PROPERTY_USAGE_STORAGE
	return [
		{
			"name": "custom_group",
			"type": TYPE_STRING_NAME,
			"usage": group_usage,
		},
		{
			"name": "check_player_size",
			"type": TYPE_BOOL,
			"usage": size_usage,
		},
	]

# 設定碰撞層／遮罩，記住外觀原始位置
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("signal_source")
	_visual_origin = _visual.position
	_detector.collision_layer = 0
	if triggered_by == _WHO_CUSTOM:
		_detector.collision_mask = 0xFFFFFFFF  # 自訂物件可能在任何圖層，交給群組過濾
	else:
		_detector.collision_mask = (1 << 0) | (1 << 2)  # 圖層 1「玩家」、圖層 3「箱子」
	_detector.body_entered.connect(_on_detector_entered)

# 玩家的體型夠不夠格觸發：沒開 check_player_size 就一律通過
func _player_size_ok(player: Node) -> bool:
	if not check_player_size:
		return true
	var player_size_factor = player.get("size_factor")
	# 確保必須確實取得 size_factor 且大於 1.0 才能踩碎
	return player_size_factor != null and player_size_factor > 1.0

# 判斷這個 body 算不算踩得動，依 triggered_by 過濾
func _is_valid(body: Node) -> bool:
	match triggered_by:
		_WHO_PLAYER_ONLY:
			return body.is_in_group("player") and _player_size_ok(body)
		_WHO_ANY:
			if body.is_in_group("player"):
				return _player_size_ok(body)
			return body.is_in_group("box")
		_WHO_EXCEPT_PLAYER:
			return not body.is_in_group("player")
		_WHO_CUSTOM:
			if custom_group == &"":
				return false
			return body.is_in_group(custom_group)
	return false

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

# 每幀檢查上方有沒有符合條件的物體（例如玩家站上來之後才變大）；倒數期間讓外觀小幅度隨機抖動
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_check_overlapping()
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
		_after(respawn_time, _respawn_and_check)

# 重生：恢復碰撞、外觀與觸發狀態
func _respawn() -> void:
	_is_broken = false
	_is_triggered = false
	_shape.set_deferred("disabled", false)
	_visual.visible = true
	_visual.position = _visual_origin

# 計時器重生：長回來之後立刻檢查有沒有東西還站在上面（之後每幀也會持續檢查）
func _respawn_and_check() -> void:
	_respawn()
	_check_overlapping()

# 掃描偵測區內現有的物體，有符合條件的就直接開始碎裂倒數
func _check_overlapping() -> void:
	if _is_triggered or _is_broken:
		return
	for body in _detector.get_overlapping_bodies():
		if _is_valid(body):
			_is_triggered = true
			_start_break_countdown()
			return

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
