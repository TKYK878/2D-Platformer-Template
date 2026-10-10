extends Node2D

# 手動驗證用：HudNumber 數字零件與 HudText。不需要角色，用按鍵改數值。
# C 金幣 +1、X 金幣 -1、H 血量 -1、J 血量 +1、D 假裝死一次

# 印出操作說明
func _ready() -> void:
	print("[測試] ① 編輯器裡：每個 HudNumber 用假資料顯示（12、12/20、1:05）；Typo（kind 打成「金弊」）有黃色驚嘆號「…是不是想打『金幣』？」，")
	print("[測試] 　　UIRoot 上也有同一則（寫成「Typo：…」）——HUD 做成場景放進關卡時看不到裡面的零件，錯誤會掛在 UIRoot 這一層")
	print("[測試] ② 把 Coin 的 kind 清空：Coin 自己出現黃色驚嘆號「kind 是空白的」")
	print("[測試] ③ F6：Coins：0（名字用 ValueSettings 的 display_name）、血量：3/3、遊玩時間 0:00 每秒跳、死亡次數只有數字 0")
	print("[測試] 　　Typo 顯示「金弊：?」、NoStamina 顯示「體力：?」，輸出面板各有一則中文警告（金弊有「是不是想打『金幣』」）")
	print("[測試] ④ C／X：金幣 +1／-1，閃白／閃紅；H／J：血量 -1／+1，扣血時閃紅並左右抖；D：死亡次數 +1（沒勾閃，不會閃）")
	print("[測試] （左上角原本的預設 HUD 也會顯示，U173 才會讓位）")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_C:
			Stats.add("金幣", 1)
		KEY_X:
			Stats.add("金幣", -1)
		KEY_H:
			Stats.add(Stats.HEALTH_KIND, -1)
		KEY_J:
			Stats.add(Stats.HEALTH_KIND, 1)
		KEY_D:
			Events.player_died.emit()
