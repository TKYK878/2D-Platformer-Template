extends Node2D

# 手動驗證用：背景零件 SkinBackground。兩個 Room 並排，背景鋪滿兩間房（藍色格子圖重複鋪滿），
# 場景樹裡背景放在最下面（最後畫），還是在所有東西後面。

const _SKIN_BACKGROUND := preload("res://skins/SkinBackground.tscn")
const _TEXTURES := [preload("res://tests/skins/_art/PixelFrog/Background/Blue.png"), preload("res://tests/skins/_art/PixelFrog/Background/Pink.png")]
const _FILL_NAMES := ["只放一張", "重複鋪滿", "拉伸蓋滿"]

@onready var _background: Node2D = $SkinBackground

# 印出操作說明
func _ready() -> void:
	print("[測試] ① 開場：藍色格子鋪滿畫面，角色、地板在背景前面（背景在場景樹最下面也一樣）")
	print("[測試] ② 往右走到 Room2：背景接得起來、沒有空白的地方")
	print("[測試] ③ 1／2／3：只放一張（在左上角附近一小張）／重複鋪滿／拉伸蓋滿（一張拉大蓋住兩間房，格子變大變糊是正常的）")
	print("[測試] ④ P：開關遠景；開著時走到 Room2，背景只動一半；Q／E 調遠近（越小越遠），兩間房都不會露出空白")
	print("[測試] ⑤ T：換圖（藍／粉紅）；W：在 Player 底下放一個背景 → 輸出面板印中文警告「背景放在 Player 底下…」")
	print("[測試] ⑥ 編輯器裡：清空 texture → 黃色驚嘆號；拖第二個 SkinBackground 進來 → 第二個黃色驚嘆號（會蓋住第一個）；")
	print("[測試] 　 把 Room2 的 width_in_tiles 拉大，半秒內背景跟著變大；depth 只有勾 parallax 才看得到")
	_print_now()

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1, KEY_2, KEY_3:
			_background.fill_style = event.physical_keycode - KEY_1
		KEY_P:
			_background.parallax = not _background.parallax
		KEY_Q:
			_background.depth = maxf(snappedf(_background.depth - 0.1, 0.1), 0.1)
		KEY_E:
			_background.depth = minf(snappedf(_background.depth + 0.1, 0.1), 0.9)
		KEY_T:
			_background.texture = _TEXTURES[1] if _background.texture == _TEXTURES[0] else _TEXTURES[0]
		KEY_W:
			$Player.add_child(_SKIN_BACKGROUND.instantiate())
			return
		_:
			return
	_print_now()

# 印出現在的設定
func _print_now() -> void:
	var text := "[測試] %s" % _FILL_NAMES[_background.fill_style]
	if _background.parallax:
		text += "，遠景 depth %.1f" % _background.depth
	print(text)
