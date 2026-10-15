extends Node

# 按鍵觸發器：KeySettings 底下的一列自訂按鍵（節點名稱＝這一列的名稱）。依 key_source 決定要自己選一個
# 按鍵、用滑鼠左鍵／右鍵／中鍵，還是跟基本操作（移動/跳躍）或 Input Map 裡的動作共用同一顆鍵；依 trigger 決定什麼
# 時候發出 triggered，學員把 triggered 連到零件的函式。一律用學員按鍵優先權註冊，
# 不會搶走 Player 或機制卡的輸入（見 documents/01a_shared_systems.md §3.5）。

## 關閉時這個觸發器不會生效
@export var enabled: bool = true

## 按鍵來源：自己選一個按鍵、滑鼠按鍵，或跟基本操作（移動/跳躍）共用同一顆鍵
@export_enum("自訂按鍵", "滑鼠左鍵", "滑鼠右鍵", "滑鼠中鍵", "跟基本操作同一顆鍵") var key_source: int = 0

## key_source 選「自訂按鍵」時，要用哪一個按鍵
@export var key: Key = KEY_E

## 跟哪一個基本操作用同一顆鍵（會跟著 KeySettings 改過的按鍵走）。這裡只決定聽哪一顆鍵，
## 按下時基本操作照樣會做，另外再觸發你用 triggered 訊號連的函式。
## 也可以選你在「專案設定 → Input Map」自己加的動作（可以綁手把等其他裝置）
@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin") var same_key_as: String = "jump"

## 什麼時候發出 triggered：按下的那一刻、放開的那一刻，或按住期間每一幀都發
@export_enum("按下時", "放開時", "按住時（每一幀）") var trigger: int = 0

## 依 trigger 選的時機發出，拿去連任何零件的函式（例如門的 toggle）
signal triggered
## 按下的那一幀發出
signal pressed
## 開始按住那一刻發出（時機等同 pressed，名字給知道「按住」概念的人用）
signal hold_started
## 放開、結束按住那一刻發出
signal hold_ended
## 放開的那一幀發出，帶總共按住的秒數（進階用，一般接效果不用管這個參數）
signal released(seconds: float)
## 按著的每個物理幀發出，帶已經按住的秒數（進階用）
signal held(seconds: float)

const _TRIGGER_PRESSED := 0
const _TRIGGER_RELEASED := 1
const _TRIGGER_HELD := 2
# key_source 0～3 的順序跟卡片、能力的 input_type 相同（鍵盤按鍵、滑鼠左鍵、右鍵、中鍵），直接交給 InputRouter.bind_input 的學員版
const _SOURCE_KEY := 0
const _SOURCE_ACTION := 4

# 依 key_source 顯示對應欄位，其他隱藏（選滑鼠按鍵時兩個都隱藏），學員不會被無關的欄位搞混
func _validate_property(property: Dictionary) -> void:
	if property.name == "same_key_as" and key_source != _SOURCE_ACTION:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "key" and key_source != _SOURCE_KEY:
		property.usage = PROPERTY_USAGE_NONE

# 依 key_source 向 InputRouter 註冊三個時機，一律用學員優先權（只聽不搶）；一條訊號都沒連就提醒學員
func _ready() -> void:
	add_to_group("signal_source")
	_warn_if_not_connected.call_deferred()  # 等場景裡其他節點的 _ready() 都跑完，用程式連的線也算進去
	if key_source == _SOURCE_ACTION:
		if not InputRouter.check_action(StringName(same_key_as), "[按鍵觸發器] %s" % name):
			return
		InputRouter.bind_student(self, StringName(same_key_as), InputRouter.PRESSED, _on_pressed)
		InputRouter.bind_student(self, StringName(same_key_as), InputRouter.HELD, _on_held)
		InputRouter.bind_student(self, StringName(same_key_as), InputRouter.RELEASED, _on_released)
	elif key_source != _SOURCE_KEY:
		var button: MouseButton = InputRouter.MOUSE_BUTTONS[key_source - 1]
		InputRouter.bind_student_mouse(self, button, InputRouter.PRESSED, _on_pressed)
		InputRouter.bind_student_mouse(self, button, InputRouter.HELD, _on_held)
		InputRouter.bind_student_mouse(self, button, InputRouter.RELEASED, _on_released)
	else:
		InputRouter.warn_if_dangerous_key(key, "[按鍵觸發器]")
		InputRouter.bind_student_key(self, key, InputRouter.PRESSED, _on_pressed)
		InputRouter.bind_student_key(self, key, InputRouter.HELD, _on_held)
		InputRouter.bind_student_key(self, key, InputRouter.RELEASED, _on_released)

# 按下那一幀：發出 pressed 跟 hold_started，trigger 選按下時也發出 triggered
func _on_pressed() -> void:
	pressed.emit()
	hold_started.emit()
	if trigger == _TRIGGER_PRESSED:
		triggered.emit()

# 按著的每個物理幀：發出 held(秒數)，trigger 選按住時也發出 triggered
func _on_held(seconds: float) -> void:
	held.emit(seconds)
	if trigger == _TRIGGER_HELD:
		triggered.emit()

# 放開那一幀：發出 hold_ended 跟 released(總共按住的秒數)，trigger 選放開時也發出 triggered
func _on_released(seconds: float) -> void:
	hold_ended.emit()
	released.emit(seconds)
	if trigger == _TRIGGER_RELEASED:
		triggered.emit()

# 這個觸發器所有訊號都沒連到任何東西時提醒學員，不然按了沒反應會以為壞掉
func _warn_if_not_connected() -> void:
	for sig in [triggered, pressed, hold_started, hold_ended, released, held]:
		if not (sig as Signal).get_connections().is_empty():
			return
	push_warning("[按鍵觸發器] %s 的 triggered 沒有連到任何東西，按了不會有反應" % name)
	printerr("⚠ [按鍵觸發器] %s 還沒連線：選它 → 右邊「節點」面板 → 雙擊 triggered → 選要控制的零件和函式" % name)
