extends Node2D

# 手動驗證用：過關畫面接上學員自己的場景（UISettings 的 clear_screen_scene 接 MyClearScreenExample：
# 復古綠配色、綠色「破關啦！」、只放了用了幾秒和製作者的話（沒放死了幾次）、提示「R：再挑戰一次」）。
# 預設範本的樣子用 tests/blocks/ClearScreenTest.tscn 驗證（跟改版前一樣）。
# T：切換 ClearScreen 的 show_time；M：清空／放回 ClearScreen 的 message

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] ① 碰尖刺死一兩次，走到右邊終點：遊戲暫停，出現綠色的「破關啦！」畫面（不是預設的金色「過關！」），")
	print("[測試] 　　有「用了 x.x 秒」、「感謝遊玩！」、「R：再挑戰一次」，沒有「死了幾次」（這個畫面沒放）")
	print("[測試] ② 按 R：畫面消失、玩家回到起點；再過關一次，秒數從 0 算")
	print("[測試] ③ 過關前按 T 關掉 show_time、按 M 清空 message：再過關時秒數和「感謝遊玩！」都不見了")
	print("[測試] ④ 打開 tests/blocks/ClearScreenTest.tscn 按 F6：預設過關畫面長得跟以前一樣")
	print("[測試] ⑤ 編輯器：這個場景的 ClearScreen 先刪掉（不要存檔）：UISettings 出現黃色驚嘆號「關卡裡沒有 ClearScreen…」")
	print("[測試] ⑥ 編輯器：開 ui/templates/ClearScreenTemplate.tscn，選 Time 把 stat 換成「死了幾次」：字馬上變成「死了 2 次」（改回來別存檔）")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_T:
		$ClearScreen.show_time = not $ClearScreen.show_time
		print("[測試] show_time = %s" % $ClearScreen.show_time)
	elif event.physical_keycode == KEY_M:
		$ClearScreen.message = "" if $ClearScreen.message != "" else "感謝遊玩！"
		print("[測試] message = 「%s」" % $ClearScreen.message)
