extends Node2D

# 手機按鈕（U226）：開場先自動假裝手指按一輪、印出檢查結果，之後可以用滑鼠點按鈕手動測。
# 左下 ◀ ▶、右下「跳」「F」（F 是近戰的攻擊鍵）、右上暫停；左上的 ▲ 選「只在觸控裝置」，電腦上應該看不到。

@onready var _left: Control = $Left
@onready var _right: Control = $Right
@onready var _jump: Control = $Jump
@onready var _attack: Control = $Attack
@onready var _pause: Control = $Pause
@onready var _touch_only: Control = $TouchOnly

# 跑自動檢查，再印出手動操作說明
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_checks()
	print("[測試] ── 手動測試 ──")
	print("[測試] ① 左下 ◀ ▶、右下「跳」「F」、右上暫停鈕，半透明、不跟著鏡頭跑；左上看不到 ▲（只在觸控裝置顯示）")
	print("[測試] ② 用滑鼠按住 ◀：角色往左走，按鈕變亮；放開就停")
	print("[測試] ③ 按住 ◀ 不放滑到 ▶：換成往右走")
	print("[測試] ④ 點「跳」會跳、按久跳比較高；點「F」角色揮擊")
	print("[測試] ⑤ 點右上暫停鈕：出現暫停選單；再點一次：關掉")
	print("[測試] ⑥ 選一顆按鈕改 corner、distance_x／distance_y、button_size、opacity，編輯器裡馬上看到；press 選「鍵盤按鍵」才出現 key")
	print("[測試] ⑦ 有手機的話：匯出 Web 用手機瀏覽器開，左上 ▲ 會出現，兩根手指可以一邊走一邊跳")

# 假裝手指按下、滑動、放開，檢查鍵有沒有跟著按住、放開
func _run_checks() -> void:
	print("[測試] ── 自動檢查 ──")
	_check("左上 ▲（只在觸控裝置）在沒有觸控螢幕的電腦上藏起來", not _touch_only.visible or DisplayServer.is_touchscreen_available())
	_check("按鈕移進 CanvasLayer（不跟著鏡頭跑）", _left.get_parent() is CanvasLayer)

	_touch(0, _left, true)
	await _frames()
	_check("手指 0 按 ◀：move_left 按著", Input.is_action_pressed(&"move_left"))
	_touch(1, _jump, true)
	await _frames()
	_check("手指 1 同時按「跳」：jump 按著、move_left 還按著", Input.is_action_pressed(&"jump") and Input.is_action_pressed(&"move_left"))
	_drag(0, _right)
	await _frames()
	_check("手指 0 滑到 ▶：move_left 放開、move_right 按著", not Input.is_action_pressed(&"move_left") and Input.is_action_pressed(&"move_right"))
	_touch(0, _right, false)
	_touch(1, _jump, false)
	await _frames()
	_check("兩根手指都放開：都放開了", not Input.is_action_pressed(&"move_right") and not Input.is_action_pressed(&"jump"))

	_touch(2, _attack, true)
	await _frames()
	_check("按「F」：F 鍵按著", Input.is_physical_key_pressed(KEY_F))
	_touch(2, _attack, false)
	await _frames()
	_check("放開「F」：F 鍵放開", not Input.is_physical_key_pressed(KEY_F))

	_mouse(_left, true, InputEvent.DEVICE_ID_EMULATION)
	await _frames()
	_check("觸控模擬出來的滑鼠點擊不會重複算一次", not Input.is_action_pressed(&"move_left"))
	_mouse(_left, false, InputEvent.DEVICE_ID_EMULATION)
	_mouse(_left, true, 0)
	await _frames()
	_check("真的滑鼠點 ◀：move_left 按著", Input.is_action_pressed(&"move_left"))
	_mouse(_left, false, 0)
	await _frames()
	_check("滑鼠放開：move_left 放開", not Input.is_action_pressed(&"move_left"))

	_touch(3, _pause, true)
	_touch(3, _pause, false)
	await _frames()
	_check("點暫停鈕：暫停選單打開", PauseMenu.is_open())
	_touch(3, _pause, true)
	_touch(3, _pause, false)
	await _frames()
	_check("暫停中再點一次：暫停選單關掉", not PauseMenu.is_open())

# 印出一條檢查結果
func _check(label: String, ok: bool) -> void:
	if ok:
		print("[測試] ✓ %s" % label)
	else:
		printerr("[測試] ✗ %s" % label)

# 等幾幀讓輸入事件處理完
func _frames() -> void:
	for i in 3:
		await get_tree().process_frame

# 按鈕正中間在視窗上的位置（畫面有放大時要換算）
func _window_point(button: Control) -> Vector2:
	var center := button.get_global_transform_with_canvas().origin + button.size / 2.0
	return get_viewport().get_final_transform() * center

# 假裝某根手指在某顆按鈕上按下或放開
func _touch(index: int, button: Control, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = _window_point(button)
	event.pressed = down
	Input.parse_input_event(event)

# 假裝某根手指滑到某顆按鈕上
func _drag(index: int, button: Control) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = _window_point(button)
	Input.parse_input_event(event)

# 假裝滑鼠左鍵在某顆按鈕上按下或放開（device 是觸控模擬的就應該被忽略）
func _mouse(button: Control, down: bool, device: int) -> void:
	var event := InputEventMouseButton.new()
	event.device = device
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = _window_point(button)
	event.global_position = event.position
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)
