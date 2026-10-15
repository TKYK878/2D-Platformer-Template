extends Node2D

# 手動驗證用（U219）：HUD、暫停選單的 palette 選「跟標題一樣」，用主場景（標題畫面）的配色。
# 測試時不改專案的主場景，改用 UIRoot.title_scene_override 指定要跟哪個標題：1～4 切換

const _TITLES := [
	["res://tests/ui/TitleArtPaletteTest.tscn", "跟主視覺配的標題（藍灰色）"],
	["res://tests/ui/TitleScreenTemplateTest.tscn", "預設配色的標題"],
	["res://tests/ui/TitleFlowLevel.tscn", "不是標題畫面的關卡（要警告、用預設配色）"],
	["", "專案真正的主場景"],
]
const _KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]

# 子節點的 UIRoot 開場前就指定好要跟哪個標題
func _enter_tree() -> void:
	UIRoot.title_scene_override = _TITLES[0][0]

# 印出操作說明和現在的顏色
func _ready() -> void:
	print("[測試] ① 一開始跟的是「跟主視覺配」的標題：右上 HUD 的底框、血條是標題那套藍灰色（不是預設的深色）")
	print("[測試] ② 按 Esc：暫停選單也是同一套顏色")
	print("[測試] ③ 1～4 換要跟的標題：跟主視覺配／預設配色／不是標題的關卡（輸出面板中文警告，變回預設）／專案真正的主場景")
	print("[測試] ④ 編輯器裡：打開 ui/templates/HudTemplate.tscn，palette 下拉最後是「跟標題一樣」、沒有「跟主視覺配」；標題範本相反")
	print("[測試] ⑤ 編輯器裡：HUD 選「跟標題一樣」後，去 _my/ 的標題（主場景）換 palette 存檔，切回 HUD 分頁，一秒內跟著變")
	print("[測試] ⑥ 編輯器裡：主場景不是標題畫面時，HUD 最上層黃色驚嘆號「專案的主場景不是標題畫面」")
	_print_now(0)

# 除錯按鍵：1～4 換要跟的標題
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index := _KEYS.find(event.physical_keycode)
	if index == -1:
		return
	UIRoot.title_scene_override = _TITLES[index][0]
	UIRoot._title_cache_time = -1
	for ui in [$HudTemplate, $PauseMenuTemplate]:
		ui.palette = ui.palette
		var problem: String = ui.title_palette_problem()
		if problem != "":
			push_warning("[%s] %s" % [ui.name, problem])
	_print_now(index)

# 印出現在跟的是哪個標題、HUD 用的亮色和底框顏色
func _print_now(index: int) -> void:
	var hud: UIRoot = $HudTemplate
	print("[測試] 跟：%s → HUD 亮色 #%s、底框 #%s" % [_TITLES[index][1],
		hud.get_palette_color("accent", Color.BLACK).to_html(false), hud.get_palette_color("panel", Color.BLACK).to_html()])

# 離開時恢復成看主場景
func _exit_tree() -> void:
	UIRoot.title_scene_override = ""
