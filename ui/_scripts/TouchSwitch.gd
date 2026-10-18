@tool
extends HBoxContainer

# 手機按鈕開關：拖進選單（標題畫面、暫停選單）就能用，玩家自己決定手機按鈕要「自動／顯示／隱藏」，不用連任何線。
# 選的結果存進設定檔（跟音量同一份），換關、下次開遊戲還是一樣；關卡裡所有手機按鈕、套件、搖桿都會跟著變。
# 想用自己做的按鈕、勾選框：style 選「不顯示（只當接口）」，再把它們的訊號連到這裡的
# set_on／set_off（勾選框的 toggled）或 show_controls／hide_controls／auto_controls／toggle_controls（按鈕的 pressed）。

## 長什麼樣子：勾選框（顯示／隱藏）、下拉選單（自動／顯示／隱藏），或不顯示（只給自己的按鈕、勾選框連訊號用）
@export_enum("勾選框", "下拉選單", "不顯示（只當接口）") var style: int = 0:
	set(value):
		style = value
		_build()

const STYLE_CHECK := 0
const STYLE_LIST := 1
const _TEXT := "手機按鈕"
const _MODE_NAMES := ["自動", "顯示", "隱藏"]

var _check: CheckButton = null
var _list: OptionButton = null
var _label: Label = null
var _syncing: bool = false

# 照 style 建勾選框或下拉選單；遊戲中讀回玩家上次的選擇，暫停中也要按得到
func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_build()
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	TouchSettings.changed.connect(_sync)

# 勾選框的 toggled 連過來：勾著就顯示手機按鈕、取消勾就隱藏
func set_on(on: bool, ..._args: Array) -> void:
	TouchSettings.set_mode(TouchSettings.MODE_SHOW if on else TouchSettings.MODE_HIDE)

# 跟 set_on 相反：勾選框的字寫「隱藏手機按鈕」時連這個，勾著就隱藏、取消勾就顯示
func set_off(off: bool, ..._args: Array) -> void:
	set_on(not off)

# 按鈕的 pressed 連過來：手機按鈕一直顯示
func show_controls(..._args: Array) -> void:
	TouchSettings.set_mode(TouchSettings.MODE_SHOW)

# 按鈕的 pressed 連過來：手機按鈕一直隱藏
func hide_controls(..._args: Array) -> void:
	TouchSettings.set_mode(TouchSettings.MODE_HIDE)

# 按鈕的 pressed 連過來：回到自動（照各零件的 show_on 決定）
func auto_controls(..._args: Array) -> void:
	TouchSettings.set_mode(TouchSettings.MODE_AUTO)

# 按鈕的 pressed 連過來：現在看得到就改成隱藏，看不到就改成顯示
func toggle_controls(..._args: Array) -> void:
	set_on(not _is_shown())

# 手機按鈕現在算不算「顯示中」：選了顯示，或選自動而這台是觸控裝置、玩家正在用觸控
func _is_shown() -> bool:
	if TouchSettings.mode != TouchSettings.MODE_AUTO:
		return TouchSettings.mode == TouchSettings.MODE_SHOW
	return TouchSettings.touch_used or DisplayServer.is_touchscreen_available()

# 拿掉舊的，照 style 重建勾選框或下拉選單（不存進場景）
func _build() -> void:
	if not is_inside_tree():
		return
	for old in [_check, _list, _label]:
		if old != null:
			old.queue_free()
	_check = null
	_list = null
	_label = null
	if style == STYLE_CHECK:
		_check = CheckButton.new()
		_check.text = _TEXT
		add_child(_check)
		_check.toggled.connect(_on_check_toggled)
	elif style == STYLE_LIST:
		_label = Label.new()
		_label.text = _TEXT
		_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_list = OptionButton.new()
		for mode_name in _MODE_NAMES:
			_list.add_item(mode_name)
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_label)
		add_child(_list)
		_list.item_selected.connect(_on_list_selected)
	_sync()

# 讓勾選框、下拉選單顯示玩家現在的選擇（編輯器裡顯示預設值）
func _sync() -> void:
	_syncing = true
	if _check != null:
		_check.button_pressed = false if Engine.is_editor_hint() else _is_shown()
	if _list != null:
		_list.selected = TouchSettings.MODE_AUTO if Engine.is_editor_hint() else TouchSettings.mode
	_syncing = false

# 玩家點勾選框
func _on_check_toggled(on: bool) -> void:
	if not _syncing and not Engine.is_editor_hint():
		set_on(on)

# 玩家在下拉選單選了一項
func _on_list_selected(index: int) -> void:
	if not _syncing and not Engine.is_editor_hint():
		TouchSettings.set_mode(index)
