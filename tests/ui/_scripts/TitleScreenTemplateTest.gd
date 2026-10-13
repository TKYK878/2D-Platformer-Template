extends Node

# 手動驗證用：標題畫面範本（從 TitleScreenTemplate 再製出來改的，跟學員的做法一樣）。
# 根節點填了 game_name（頭尾有空白）、key_art（地形範本圖），hook 空白（用範本原本的字）；
# 「開始遊戲」選了 W4_SkinBox。W 切換「假裝在網頁版」，看「離開遊戲」會不會藏起來

const _MENU_ACTION := preload("res://ui/_scripts/MenuAction.gd")

# 印出操作說明，等一幀（根節點的 _ready 比這裡晚跑，欄位那時才套上去）再檢查欄位有沒有套上去
func _ready() -> void:
	print("[測試] ① 畫面最上面是「測試遊戲」（頭尾空白去掉了），中間是地形範本圖，下面一行小字是範本原本的「一句話告訴玩家這是什麼遊戲」")
	print("[測試] ② 「開始遊戲」已經選好（鍵盤按 Enter 或空白鍵也可以按）：按下去換到 W4_SkinBox，HUD 從頭算、金幣是 0")
	print("[測試] ③ 在標題畫面按 Esc：不會跳出暫停選單")
	print("[測試] ④ 按 W：切換「假裝在網頁版」，「離開遊戲」按鈕藏起來／出現")
	print("[測試] ⑤ 編輯器裡：選根節點，Inspector 最下面「標題畫面」群組有 game_name、key_art、hook；kind 換成 HUD 時這三格會消失")
	print("[測試] ⑥ 編輯器裡：選 Start，level 是下拉選單，列出 _my/ 和 levels/_starts/ 的關卡（沒有標題、HUD 這些畫面）；清空 level → Start 出現黃色驚嘆號")
	print("[測試] ⑦ 編輯器裡：刪掉 Layout/Top/GameName（測完不要存檔）→ 根節點出現黃色驚嘆號「範本裡的 GameName 被刪掉或改名了」")
	await get_tree().process_frame
	var root := get_parent() as UIRoot
	var name_label := root.find_child("GameName", true, false) as Label
	var hook_label := root.find_child("Hook", true, false) as Label
	print("[測試] 遊戲名稱：「%s」（應該是「測試遊戲」）" % name_label.text)
	print("[測試] 一行小字：「%s」（應該是範本原本的字）" % hook_label.text)
	print("[測試] 現在是不是標題畫面：%s（應該是 true）" % PauseMenu.is_title_scene())

# 除錯按鍵：W 切換假裝在網頁版
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_W:
		_MENU_ACTION.pretend_web = not _MENU_ACTION.pretend_web
		_refresh_buttons(get_parent())
		print("[測試] 假裝在網頁版：%s（「離開遊戲」應該%s）" % [_MENU_ACTION.pretend_web, "藏起來" if _MENU_ACTION.pretend_web else "出現"])

# 讓畫面上的選單按鈕重新決定要不要出現
func _refresh_buttons(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("refresh_menu_action"):
			child.refresh_menu_action()
		_refresh_buttons(child)

# 離開時把「假裝在網頁版」關掉，免得影響換到的關卡
func _exit_tree() -> void:
	_MENU_ACTION.pretend_web = false
