extends Node2D

# 手動驗證用：像素專案預設值。像素圖放大 3 倍、像素字 12／24／36 要邊緣銳利不糊，20 是反例（筆畫粗細不一）。
# 開場印出專案設定與字型匯入設定，跟應該的值比對

const _FONT_PATH := "res://art/fonts/Cubic_11.woff2"

# 印出操作說明與目前的設定值
func _ready() -> void:
	print("[測試] ① 右上的圖塊放大 3 倍、右下原尺寸：每一格像素邊緣都是銳利的方塊，沒有模糊、沒有半透明的邊")
	print("[測試] ② 左邊的字：12、24、36 每一筆都是銳利的方塊、粗細一致；最下面 20 那行筆畫粗細不一（反例，所以字級要用 12 的倍數）")
	print("[測試] ③ 拉大視窗：畫面只會整數倍放大，放不下整數倍時四周補黑邊")
	print("[測試] ④ 編輯器裡選 UIRoot，font_size 是下拉（原本大小 12／2 倍 24／3 倍 36／4 倍 48），不是拉桿")
	for line in check_settings():
		print("[測試] %s" % line)

# 檢查專案設定與字型匯入設定，回傳每一項的結果（開頭 ✓ 或 ✗）；煙霧測試也用這個
static func check_settings() -> PackedStringArray:
	var lines := PackedStringArray()
	_check(lines, "貼圖過濾 Nearest", ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)
	_check(lines, "視窗整數縮放", ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer")
	_check(lines, "預設字型不抗鋸齒", ProjectSettings.get_setting("gui/theme/default_font_antialiasing"), 0)
	_check(lines, "預設字型不用 hinting", ProjectSettings.get_setting("gui/theme/default_font_hinting"), 0)
	_check(lines, "預設字型不用次像素定位", ProjectSettings.get_setting("gui/theme/default_font_subpixel_positioning"), 0)
	var font := load(_FONT_PATH) as FontFile
	if font == null:
		lines.append("✗ 讀不到 %s" % _FONT_PATH)
		return lines
	_check(lines, "像素字不抗鋸齒", font.antialiasing, TextServer.FONT_ANTIALIASING_NONE)
	_check(lines, "像素字不用 hinting", font.hinting, TextServer.HINTING_NONE)
	_check(lines, "像素字不用次像素定位", font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED)
	return lines

# 比對一項設定，加一行結果
static func _check(lines: PackedStringArray, label: String, actual: Variant, expected: Variant) -> void:
	var ok: bool = actual == expected
	lines.append("%s %s：%s（應該是 %s）" % ["✓" if ok else "✗", label, str(actual), str(expected)])
