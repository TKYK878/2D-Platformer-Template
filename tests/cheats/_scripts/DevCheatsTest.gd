extends Node2D

# 手動驗證用（U239）：開發熱鍵 DevCheats。拖進關卡就有，按 ` 打開清單、數字鍵開關。
# 場景裡有兩個房間、一隻敵人、會秒殺的岩漿，可以一個一個試。

@onready var _player: CharacterBody2D = $Player

# 印出操作說明，先自動檢查一輪
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳；按 `（Tab 上面那顆鍵）打開開發熱鍵清單")
	print("[測試] ① 右下角有一行小字「` 開發熱鍵」；按 ` 右上角出現清單（1～9、-、= 各是什麼）")
	print("[測試] ② 清單開著時按 1：清單上「不會死」後面出現「● 開」，踩岩漿沒事；再按 1 關掉")
	print("[測試] ③ 按 2 飛行穿牆、7／8 換房間、4 慢動作、6 鏡頭拉遠……每個都試一下")
	print("[測試] ④ 按 ` 關掉清單：數字鍵不再有作用；右下角小字寫「（N 個開著）」")
	print("[測試] ⑤ 在編輯器的 Game 分頁（遊戲嵌在編輯器裡）也試一次 ` 和數字鍵，確認沒有被編輯器吃掉")
	await get_tree().process_frame
	_press(KEY_1)
	_check("清單關著時按 1：沒有作用", not _player.is_invincible())
	_press(KEY_QUOTELEFT)
	_press(KEY_1)
	_check("按 ` 打開清單再按 1：不會死打開了", _player.is_invincible())
	_press(KEY_1)
	_press(KEY_QUOTELEFT)
	_check("再按 1 關掉、按 ` 收起清單", not _player.is_invincible())

# 模擬按下並放開一個鍵
func _press(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		get_viewport().push_input(event)

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
