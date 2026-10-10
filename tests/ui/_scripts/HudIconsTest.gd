extends Node2D

# 手動驗證用：HudIcons 圖示排零件。不需要角色，用按鍵改數值。
# H 血量 -1、J 血量 +1、K 鑰匙 +1、L 鑰匙 -1、D 假裝死一次、1～5 換配色

const _PALETTE_NAMES := ["預設", "暗色", "亮色", "復古綠", "糖果"]

var _ui: UIRoot = null

# 印出操作說明
func _ready() -> void:
	_ui = $UIRoot
	print("[測試] ① 編輯器裡：每排都是 3 滿 2 空的假資料；場景樹上看不到一顆一顆的圖示（不會存進場景檔）")
	print("[測試] ② F6：血量兩排都是 5 個滿的；鑰匙 2 個（沒有上限，不畫空的）；死亡次數 0 個；體力只有一個「?」，輸出面板有中文警告")
	print("[測試] ③ H／J：血量 -1／+1，滿的變空的（小方塊那排扣血時閃紅並左右抖；用圖那排滿的是白色方塊、空的是暗色小方塊）")
	print("[測試] ④ K／L：鑰匙 +1／-1；D：死亡次數 +1，最多畫到 5 個就不再變多")
	print("[測試] ⑤ 1～5 換配色：小方塊跟著換顏色；把 Icons1 的 show_empty 取消勾選，空的就不畫")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_H:
			Stats.add(Stats.HEALTH_KIND, -1)
		KEY_J:
			Stats.add(Stats.HEALTH_KIND, 1)
		KEY_K:
			Stats.add("鑰匙", 1)
		KEY_L:
			Stats.add("鑰匙", -1)
		KEY_D:
			Events.player_died.emit()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_ui.palette = event.physical_keycode - KEY_1
			print("[測試] 配色：%s" % _PALETTE_NAMES[_ui.palette])
