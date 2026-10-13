@tool
extends Node2D

# 門：實心，關閉時擋住玩家，打開時碰撞消失、變半透明。
# 「由訊號控制」模式不會自動檢查任何東西，只能靠 activate/deactivate/toggle 這三個函式控制——
# 在「節點」面板把別的零件的訊號連過來（例如按鈕的 turned_on）就能組合出機關；
# 「鑰匙」「金幣數量」「自訂數值」模式則是玩家碰到門的時候自動檢查 Stats。
# 自訂數值可以自己打數值種類名稱（例如「星星」），名稱檢查走共用工具 NameCheck。

## 開門方式：由其他零件的訊號控制、玩家帶著足夠的鑰匙、玩家帶著足夠的金幣，或自己指定一種數值
@export_enum("由訊號控制", "鑰匙", "金幣數量", "自訂數值") var open_mode: int = 0:
	set(value):
		open_mode = value
		notify_property_list_changed()
		update_configuration_warnings()

## 自訂數值的種類名稱，例如「星星」。要跟道具、ValueSettings 用的名稱打一樣的字；
## 頭尾空白、全形字會自動整理，場景裡找不到這個名稱時場景樹會出現黃色驚嘆號
@export var custom_kind: String = "":
	set(value):
		custom_kind = value
		update_configuration_warnings()

## 鑰匙、金幣或自訂數值模式下，需要達到的數量
@export_range(1, 99) var required_amount: int = 1

## 打開時是否要消耗掉那些鑰匙／金幣／自訂數值
@export var consume: bool = true

## 一開始就是開著的
@export var start_open: bool = false

## 開啟時發出
signal opened
## 關閉時發出
signal closed

const _MODE_SIGNAL := 0
const _MODE_KEY := 1
const _MODE_COIN := 2
const _MODE_CUSTOM := 3
# 編輯器裡每隔幾秒重新檢查一次名稱，學員改了道具、ValueSettings 之後黃色警告會跟著更新
const _WARNING_REFRESH_SECONDS := 1.0

@onready var _shape: CollisionShape2D = $Body/CollisionShape2D
@onready var _detector: Area2D = $Detector

var _is_open: bool = false
var _paid: int = 0
var _warning_timer: float = 0.0
var _skin: SkinLink = null

## 開啟
func activate() -> void:
	_set_open(true)

## 關閉
func deactivate() -> void:
	_set_open(false)

## 切換
func toggle() -> void:
	_set_open(not _is_open)

# 依 open_mode 決定要不要監聽玩家碰門，並套用一開始的開關狀態；底下有皮就換上皮
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_skin = SkinLink.new(self, $Visual)
	add_to_group("signal_source")
	if open_mode != _MODE_SIGNAL:
		_detector.body_entered.connect(_on_detector_entered)
	if open_mode == _MODE_CUSTOM:
		_check_custom_kind.call_deferred()
	_is_open = start_open
	_apply_state()

# 鑰匙／金幣門恢復到關卡開始時的狀態（用掉的鑰匙金幣由 rewind_values() 還，重生處理者呼叫）。
# 由訊號控制的門不重置：它的開關是別的零件決定的，重置了會跟控制它的按鈕對不上，可能卡關。
# 鑰匙／金幣設成「死亡不退回」時也不重置：付掉的拿不回來，門再關上就過不去了
func reset() -> void:
	if open_mode == _MODE_SIGNAL:
		return
	if consume and not Stats.is_reset_on_death(_get_kind()):
		return
	_is_open = start_open
	_apply_state()

# 開門時付掉的鑰匙／金幣／自訂數值還給玩家，只還一次（重生處理者呼叫，在 reset() 之前）；設成「死亡不退回」的種類不還
func rewind_values() -> void:
	if _paid <= 0 or not Stats.is_reset_on_death(_get_kind()):
		return
	Stats.add(_get_kind(), _paid)
	_paid = 0

# 鑰匙／金幣／自訂數值模式下，玩家碰到門時檢查 Stats 夠不夠，夠了就開門（自訂名稱空白時永遠不開）
func _on_detector_entered(body: Node) -> void:
	if _is_open or not body.is_in_group("player"):
		return
	var kind := _get_kind()
	if kind == "":
		return
	if not Stats.has_at_least(kind, required_amount):
		return
	if consume and Stats.consume(kind, required_amount):
		_paid += required_amount
	activate()

# 這扇門要檢查的數值種類
func _get_kind() -> String:
	match open_mode:
		_MODE_KEY:
			return "鑰匙"
		_MODE_COIN:
			return "金幣"
		_MODE_CUSTOM:
			return NameCheck.clean(custom_kind)
	return ""

# 回傳這扇門用到的數值種類名稱（整理過，由訊號控制的門是空字串），道具檢查打錯字時用來對照
func get_value_kind() -> String:
	return _get_kind()

# 只有選「自訂數值」時才顯示名稱欄位，沒選到的學員看不到
func _validate_property(property: Dictionary) -> void:
	if property.name == "custom_kind" and open_mode != _MODE_CUSTOM:
		property.usage = PROPERTY_USAGE_NONE

# 編輯器場景樹的黃色驚嘆號：選了「自訂數值」但名稱空白、疑似打錯字，或場景裡沒有道具／ValueSettings 用這個名稱
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if open_mode != _MODE_CUSTOM or not is_inside_tree():
		return warnings
	var root := get_tree().edited_scene_root
	if root == null:
		return warnings
	var message := _custom_kind_problem(root)
	if message != "":
		warnings.append(message)
	return warnings

# 執行時檢查自訂名稱，有問題就印中文警告，不然門會永遠打不開卻沒有任何提示
func _check_custom_kind() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var message := _custom_kind_problem(root)
	if message != "":
		message = "[門] %s：%s" % [name, message]
		push_warning(message)
		print(message)

# 回傳自訂名稱的問題說明（空白、疑似打錯字、場景裡沒人給這個數值），沒問題回傳空字串
func _custom_kind_problem(root: Node) -> String:
	var clean_kind := NameCheck.clean(custom_kind)
	if clean_kind == "":
		return "開門方式選了「自訂數值」，但 custom_kind 是空的，請打上數值種類名稱（例如「星星」），不然這扇門永遠打不開。"
	var others := NameCheck.collect_value_kinds(root, self)
	if clean_kind in others:
		return ""
	var message := "場景裡沒有道具或 ValueSettings 用「%s」這個名稱，這扇門會永遠打不開。現有的數值種類：%s。" % [clean_kind, NameCheck.list_text(others)]
	var similar := NameCheck.find_similar(clean_kind, others)
	if similar != "":
		message += "是不是想打「%s」？" % similar
	return message

# 真正切換開關狀態，狀態沒變就不重複處理
func _set_open(is_open: bool) -> void:
	if is_open == _is_open:
		return
	_is_open = is_open
	_apply_state()
	if is_open:
		opened.emit()
	else:
		closed.emit()

# 把目前的開關狀態套用到碰撞與外觀上（打開時變淡，有皮就換皮的樣子）
func _apply_state() -> void:
	_shape.set_deferred("disabled", _is_open)
	_skin.show_faded(_is_open, 0.35)

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
	SignalLines.draw(self, opened)
	SignalLines.draw(self, closed)
