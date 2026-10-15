extends Node

# 手動驗證用（U218）：標題畫面 palette 選「跟主視覺配」，從主視覺的圖自動配顏色。
# 1～5 換主視覺（範本的佔位圖、背景、主角、終點旗子、全白的圖）、T 換深淺（自動／深底／淺底）、C 換主色（最多／第二多／第三多）

const _ARTS := [
	"res://ui/templates/_art/KeyArtPlaceholder.png",
	"res://levels/_starts/_W4SkinBox/art/PixelFrog/background.png",
	"res://levels/_starts/_W4SkinBox/art/Ansimuz/player_idle.png",
	"res://levels/_starts/_W4SkinBox/art/goal.png",
	"res://art/white_block.png",
]
const _ART_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
const _TONE_NAMES := ["自動", "深底", "淺底"]
const _PICK_NAMES := ["最多的顏色", "第二多的顏色", "第三多的顏色"]
# 字跟底框亮度至少差這麼多才算看得清楚
const _MIN_CONTRAST := 0.5

# 印出操作說明，先把每張圖 × 每種深淺都檢查一次字看不看得清楚
func _ready() -> void:
	print("[測試] ① 一開始主視覺是 Pixel Frog 的背景：底框、按鈕、亮色（按鈕被選到的外框）都帶藍綠色，字看得清楚")
	print("[測試] ② 1～5 換主視覺：範本佔位圖／背景／主角／終點旗子／全白的圖；顏色跟著圖變，字永遠看得清楚")
	print("[測試] ③ T 換深淺：自動（看圖亮暗）／深底（淺色字）／淺底（深色字）；C 換主色：按鈕和亮色換成圖裡第二、第三多的顏色")
	print("[測試] ④ 編輯器裡：選根節點，palette 選「跟主視覺配」才出現「跟主視覺配」群組（tone、main_color）；把 key_art 換成別的圖，畫面馬上變")
	print("[測試] ⑤ 編輯器裡：palette 改選「自訂」→ 4 個取色器帶著剛剛自動配的顏色（不是原本的紫色），從這裡微調")
	print("[測試] ⑥ 編輯器裡：清空 key_art、再把範本 KeyArt 的 Texture 也清空 → 根節點黃色驚嘆號「找不到主視覺的圖」，畫面變回預設配色")
	print("[測試] ⑦ 編輯器裡：打開 ui/templates/HudTemplate.tscn，palette 下拉沒有「跟主視覺配」（只有標題畫面有）")
	await get_tree().process_frame
	_check_all()
	_print_now()

# 每張圖 × 每種深淺 × 每個主色都算一次，字跟底框太接近就報錯
func _check_all() -> void:
	var root := get_parent() as UIRoot
	var original: Texture2D = root.key_art
	var bad := 0
	for path in _ARTS:
		root.key_art = load(path)
		for tone in 3:
			root.tone = tone
			for pick in 3:
				root.main_color = pick
				if root.art_problem() != "":
					print("[測試] ✗ %s 讀不到顏色：%s" % [path.get_file(), root.art_problem()])
					bad += 1
					continue
				var c: PackedColorArray = root.art_colors
				if absf(c[0].get_luminance() - c[1].get_luminance()) < _MIN_CONTRAST:
					print("[測試] ✗ %s %s %s：字跟底框太接近" % [path.get_file(), _TONE_NAMES[tone], _PICK_NAMES[pick]])
					bad += 1
	root.key_art = original
	root.tone = 0
	root.main_color = 0
	print("[測試] 自動檢查 %d 種組合：%s" % [_ARTS.size() * 9, "全部字都看得清楚 ✓" if bad == 0 else "%d 種有問題 ✗" % bad])

# 除錯按鍵：1～5 換主視覺、T 換深淺、C 換主色
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var root := get_parent() as UIRoot
	if _ART_KEYS.has(event.physical_keycode):
		root.key_art = load(_ARTS[_ART_KEYS.find(event.physical_keycode)])
	elif event.physical_keycode == KEY_T:
		root.tone = (root.tone + 1) % 3
	elif event.physical_keycode == KEY_C:
		root.main_color = (root.main_color + 1) % 3
	else:
		return
	_print_now()

# 印出現在的主視覺、深淺、主色和配出來的 4 個顏色
func _print_now() -> void:
	var root := get_parent() as UIRoot
	var c: PackedColorArray = root.art_colors
	if c.size() < 4:
		print("[測試] 沒有配出顏色：%s" % root.art_problem())
		return
	print("[測試] %s／%s／%s → 字 #%s、底框 #%s、按鈕 #%s、亮色 #%s" % [root.key_art.resource_path.get_file(),
		_TONE_NAMES[root.tone], _PICK_NAMES[root.main_color], c[0].to_html(false), c[1].to_html(false), c[2].to_html(false), c[3].to_html(false)])
