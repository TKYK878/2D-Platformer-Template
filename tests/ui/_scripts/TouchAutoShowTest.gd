extends Node2D

# 「摸到螢幕才出現」（U230）：手機按鈕套件和另外拖的「F」都選這個。開場先自動檢查一輪。
# 電腦上沒辦法用手指摸，按 T 假裝手指碰一下畫面正中間。

const _BUTTON_SCENE := preload("res://ui/TouchButton.tscn")

@onready var _kit: Control = $TouchControls
@onready var _attack: Control = $Attack

# 跑自動檢查，再印出手動操作說明
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_checks()
	print("[測試] ── 手動測試 ──")
	print("[測試] ① 現在看不到手機按鈕（最後一步按了鍵盤）")
	print("[測試] ② 按 T（假裝手指碰螢幕）：套件和「F」一起出現")
	print("[測試] ③ 用滑鼠點出現的按鈕（◀ ▶ 跳 F 暫停）：按鈕不會因為送出假按鍵就藏起來")
	print("[測試] ④ 按鍵盤任何鍵（例如方向鍵）：手機按鈕藏起來；再按 T 又出現")
	print("[測試] ⑤ 有手機的話：匯出 Web 用手機瀏覽器開，一開始沒有按鈕，手指一碰就出現")

# 假裝手指、鍵盤、手把輪流用，檢查手機按鈕跟著出現、藏起來
func _run_checks() -> void:
	print("[測試] ── 自動檢查 ──")
	_check("一開始沒碰過螢幕：套件、F 都藏著", not _kit.visible and not _attack.visible)
	_touch_at(0, get_viewport().get_visible_rect().size / 2.0, true)
	_touch_at(0, get_viewport().get_visible_rect().size / 2.0, false)
	await _frames()
	_check("手指碰一下畫面：套件、F 都出現", _kit.visible and _attack.visible)

	_touch_on(1, _attack, true)
	await _frames()
	_check("按「F」（送出假的 F 鍵）：F 鍵按著，按鈕沒有藏起來", Input.is_physical_key_pressed(KEY_F) and _attack.visible)
	_touch_on(1, _attack, false)
	await _frames()
	_check("放開「F」：按鈕還在", _attack.visible and _kit.visible)

	var pause: Control = _kit.get_node("Pause")
	_touch_on(2, pause, true)
	_touch_on(2, pause, false)
	await _frames()
	_check("點暫停鈕（送出假的 Esc）：暫停選單打開、套件還在", PauseMenu.is_open() and _kit.visible)
	_touch_on(2, pause, true)
	_touch_on(2, pause, false)
	await _frames()
	_check("再點一次：暫停選單關掉、套件還在", not PauseMenu.is_open() and _kit.visible)

	var fresh := _BUTTON_SCENE.instantiate()
	fresh.show_on = 2
	add_child(fresh)
	_check("用觸控中新出現的手機按鈕（像換到下一關）：一出現就顯示", fresh.visible)

	_touch_on(3, _kit.get_node("Left"), true)
	await _frames()
	_key(KEY_RIGHT, true)
	await _frames()
	_check("按鍵盤：套件、F 都藏起來", not _kit.visible and not _attack.visible)
	_check("藏起來時按著的 ◀ 自動放開", not Input.is_action_pressed(&"move_left"))
	_check("新出現的那顆也跟著藏起來", not fresh.visible)
	_key(KEY_RIGHT, false)
	_touch_on(3, _kit.get_node("Left"), false)
	fresh.queue_free()

	_touch_at(0, Vector2(240, 135), true)
	_touch_at(0, Vector2(240, 135), false)
	await _frames()
	_check("再碰一下：又出現", _kit.visible)
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	Input.parse_input_event(joy)
	joy = joy.duplicate()
	joy.pressed = false
	Input.parse_input_event(joy)
	await _frames()
	_check("按手把：藏起來", not _kit.visible)

# 按 T：假裝手指碰一下畫面正中間（T 本身是鍵盤，會先藏起來，接著又因為碰螢幕出現）
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		print("[測試] 假裝手指碰螢幕")
		_touch_at(9, get_viewport().get_visible_rect().size / 2.0, true)
		_touch_at(9, get_viewport().get_visible_rect().size / 2.0, false)

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

# 假裝某根手指在畫面上某個點按下或放開（畫面有放大時要換算成視窗上的位置）
func _touch_at(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * at
	event.pressed = down
	Input.parse_input_event(event)

# 假裝某根手指在某顆按鈕正中間按下或放開
func _touch_on(index: int, button: Control, down: bool) -> void:
	_touch_at(index, button.get_global_transform_with_canvas().origin + button.size / 2.0, down)

# 假裝真的鍵盤按下或放開某個鍵
func _key(which: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = which
	event.physical_keycode = which
	event.pressed = down
	Input.parse_input_event(event)
