extends Node2D

# 手動驗證用：UIRoot 的風格（style）× 配色（palette）。Q／W／E／R／T／Y／U 換風格、1～0 換配色（U211 加後四種風格、後五套配色）。
# 選單蓋在藍天綠地上，檢查底框、按鈕四種狀態（平常／滑鼠移上去／按下／停用）、條、拉桿在每一種組合都看得清楚

const _STYLE_NAMES := ["像素復古", "乾淨極簡", "可愛圓角", "木牌", "科幻", "漫畫", "復古遊戲機"]
const _PALETTE_NAMES := ["預設", "暗色", "亮色", "復古綠", "糖果", "海洋", "森林", "夕陽", "黑白", "萬聖節", "自訂"]
const _STYLE_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U]
const _PALETTE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS]

@onready var _ui: UIRoot = $UIRoot

# 印出操作說明
func _ready() -> void:
	print("[測試] ① Q／W／E：像素復古（方角、切角底框）／乾淨極簡（細外框、留白多）／可愛圓角（圓角、按鈕底邊厚，按下去會變薄、字往下）")
	print("[測試] ①b R／T／Y／U：木牌（木紋底框、四角釘子、按鈕圓一點底邊厚）／科幻（切角亮線底框、按鈕左邊一條亮線，滑鼠移上去變亮）／")
	print("[測試] 　漫畫（粗黑框、右下硬陰影，按下去陰影消失、字往右下）／復古遊戲機（雙線底框、按鈕左邊粗線，滑鼠移上去變亮）")
	print("[測試] ② 1～0：預設／暗色／亮色／復古綠／糖果／海洋／森林／夕陽／黑白／萬聖節；底框的顏色、按鈕、條、拉桿一起換")
	print("[測試] ③b 底框最外圈有一圈配色的亮色（accent）外框，圓角、切角跟著形狀走；漫畫風格維持黑框（U212）")
	print("[測試] ②b －（減號）：自訂配色（U213）。編輯器裡選 UIRoot、palette 選「自訂」才出現「自訂配色」4 個取色器，改了畫面馬上變；")
	print("[測試] 　把 text_color 跟 panel_color 選得很像（例如都選深灰）：UIRoot 出現黃色驚嘆號「…太接近，字可能看不清楚」，F6 輸出面板也有中文警告")
	print("[測試] ③ 每一種組合：滑鼠移到按鈕上會變色、按住會變深、「停用」那顆字變淡；用 Tab 選到按鈕時有外框")
	print("[測試] ④ 「預設」配色＋像素復古＝跟以前一樣；「預設」配色＋其他風格會用中性的灰色")
	print("[測試] ⑤ 編輯器裡選 UIRoot 改 style：編輯畫面上馬上跟著變")
	_print_now()

# 除錯按鍵：Q～U 換風格、1～0、－ 換配色
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		_ when _STYLE_KEYS.has(event.physical_keycode):
			_ui.style = _STYLE_KEYS.find(event.physical_keycode)
			_print_now()
		_ when _PALETTE_KEYS.has(event.physical_keycode):
			_ui.palette = _PALETTE_KEYS.find(event.physical_keycode)
			_print_now()

# 印出現在的組合
func _print_now() -> void:
	print("[測試] 風格：%s，配色：%s" % [_STYLE_NAMES[_ui.style], _PALETTE_NAMES[_ui.palette]])
