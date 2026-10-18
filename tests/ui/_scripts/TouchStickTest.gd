extends Node2D

# 手機搖桿（U228）：開場先自動檢查一輪，之後可以用滑鼠拖搖桿手動測。
# 左下是搖桿（一直顯示）；手機按鈕套件開「可編輯的子節點」把 Left、Right 藏起來，只留跳和暫停。

@onready var _stick: Control = $TouchStick
@onready var _kit: Control = $TouchControls

# 跑自動檢查，再印出手動操作說明
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_checks()
	print("[測試] ── 手動測試 ──")
	print("[測試] ① 左下是搖桿（大圓圈＋中間圓鈕），套件的 ◀ ▶ 看不到，右下還有「跳」、右上暫停鈕")
	print("[測試] ② 滑鼠按住圓鈕往右拖一點點：角色慢慢走；拖到底：全速；圓鈕跟著移動、不會跑出圓圈")
	print("[測試] ③ 拖著不放、滑鼠移到圓圈外面：照樣在推；放開：圓鈕回到中間，角色停下")
	print("[測試] ④ 調 dead_zone 拉大：要推比較遠才會動；stick_size、corner、opacity 編輯器裡馬上看到")
	print("[測試] ⑤ 有手機的話：匯出 Web 用手機瀏覽器開，左手推搖桿、右手按跳")

# 假裝手指推搖桿到各種位置，檢查左右的力道、上下、放開
func _run_checks() -> void:
	print("[測試] ── 自動檢查 ──")
	_check("搖桿移進 CanvasLayer（不跟著鏡頭跑）", _stick.get_parent() is CanvasLayer)
	_check("套件的 Left、Right 藏起來了", not _kit.get_node("Left").visible and not _kit.get_node("Right").visible)
	var radius: float = _stick.stick_size / 2.0

	_touch(0, Vector2.ZERO, true)
	await _frames()
	_check("按在正中間：不會走", not Input.is_action_pressed(&"move_left") and not Input.is_action_pressed(&"move_right"))
	_drag(0, Vector2(radius * 0.1, 0))
	await _frames()
	_check("推一成（比 dead_zone 0.2 小）：不會走", not Input.is_action_pressed(&"move_right"))
	_drag(0, Vector2(radius * 0.6, 0))
	await _frames()
	var half := Input.get_action_strength(&"move_right")
	_check("推六成：往右、力道介於中間（%.2f）" % half, half > 0.3 and half < 0.7)
	_drag(0, Vector2(radius * 3.0, 0))
	await _frames()
	_check("推到圓圈外面：照樣在推、力道 1（%.2f）" % Input.get_action_strength(&"move_right"), is_equal_approx(Input.get_action_strength(&"move_right"), 1.0))
	_drag(0, Vector2(-radius, 0))
	await _frames()
	_check("推到左邊：move_left 按著、move_right 放開", Input.is_action_pressed(&"move_left") and not Input.is_action_pressed(&"move_right"))
	_drag(0, Vector2(0, -radius))
	await _frames()
	_check("推到上面：move_up 按著、左右都放開", Input.is_action_pressed(&"move_up") and not Input.is_action_pressed(&"move_left"))
	_drag(0, Vector2(radius * 0.7, radius * 0.3))
	await _frames()
	_check("斜斜往右下但下面推不到一半：只往右，沒按下", Input.is_action_pressed(&"move_right") and not Input.is_action_pressed(&"move_down") and not Input.is_action_pressed(&"move_up"))

	_touch(1, Vector2.ZERO, true, _kit.get_node("Jump"))
	await _frames()
	_check("手指 1 同時按「跳」：jump 按著、搖桿還在推", Input.is_action_pressed(&"jump") and Input.is_action_pressed(&"move_right"))
	_touch(1, Vector2.ZERO, false, _kit.get_node("Jump"))
	_touch(0, Vector2(radius * 0.7, 0), false)
	await _frames()
	_check("放開：四個方向都放開", not (Input.is_action_pressed(&"move_left") or Input.is_action_pressed(&"move_right") or Input.is_action_pressed(&"move_up") or Input.is_action_pressed(&"move_down")))

	Input.action_press(&"move_left")
	_touch(0, Vector2(radius, 0), true)
	_touch(0, Vector2(radius, 0), false)
	await _frames()
	_check("鍵盤按著左時推一下搖桿再放開：鍵盤的左還按著", Input.is_action_pressed(&"move_left"))
	Input.action_release(&"move_left")

	_touch(2, Vector2(radius * 2.0, 0), true)
	await _frames()
	_check("按在圓圈外面：搖桿不理", not Input.is_action_pressed(&"move_right"))
	_touch(2, Vector2(radius * 2.0, 0), false)
	await _frames()

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

# 某個控制項正中間再偏一點，換算成視窗上的位置（畫面有放大時要換算）
func _window_point(target: Control, offset: Vector2) -> Vector2:
	var center := target.get_global_transform_with_canvas().origin + target.size / 2.0
	return get_viewport().get_final_transform() * (center + offset)

# 假裝某根手指在搖桿（或指定的按鈕）正中間偏 offset 的地方按下或放開
func _touch(index: int, offset: Vector2, down: bool, target: Control = null) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = _window_point(target if target != null else _stick, offset)
	event.pressed = down
	Input.parse_input_event(event)

# 假裝某根手指滑到搖桿正中間偏 offset 的地方
func _drag(index: int, offset: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = _window_point(_stick, offset)
	Input.parse_input_event(event)
