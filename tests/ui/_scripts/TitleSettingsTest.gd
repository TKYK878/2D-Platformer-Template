extends Node

# 手動驗證用（U244、U245）：標題畫面的「設定」鍵。場景就是 TitleScreenTemplate 本身（範本改了這裡跟著變），
# 底下多掛一個測試節點。開場先自動檢查一輪，再印出手動操作說明。

# 跑自動檢查，再印出手動操作說明
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_checks()
	print("[測試] ── 手動測試 ──")
	print("[測試] ① 標題下面有「開始遊戲」「設定」「離開遊戲」三顆按鈕，選取停在「開始遊戲」")
	print("[測試] ② 按「設定」（滑鼠點，或方向鍵下移過去按 Enter）：半透明底蓋住標題，中間是「設定」頁，選取停在主音量拉桿")
	print("[測試] ③ 方向鍵左右拉主音量、上下換到音效（拉的時候有試聽音效）、音樂、手機按鈕、返回")
	print("[測試] ④ 按「返回」或 Esc：設定頁關掉，選取回到「設定」鍵；在標題按 Esc 不會跳出暫停選單")
	print("[測試] ⑤ 把音樂拉到 0、關掉遊戲再按 F6：再打開設定，音樂還是 0（記在設定檔；測完記得拉回來）")
	print("[測試] ⑥ 編輯器裡：點場景樹上 SettingsPage 旁邊的眼睛，設定頁會蓋在標題上顯示出來；再點一次藏起來（測完不要存檔）")
	print("[測試] （「開始遊戲」在範本裡沒選關卡，按了只會印警告，這裡不用測）")

# 按設定、按 Esc、按返回，檢查設定頁、選取、暫停選單都對
func _run_checks() -> void:
	print("[測試] ── 自動檢查 ──")
	var title := owner as Control
	var page: Control = title.find_child("SettingsPage", true, false)
	var start := title.find_child("Start", true, false) as Button
	var settings := title.find_child("Settings", true, false) as Button
	var back := page.find_child("Back", true, false) as Button
	_check("現在是標題畫面", PauseMenu.is_title_scene())
	_check("一開始設定頁藏著、選取在「開始遊戲」", not page.visible and get_viewport().gui_get_focus_owner() == start)
	_check("「設定」鍵沒有黃色驚嘆號", settings._get_configuration_warnings().is_empty())
	settings.grab_focus()
	settings.pressed.emit()
	await get_tree().process_frame
	var focus := get_viewport().gui_get_focus_owner()
	_check("按「設定」：設定頁打開", page.is_open())
	_check("選取跳到主音量拉桿", focus is HSlider and page.is_ancestor_of(focus))
	_press(KEY_ESCAPE)
	await get_tree().process_frame
	_check("按 Esc：設定頁關掉、選取回到「設定」鍵", not page.visible and get_viewport().gui_get_focus_owner() == settings)
	_check("標題畫面按 Esc 不會跳出暫停選單", not PauseMenu.is_open())
	settings.pressed.emit()
	await get_tree().process_frame
	back.pressed.emit()
	await get_tree().process_frame
	_check("按「返回」：設定頁關掉", not page.visible)

# 模擬按下並放開一個鍵
func _press(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		get_viewport().push_input(event)

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
