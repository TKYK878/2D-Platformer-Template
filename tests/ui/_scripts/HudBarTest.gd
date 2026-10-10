extends Node2D

# 手動驗證用：HudBar 條零件。不需要角色，用按鍵改數值。
# H 血量 -1、J 血量 +1、C 金幣 +1、X 金幣 -1、1～5 換配色

const _PALETTE_NAMES := ["預設", "暗色", "亮色", "復古綠", "糖果"]

var _ui: UIRoot = null

# 印出操作說明
func _ready() -> void:
	_ui = $UIRoot
	print("[測試] ① 編輯器裡：每條都是半滿的假資料；「放圖片」那條用的是圖片（深紅底、紅色填滿）；NoStamina 沒有黃色驚嘆號（內建來源要到執行時才知道有沒有卡）")
	print("[測試] ② F6：血量 5/5 全滿（三條同步）、金幣全滿（不限上限時用目前的值當滿格）、體力那條是空的、中間一個「?」，輸出面板有中文警告")
	print("[測試] ③ H／J：血量 -1／+1，四條血量一起變；「預設」那條扣血時閃紅並左右抖；右到左那條從右邊填、下到上那條從下面填")
	print("[測試] ④ C／X：金幣 +1／-1（不限上限：只要比之前的最大值大就一直是滿的，變少才看得出來）")
	print("[測試] ⑤ 1～5 換配色：沒放圖的條跟著換顏色，放圖片的那條不變")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_H:
			Stats.add(Stats.HEALTH_KIND, -1)
		KEY_J:
			Stats.add(Stats.HEALTH_KIND, 1)
		KEY_C:
			Stats.add("金幣", 1)
		KEY_X:
			Stats.add("金幣", -1)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_ui.palette = event.physical_keycode - KEY_1
			print("[測試] 配色：%s" % _PALETTE_NAMES[_ui.palette])
