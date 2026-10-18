extends Node2D

# 手動驗證用（U225）：學員自己接勾選框開關 Juice 的示範。
# 暫停選單範本直接放進關卡、開「可編輯的子節點」，在 List 底下加一個 CheckButton「畫面震動」，
# 它的 toggled 連到兩個 Juice_ScreenShake 的 set_on()：勾著就震、取消勾就不震。

@onready var _player: CharacterBody2D = $Player

# 印出操作說明，先自動切一次勾選框，檢查兩個震動 Juice 有沒有跟著關、開
func _ready() -> void:
	Events.shake_requested.connect(func(strength: float, _duration: float):
		print("[測試] 震動請求：幅度 %.1f" % strength))
	print("[測試] 方向鍵移動、空白跳、H 受傷、Esc 暫停選單")
	print("[測試] ① 跳一下落地、按 H：畫面會震，輸出面板印出震動請求")
	print("[測試] ② 按 Esc：暫停選單最下面有「畫面震動」開關（勾著）；取消勾、按 Esc 回到遊戲")
	print("[測試] ③ 再跳、再按 H：畫面不震，也不印震動請求")
	print("[測試] ④ 再打開暫停選單把它勾回來：又會震了")
	print("[測試] ⑤ 在編輯器點 ShakeCheck → 右邊「節點」分頁 → 訊號：toggled 底下有兩條線連到 set_on")
	await get_tree().process_frame
	# 暫停選單開場會被搬進 CanvasLayer，路徑會變，用名字找
	var check := find_child("ShakeCheck", true, false) as CheckButton
	var shakes := [$Player/Juice/Juice_ScreenShake, $Player/Juice/Juice_ScreenShake_Hurt]
	check.button_pressed = false
	_check("取消勾：兩個震動 Juice 都關掉", shakes.all(func(j): return not j.enabled))
	check.button_pressed = true
	_check("勾回來：兩個震動 Juice 都打開", shakes.all(func(j): return j.enabled))

# 除錯按鍵：H 受傷
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		print("[測試] 模擬受傷")
		_player.take_damage(1)

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
