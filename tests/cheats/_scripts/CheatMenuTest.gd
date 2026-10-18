extends Node2D

# 手動驗證用（U236）：作弊的解鎖方式「選單勾選框」。暫停選單範本直接放進關卡、開「可編輯的子節點」，
# 在 List 底下放兩個 Cheat：Cheat_Fly（飛行＋穿牆，字用預設的）、Cheat_God（不會死，label 打「上帝模式」）。
# 另外 Cheat_Loose 選了選單勾選框卻放在關卡最外層，開場會印警告、編輯器有黃色驚嘆號。

@onready var _player: CharacterBody2D = $Player

# 印出操作說明，等暫停選單搬進 CanvasLayer 之後自動檢查一輪
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳、H 受傷、Esc 暫停選單")
	print("[測試] ① 開場輸出面板有 Cheat_Loose 的警告（沒有放在選單裡）")
	print("[測試] ② 按 Esc：選單最下面多兩個勾選框「作弊：飛行穿牆」「上帝模式」，鍵盤上下選得到、有按鈕音效")
	print("[測試] ③ 勾「作弊：飛行穿牆」、按 Esc 回到遊戲：可以飛、畫面上方出現「作弊中：飛行穿牆」")
	print("[測試] ④ 再打開選單：勾選框還是勾著；取消勾回到遊戲：掉下來")
	print("[測試] ⑤ 在編輯器把 Cheat_Fly 的 label 打字：選單上的字跟著變；清空就變回預設的字")
	await get_tree().process_frame
	var fly := find_child("Cheat_Fly", true, false)
	var god := find_child("Cheat_God", true, false)
	_check("預設的字是「作弊：飛行穿牆」", fly.get_menu_text() == "作弊：飛行穿牆")
	_check("label 打了「上帝模式」就用它", god.get_menu_text() == "上帝模式")
	var check := fly.get_child(0) as CheckButton
	check.button_pressed = true
	_check("勾起來：玩家在飛", _player.is_free_moving())
	fly.turn_off()
	_check("從別的地方關掉：勾選框跟著取消勾", not check.button_pressed and not _player.is_free_moving())

# 除錯按鍵：H 受傷
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		print("[測試] 模擬受傷")
		_player.take_damage(1)

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
