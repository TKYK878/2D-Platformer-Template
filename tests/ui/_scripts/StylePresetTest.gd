extends Node2D

# 手動驗證用：UIRoot 的風格（style）× 配色（palette）。Q／W／E 換風格、1～5 換配色。
# 選單蓋在藍天綠地上，檢查底框、按鈕四種狀態（平常／滑鼠移上去／按下／停用）、條、拉桿在每一種組合都看得清楚

const _STYLE_NAMES := ["像素復古", "乾淨極簡", "可愛圓角"]
const _PALETTE_NAMES := ["預設", "暗色", "亮色", "復古綠", "糖果"]

@onready var _ui: UIRoot = $UIRoot

# 印出操作說明
func _ready() -> void:
	print("[測試] ① Q／W／E：像素復古（方角、切角底框）／乾淨極簡（細外框、留白多）／可愛圓角（圓角、按鈕底邊厚，按下去會變薄、字往下）")
	print("[測試] ② 1～5：預設／暗色／亮色／復古綠／糖果；底框的顏色、按鈕、條、拉桿一起換")
	print("[測試] ③ 每一種組合：滑鼠移到按鈕上會變色、按住會變深、「停用」那顆字變淡；用 Tab 選到按鈕時有外框")
	print("[測試] ④ 「預設」配色＋像素復古＝跟以前一樣；「預設」配色＋其他兩種風格會用中性的灰色")
	print("[測試] ⑤ 編輯器裡選 UIRoot 改 style：編輯畫面上馬上跟著變")
	_print_now()

# 除錯按鍵：Q／W／E 換風格、1～5 換配色
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_Q, KEY_W, KEY_E:
			_ui.style = [KEY_Q, KEY_W, KEY_E].find(event.physical_keycode)
			_print_now()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_ui.palette = event.physical_keycode - KEY_1
			_print_now()

# 印出現在的組合
func _print_now() -> void:
	print("[測試] 風格：%s，配色：%s" % [_STYLE_NAMES[_ui.style], _PALETTE_NAMES[_ui.palette]])
