extends MechanicBase

# 忽大忽小：在小、大兩種體型之間切換，一開始是小的。變大、變小都是腳底不動、往頭頂伸縮，
# 站在地上也能直接變大；變大時如果頭頂或兩旁會卡進地形，會先延後，等空間夠了才真的套用，不會把玩家卡進牆裡。
# 拖進 Player → Mechanics 底下就能用，不用連任何線。

## 什麼時候切換大小
@export_enum("按下按鍵", "隨時間") var trigger_timing: int = 0

## 按下按鍵時用鍵盤、滑鼠按鍵或輸入動作（只有「觸發時機」選按下按鍵時才會顯示這一欄）
@export_enum("鍵盤按鍵", "滑鼠左鍵", "滑鼠右鍵", "滑鼠中鍵", "輸入動作 (Input Action)") var input_type: int = 0

## 按下按鍵時要按哪一鍵切換（「觸發時機」選按下按鍵、「按鍵種類」選鍵盤按鍵時才會顯示這一欄）
@export var key: Key = KEY_SHIFT

## 輸入動作名稱（如設定在 Input Map 的動作名稱，選「輸入動作」時才會顯示這一欄）
@export var action_name: StringName = &"toggle_size"

## 變小時的體型倍率
@export_range(0.3, 1.0) var small_scale: float = 0.5

## 變大時的體型倍率
@export_range(1.0, 2.5) var big_scale: float = 1.8

## 體型是否連動推力、擊退、跳躍力
@export var size_affects_stats: bool = true

## 變大之後發出
signal grew
## 變小之後發出
signal shrank
## 還在等空間變大時又按一次、取消了變大之後發出（可以接「無效」提示）
signal grow_canceled

const _TRIGGER_KEY := 0
const _AUTO_INTERVAL := 3.0
# 檢查變大後會不會卡進地形時，形狀每邊縮一點，避免剛好貼著地板、牆壁也被當成重疊
const _OVERLAP_MARGIN := 1.0

var _is_big: bool = false
var _pending_factor: float = 0.0
var _auto_time_left: float = _AUTO_INTERVAL

# 依 trigger_timing 決定要不要顯示按鍵欄位；依 input_type 控制 key 與 action_name 欄位的顯示
func _validate_property(property: Dictionary) -> void:
	if property.name == "input_type" and trigger_timing != _TRIGGER_KEY:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "key" and (trigger_timing != _TRIGGER_KEY or input_type != 0):
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "action_name" and (trigger_timing != _TRIGGER_KEY or input_type != 4):
		property.usage = PROPERTY_USAGE_NONE

# 套用一開始的體型（小），依觸發時機接對應的按鍵
func _on_setup() -> void:
	player.set_size_factor(small_scale)
	if trigger_timing == _TRIGGER_KEY:
		if input_type == 0:
			InputRouter.warn_if_dangerous_key(key, "[忽大忽小]")
			InputRouter.bind_input(self, input_type, key, InputRouter.PRESSED, _toggle)
		elif input_type in [1, 2, 3]:
			InputRouter.bind_input(self, input_type, key, InputRouter.PRESSED, _toggle)

# 隨時間模式的倒數；有待處理的變大請求時，每幀重新檢查空間夠不夠；處理 Input Action (如手把按鈕)
func apply(ctx: MoveContext) -> void:
	if trigger_timing == _TRIGGER_KEY:
		if input_type == 4 and Input.is_action_just_pressed(action_name):
			_toggle()
	else:
		_auto_time_left -= ctx.delta
		if _auto_time_left <= 0.0:
			_auto_time_left = _AUTO_INTERVAL
			_toggle()

	if _pending_factor != 0.0 and _try_apply_size(_pending_factor):
		_pending_factor = 0.0

	if size_affects_stats:
		_apply_stat_scales(ctx)

# 重生時回到一開始的體型（小），取消還沒套用的變大請求，自動切換的倒數重新開始
func on_respawn() -> void:
	_is_big = false
	_pending_factor = 0.0
	_auto_time_left = _AUTO_INTERVAL
	player.set_size_factor(small_scale)

# 在小、大兩種體型之間切換；還在等空間變大時又切換，就當作取消變大（不算變小）
func _toggle() -> void:
	if _pending_factor != 0.0:
		_pending_factor = 0.0
		_is_big = false
		grow_canceled.emit()
		Events.mechanic_event.emit("Mechanic_SizeShift", "grow_canceled")
		return
	var target := small_scale if _is_big else big_scale
	_is_big = not _is_big
	if target > player.size_factor:
		if not _try_apply_size(target):
			_pending_factor = target
	else:
		_try_apply_size(target)

# 嘗試套用體型（腳底不動）：變大時若會跟地形重疊就先不套用，等空間足夠再套；回傳有沒有真的套用
func _try_apply_size(target: float) -> bool:
	if is_equal_approx(target, player.size_factor):
		return true
	if target > player.size_factor and _would_overlap_terrain(target):
		return false
	player.global_position += _feet_anchor_offset(target)
	player.set_size_factor(target)
	if target > 1.0:
		grew.emit()
	else:
		shrank.emit()
	Events.mechanic_event.emit("Mechanic_SizeShift", "grew" if target > 1.0 else "shrank")
	return true

# 換成目標體型時，玩家要往頭頂方向移多少，腳底才會留在原地（碰撞形狀高度變化的一半）
func _feet_anchor_offset(target_factor: float) -> Vector2:
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or not (col.shape is RectangleShape2D):
		return Vector2.ZERO
	var height: float = (col.shape as RectangleShape2D).size.y
	var height_change: float = height * (target_factor / player.size_factor - 1.0)
	return player.up_direction * height_change * 0.5

# 用縮放後的碰撞形狀在腳底不動的位置查一次，看看會不會卡進地形
func _would_overlap_terrain(target_factor: float) -> bool:
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or not (col.shape is RectangleShape2D):
		return false
	var current_size: Vector2 = (col.shape as RectangleShape2D).size
	var ratio: float = target_factor / player.size_factor
	var shape := RectangleShape2D.new()
	shape.size = (current_size * ratio - Vector2.ONE * _OVERLAP_MARGIN * 2.0).max(Vector2.ONE)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, col.global_position + _feet_anchor_offset(target_factor))
	query.collision_mask = Layers.TERRAIN
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	return not space_state.intersect_shape(query, 1).is_empty()

# 依目前體型調整推力、擊退、跳躍力倍率：大隻推得動箱子、比較不容易被擊退、跳得比較低；
# 小隻跳得比較高、比較容易被敵人撞飛
func _apply_stat_scales(ctx: MoveContext) -> void:
	var f: float = player.size_factor
	if f > 1.0 and big_scale > 1.0:
		var t := (f - 1.0) / (big_scale - 1.0)
		ctx.push_scale *= lerpf(1.0, 1.6, t)
		ctx.knockback_scale *= lerpf(1.0, 0.6, t)
		ctx.jump_scale *= lerpf(1.0, 0.7, t)
	elif f < 1.0 and small_scale < 1.0:
		var t := (1.0 - f) / (1.0 - small_scale)
		ctx.jump_scale *= lerpf(1.0, 1.3, t)
		ctx.knockback_scale *= lerpf(1.0, 1.6, t)
