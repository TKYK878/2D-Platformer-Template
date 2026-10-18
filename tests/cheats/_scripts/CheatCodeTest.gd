extends Node2D

# 手動驗證用（U235）：作弊的按鍵指令。場景裡有三個 Cheat：
# Cheat_Konami（code 故意清空，用預設指令 wwssadad＝上上下下左右左右，開飛行＋無敵）、
# Cheat_Number（指令 1234，開不會死）、Cheat_Typo（指令打成全形加中文「ＪＪ跳ｋｋ」，開場會印警告、當成 jjkk）。

@onready var _player: CharacterBody2D = $Player
@onready var _konami: Node = $Cheat_Konami
@onready var _typo: Node = $Cheat_Typo

# 印出操作說明，先自動檢查一輪
func _ready() -> void:
	for cheat in [_konami, $Cheat_Number, _typo]:
		cheat.code_entered.connect(func(): print("[測試] %s 發出 code_entered" % cheat.name))
	_auto_check()
	print("[測試] 方向鍵移動、空白跳、H 受傷")
	print("[測試] ① 開場輸出面板有兩個警告：Cheat_Konami 的 code 空白（用預設指令）、Cheat_Typo 有按不出來的字（當成 jjkk）；編輯器裡兩個都有黃色驚嘆號")
	print("[測試] ② 依序按 W W S S A D A D：印出「輸入了指令」，畫面上方出現「作弊中：無敵、飛行」，可以飛；再按一次就關掉")
	print("[測試] ③ 按 W W S S 之後停超過 1 秒再按 A D A D：不會觸發（要從頭按）")
	print("[測試] ④ 按 1 2 3 4（上排或右邊數字鍵盤都可以）：開「不會死」；按 J J K K：開 Cheat_Typo 的飛行穿牆")
	print("[測試] ⑤ 把 Cheat_Number 的 code 改成 wwss：編輯器黃色驚嘆號說它包含在 Cheat_Konami 的指令裡")

# 自動檢查：指令整理、模擬按鍵觸發
func _auto_check() -> void:
	_check("全形、大寫、空白、中文整理成 jjkk", _typo.get_code() == "jjkk")
	_check("空白的指令用預設 wwssadad", _konami.get_code() == "wwssadad")
	for key in [KEY_W, KEY_W, KEY_S, KEY_S, KEY_A, KEY_D, KEY_A, KEY_D]:
		_press(key)
	_check("模擬按 W W S S A D A D：打開了", _konami.is_on() and _player.is_free_moving())
	for key in [KEY_W, KEY_W, KEY_S, KEY_S, KEY_A, KEY_D, KEY_A, KEY_D]:
		_press(key)
	_check("再按一次：關掉了", not _konami.is_on() and not _player.is_free_moving())
	for key in [KEY_W, KEY_W, KEY_SPACE, KEY_S, KEY_S, KEY_A, KEY_D, KEY_A, KEY_D]:
		_press(key)
	_check("中間夾了空白鍵（不是字母數字）照樣算", _konami.is_on())
	_konami.turn_off()

# 模擬按下並放開一個鍵
func _press(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		get_viewport().push_input(event)

# 除錯按鍵：H 受傷
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		print("[測試] 模擬受傷")
		_player.take_damage(1)

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
