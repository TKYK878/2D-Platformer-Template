@tool
extends Area2D

# 道具：感應，玩家碰到時依 kind 幫對應的數值種類加值。血包直接加血量，Stats 本身就會
# 把數值夾在上限以內，不會超過。拖進場景就能用，不用連任何線。
# 種類選「自訂」時可以自己打數值種類名稱（例如「星星」），名稱檢查走共用工具 NameCheck。

## 種類：金幣、鑰匙、血包、分數，或選「自訂」自己取名字
@export_enum("金幣", "鑰匙", "血包", "分數", "自訂") var kind: int = 0:
	set(value):
		kind = value
		notify_property_list_changed()
		update_configuration_warnings()

## 自訂的數值種類名稱，例如「星星」。要跟 ValueSettings、門用的名稱打一樣的字；
## 頭尾空白、全形字會自動整理，打錯字時場景樹會出現黃色驚嘆號
@export var custom_kind: String = "":
	set(value):
		custom_kind = value
		update_configuration_warnings()

## 撿到時增加的數量
@export_range(1, 99) var amount: int = 1

## 撿到後是否在畫面左上角 HUD 顯示此數值
@export var show_in_hud: bool = true

## 撿到時發出，給學員自己接特效／音效用
signal collected

const _KIND_HEALTH := 2
const _KIND_CUSTOM := 4
# 下拉選項對應的數值種類名稱，血包對應到內建的「血量」（Stats.HEALTH_KIND）
const _KIND_NAMES := ["金幣", "鑰匙", "血量", "分數"]
# 編輯器裡每隔幾秒重新檢查一次名稱，學員改了別的道具、ValueSettings 之後黃色警告會跟著更新
const _WARNING_REFRESH_SECONDS := 1.0

var _collected: bool = false
var _value_returned: bool = false
var _stats_kind: String = ""
var _warning_timer: float = 0.0

# 依 kind 算出對應的 Stats 種類名稱，設定碰撞層／遮罩，只偵測玩家
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("signal_source")
	_stats_kind = _resolve_stats_kind()
	if not show_in_hud and _stats_kind != "" and _stats_kind != Stats.HEALTH_KIND:
		Stats.set_hud_visible(_stats_kind, false)
	collision_layer = Layers.SENSOR
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)
	if kind == _KIND_CUSTOM:
		_check_custom_kind.call_deferred()

# 回傳這個道具加值的數值種類名稱（整理過，自訂但沒打字時是空字串），檢查名稱時用來對照
func get_value_kind() -> String:
	if kind == _KIND_CUSTOM:
		return NameCheck.clean(custom_kind)
	return _KIND_NAMES[kind]

# 把 Inspector 的種類選項換成 Stats 認得的字串，血包對應到內建的血量種類
func _resolve_stats_kind() -> String:
	if kind == _KIND_HEALTH:
		return Stats.HEALTH_KIND
	return get_value_kind()

# 玩家碰到時加值、發出訊號，然後把自己藏起來（不刪除，重生時才能放回來）；
# 自訂名稱空白時不加值，但照樣發訊號
func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	if _stats_kind != "":
		if _stats_kind != Stats.HEALTH_KIND:
			Stats.set_hud_visible(_stats_kind, show_in_hud)
		Stats.add(_stats_kind, amount)
	collected.emit()
	Events.item_collected.emit(global_position)
	visible = false

# 把自己恢復到關卡開始時的狀態：被撿走的放回來（數值由 rewind_values() 退，重生處理者呼叫）。
# 數值設成「死亡不退回」的道具不放回來，不然同一個可以一直重複撿
func reset() -> void:
	if not _rewinds_on_death():
		return
	_collected = false
	_value_returned = false
	visible = true

# 被撿走過的話，把當初加的數值扣回來；同一次撿只扣一次（重生處理者呼叫，在 reset() 之前）
func rewind_values() -> void:
	if not _collected or _value_returned or not _rewinds_on_death():
		return
	_value_returned = true
	if _stats_kind != Stats.HEALTH_KIND and _stats_kind != "":
		Stats.add(_stats_kind, -amount)

# 這個道具的數值死掉時要不要退：血包不退（重生本來就補滿血）、設成「死亡不退回」的種類也不退
func _rewinds_on_death() -> bool:
	return _stats_kind == Stats.HEALTH_KIND or Stats.is_reset_on_death(_stats_kind)

# 只有選「自訂」時才顯示名稱欄位，沒選到的學員看不到
func _validate_property(property: Dictionary) -> void:
	if property.name == "custom_kind" and kind != _KIND_CUSTOM:
		property.usage = PROPERTY_USAGE_NONE

# 編輯器場景樹的黃色驚嘆號：選了「自訂」但名稱空白，或名稱跟場景裡現有的名稱很像但不一樣（可能打錯字）。
# 全新的名稱不算錯：撿到就會自動出現在 HUD
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if kind != _KIND_CUSTOM or not is_inside_tree():
		return warnings
	var root := get_tree().edited_scene_root
	if root == null:
		return warnings
	var message := _custom_kind_problem(root)
	if message != "":
		warnings.append(message)
	return warnings

# 執行時檢查自訂名稱：空白或疑似打錯字印中文警告；全新的名稱只印一行提示，列出現有名稱給學員對照
func _check_custom_kind() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var message := _custom_kind_problem(root)
	if message != "":
		message = "[道具] %s：%s" % [name, message]
		push_warning(message)
		print(message)
		return
	var clean_kind := NameCheck.clean(custom_kind)
	var others := _other_kinds(root)
	if clean_kind not in others:
		print("[道具] %s：新的數值種類「%s」，撿到就會出現在畫面左上角。現有的數值種類：%s" % [name, clean_kind, NameCheck.list_text(others)])

# 回傳自訂名稱的問題說明（空白、疑似打錯字），沒問題回傳空字串
func _custom_kind_problem(root: Node) -> String:
	var clean_kind := NameCheck.clean(custom_kind)
	if clean_kind == "":
		return "種類選了「自訂」，但 custom_kind 是空的，請打上數值種類名稱（例如「星星」），不然撿到也不會加任何數值。"
	var others := _other_kinds(root)
	if clean_kind in others:
		return ""
	var similar := NameCheck.find_similar(clean_kind, others)
	if similar == "":
		return ""
	return "數值種類「%s」跟現有的「%s」很像，是不是想打「%s」？現有的數值種類：%s" % [clean_kind, similar, similar, NameCheck.list_text(others)]

# 除了自己以外，場景裡用到的數值種類名稱，再加上道具下拉選單內建的幾種
func _other_kinds(root: Node) -> Array:
	var kinds := NameCheck.collect_value_kinds(root, self)
	for k in _KIND_NAMES:
		if k not in kinds:
			kinds.append(k)
	return kinds

# 編輯畫面持續請求重畫，讓虛線跟著訊號連接的變化即時更新；每隔一段時間重新檢查自訂名稱
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	queue_redraw()
	_warning_timer += delta
	if _warning_timer >= _WARNING_REFRESH_SECONDS:
		_warning_timer = 0.0
		update_configuration_warnings()

# 編輯畫面用：幫這個零件自己發出的每個訊號的每條連接畫一條虛線到目標節點
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	SignalLines.draw(self, collected)
