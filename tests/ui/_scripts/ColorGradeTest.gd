extends Node2D

# 手動驗證用：統一色調 ColorGrade。整個遊戲畫面染色，左上角 HUD、暫停選單不受影響。
# 1～4 換色調、Q／E 強度減／加、G 開關、D 多放一個（應該出現中文警告）

const _COLOR_GRADE := preload("res://skins/ColorGrade.tscn")
const _NAMES := ["暖", "冷", "復古", "夜晚"]

@onready var _grade: CanvasModulate = $ColorGrade

# 印出操作說明
func _ready() -> void:
	print("[測試] ① 地板、角色、金幣、尖刺、終點都蒙上一層暖色；左上角 HUD、按 Esc 的暫停選單顏色不變")
	print("[測試] ② 1～4：暖／冷／復古／夜晚；Q／E：強度 -0.1／+0.1（0 是原本的顏色）；G：關掉／打開")
	print("[測試] ③ D：再放一個 ColorGrade → 輸出面板出現「有不只一個 ColorGrade」的中文警告，遊戲照常")
	print("[測試] ④ 編輯器裡：拖第二個 ColorGrade 進來 → 兩個都出現黃色驚嘆號；改 tone、strength 編輯畫面馬上變")
	Stats.add("金幣", 3)

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_grade.tone = event.physical_keycode - KEY_1
		KEY_Q:
			_grade.strength = maxf(_grade.strength - 0.1, 0.0)
		KEY_E:
			_grade.strength = minf(_grade.strength + 0.1, 1.0)
		KEY_G:
			_grade.visible = not _grade.visible
		KEY_D:
			add_child(_COLOR_GRADE.instantiate())
			return
		_:
			return
	print("[測試] 色調：%s，強度 %.1f，%s" % [_NAMES[_grade.tone], _grade.strength, "開著" if _grade.visible else "關掉"])
