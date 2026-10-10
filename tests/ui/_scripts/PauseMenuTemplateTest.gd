extends Node2D

# 手動驗證用：暫停選單接上學員自己的場景（UISettings 的 pause_menu_scene 接 MyPauseMenuExample：
# 糖果配色、標題「休息一下～」、只有主音量和音樂兩條拉桿、按鈕橫排「繼續玩」「從頭來」、沒有離開遊戲）。
# 預設範本的樣子用 tests/systems/PauseMenuTest.tscn 驗證（跟改版前一樣）。
# D：刪掉 RespawnHandler（看「從頭來」會不會藏起來）

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] ① 按 Esc 或 P：遊戲停住，出現粉紅色的「休息一下～」選單（不是預設的灰色暫停選單），拉桿右邊有百分比")
	print("[測試] ② 拉「主音量」：跳躍聲跟著變；數字跟著變。關掉遊戲再開，位置跟上次一樣（跟預設暫停選單同一份存檔）")
	print("[測試] ③ 打開時「繼續玩」已經被選到（有外框），左右鍵換按鈕、Enter 按下；「從頭來」玩家回到起點")
	print("[測試] ④ 按 D 刪掉 RespawnHandler 再打開：沒有「從頭來」按鈕，輸出面板印「沒有 RespawnHandler」提醒")
	print("[測試] ⑤ 打開 tests/systems/PauseMenuTest.tscn 按 F6：預設暫停選單長得跟以前一樣（標題、三條拉桿、三顆按鈕、提示）")
	print("[測試] ⑥ 在 ui/templates/PauseMenuTemplate.tscn 選 Restart，把 action 下拉換成「離開遊戲」：按鈕上的字自動變成「離開遊戲」（改回來別存檔）")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_D:
		var handler := get_node_or_null("RespawnHandler")
		if handler != null:
			handler.queue_free()
			print("[測試] 已刪掉 RespawnHandler")
