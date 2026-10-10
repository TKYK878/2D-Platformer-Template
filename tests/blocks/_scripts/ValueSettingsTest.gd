extends Node

# 手動驗證用：ValueSettings 場景設定節點覆蓋血量初始值／上限、display_name 改顯示名稱、show_in_hud 關閉某個種類，
# 以及 kind 打成「生命」這類血量別名時的警告

func _ready() -> void:
	print("[測試] 場景裡放了三個 ValueSettings：血量（初始 5、上限 5、display_name 是 HP）、金幣（show_in_hud 關閉）、")
	print("[測試] 　　kind 故意打成「生命」的一筆：場景樹上 ValueSettings_打錯 有黃色驚嘆號，輸出面板有「這會變成一個新的數值，不是血量」的警告")
	print("[測試] 血量目前值：%d（應該是 5）" % Stats.get_value(Stats.HEALTH_KIND))
	print("[測試] 血量上限：%d（應該是 5，不是預設的 3）" % Stats.get_max_value(Stats.HEALTH_KIND))
	await get_tree().create_timer(1.0).timeout
	print("[測試] 血量扣 1，畫面應該出現血條，前面的名字是「HP」不是「血量」，滿條對應上限 5")
	Stats.add(Stats.HEALTH_KIND, -1)
	await get_tree().create_timer(1.5).timeout
	print("[測試] 金幣加 10，數值應該正確增加，但畫面左上角不會出現金幣那一列（show_in_hud 關閉）")
	Stats.add("金幣", 10)
	print("[測試] 金幣目前值：%d（應該是 10，只是不顯示在 HUD）" % Stats.get_value("金幣"))
