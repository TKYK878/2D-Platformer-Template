extends Node2D

# 設定頁（U244）：暫停選單範本直接放進關卡、開「可編輯的子節點」，List 底下加了一顆「設定」鍵（MenuAction 選「打開設定」），
# 暫停選單最上層底下放一個 SettingsPage。另外 List 底下有一顆放錯位置的「返回」鍵（BadBack），按了會印警告。
# 這裡測的是最容易出錯的情況：暫停選單裡的設定頁按 Esc 只關設定頁、不會連選單一起關。標題畫面的設定鍵見 U245（範本按 F6）。

# 跑自動檢查，再印出手動操作說明
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_checks()
	print("[測試] ── 手動測試 ──")
	print("[測試] ① 按 Esc 打開暫停選單 → 按「設定」：設定頁蓋在選單上面，選取停在主音量拉桿（鍵盤左右可以拉）")
	print("[測試] ② 方向鍵上下：主音量、音效、音樂、手機按鈕、返回之間移動，有選到的音效")
	print("[測試] ③ 按「返回」或 Esc：設定頁關掉、回到暫停選單，選取停在「設定」鍵；選單還開著")
	print("[測試] ④ 再打開設定頁、按 Esc 兩次：第一次關設定頁、第二次關選單；再按 Esc 打開選單時設定頁是關的")
	print("[測試] ⑤ 按選單裡的「返回（放錯）」：輸出面板印「『返回』要放在設定頁裡面才有用」；編輯器裡它有黃色驚嘆號")

# 打開選單、打開設定頁、按 Esc、按返回、關選單，檢查設定頁和選取跟著對
func _run_checks() -> void:
	print("[測試] ── 自動檢查 ──")
	var page: Control = find_child("SettingsPage", true, false)
	var open_button := find_child("Settings", true, false) as Button
	var back := page.find_child("Back", true, false) as Button
	var bad_back: Node = find_child("BadBack", true, false)
	_check("一開始設定頁是藏著的", not page.visible)
	PauseMenu.open()
	await get_tree().process_frame
	open_button.grab_focus()
	open_button.pressed.emit()
	await get_tree().process_frame
	var focus := get_viewport().gui_get_focus_owner()
	_check("按「設定」：設定頁打開", page.is_open())
	_check("選取跳到設定頁裡（%s）" % (focus.name if focus else "沒有"), focus != null and page.is_ancestor_of(focus))
	_press_escape()
	await get_tree().process_frame
	_check("按 Esc：設定頁關掉，暫停選單還開著", not page.visible and PauseMenu.is_open())
	_check("選取回到「設定」鍵", get_viewport().gui_get_focus_owner() == open_button)
	open_button.pressed.emit()
	await get_tree().process_frame
	back.pressed.emit()
	await get_tree().process_frame
	_check("按「返回」：設定頁關掉", not page.visible and PauseMenu.is_open())
	open_button.pressed.emit()
	await get_tree().process_frame
	PauseMenu.close()
	await get_tree().process_frame
	_check("設定頁開著時選單被關掉：設定頁也跟著關，下次打開選單不會停在設定頁", not page.visible)
	_check("放錯位置的「返回」有警告", not bad_back._get_configuration_warnings().is_empty())

# 模擬按一下 Esc
func _press_escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		get_viewport().push_input(event)

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
