extends Node2D

# 手機按鈕套件（U227）：開場先自動檢查一輪，之後可以用滑鼠點按鈕手動測。
# TouchControls 選「一直顯示」；另外拖一顆 TouchButton「F」當攻擊鍵；TouchOnlyKit 是同一個套件選「只在觸控裝置」，電腦上應該整組看不到。

@onready var _kit: Control = $TouchControls
@onready var _hidden_kit: Control = $TouchOnlyKit
@onready var _attack: Control = $Attack

# 跑自動檢查，再印出手動操作說明
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_checks()
	print("[測試] ── 手動測試 ──")
	print("[測試] ① 左下 ◀ ▶、右下大一點的「跳」、右上小的暫停鈕，旁邊多一顆「F」；都半透明、不跟著鏡頭跑")
	print("[測試] ② 用滑鼠按住 ◀ ▶ 走、點「跳」跳、點「F」揮擊、點暫停鈕開關暫停選單")
	print("[測試] ③ 選 TouchControls 拉 opacity：四顆一起變透明（F 不變，它不在套件裡）")
	print("[測試] ④ 對 TouchControls 按右鍵 → 勾「可編輯的子節點」，選 Jump 改 button_size、distance_x：只有跳變")
	print("[測試] ⑤ 有手機的話：匯出 Web 用手機瀏覽器開，兩組按鈕疊在一起出現（TouchOnlyKit 在觸控裝置上會顯示）")

# 檢查四顆都擺好、不重疊、在畫面裡，按得到；藏起來的那組按了不會有反應
func _run_checks() -> void:
	print("[測試] ── 自動檢查 ──")
	var buttons: Array = _kit.get_children().filter(func(c): return c is Control)
	_check("套件有四顆按鈕（%d 顆）" % buttons.size(), buttons.size() == 4)
	_check("套件移進 CanvasLayer（不跟著鏡頭跑）", _kit.get_parent() is CanvasLayer)
	var screen := get_viewport().get_visible_rect()
	var inside := true
	var overlap := false
	for i in buttons.size():
		var rect: Rect2 = buttons[i].get_global_rect()
		inside = inside and screen.encloses(rect)
		for j in range(i + 1, buttons.size()):
			overlap = overlap or rect.intersects(buttons[j].get_global_rect())
	_check("四顆都在畫面裡", inside)
	_check("四顆沒有疊在一起", not overlap)
	_check("套件的 opacity 套到每一顆", buttons.all(func(b): return is_equal_approx(b.opacity, _kit.opacity)))
	_check("「只在觸控裝置」的套件在電腦上整組藏起來", not _hidden_kit.visible or DisplayServer.is_touchscreen_available())

	var left: Control = _kit.get_node("Left")
	var hidden_left: Control = _hidden_kit.get_node("Left")
	_touch(0, left, true)
	await _frames()
	_check("按套件的 ◀：move_left 按著", Input.is_action_pressed(&"move_left"))
	_check("藏起來那組的 ◀ 沒有跟著按下", hidden_left.get("_touch") == -1)
	_touch(0, left, false)
	await _frames()
	_check("放開：move_left 放開", not Input.is_action_pressed(&"move_left"))

	_touch(1, _kit.get_node("Jump"), true)
	_touch(2, _attack, true)
	await _frames()
	_check("同時按套件的「跳」和另外拖的「F」：都按著", Input.is_action_pressed(&"jump") and Input.is_physical_key_pressed(KEY_F))
	_touch(1, _kit.get_node("Jump"), false)
	_touch(2, _attack, false)
	await _frames()

	var pause: Control = _kit.get_node("Pause")
	_touch(3, pause, true)
	_touch(3, pause, false)
	await _frames()
	_check("點套件的暫停鈕：暫停選單打開", PauseMenu.is_open())
	_touch(3, pause, true)
	_touch(3, pause, false)
	await _frames()
	_check("再點一次：暫停選單關掉", not PauseMenu.is_open())

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

# 假裝某根手指在某顆按鈕正中間按下或放開（畫面有放大時要換算成視窗上的位置）
func _touch(index: int, button: Control, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * (button.get_global_transform_with_canvas().origin + button.size / 2.0)
	event.pressed = down
	Input.parse_input_event(event)
