extends Node2D

# 手動驗證用（U234）：作弊組件「只當接口」。場景裡有三個 Cheat：
# Cheat_Invincible（無敵）、Cheat_Fly（飛行＋穿牆）、Cheat_Empty（什麼都沒勾，開場會印警告）。
# 畫面左上角的勾選框 toggled 連到 Cheat_Fly 的 set_on，按鈕 pressed 連到 Cheat_Invincible 的 toggle。

@onready var _player: CharacterBody2D = $Player
@onready var _invincible: Node = $Cheat_Invincible
@onready var _fly: Node = $Cheat_Fly

# 印出操作說明，先自動檢查一輪
func _ready() -> void:
	_invincible.turned_on.connect(func(): print("[測試] Cheat_Invincible 發出 turned_on"))
	_invincible.turned_off.connect(func(): print("[測試] Cheat_Invincible 發出 turned_off"))
	_auto_check()
	print("[測試] 方向鍵移動、空白跳、H 受傷；滑鼠點左上角的勾選框、按鈕")
	print("[測試] ① 開場輸出面板有一行「Cheat_Empty：沒有勾任何功能」；編輯器裡 Cheat_Empty 有黃色驚嘆號")
	print("[測試] ② 點「無敵」按鈕：畫面上方出現「作弊中：無敵」，按 H、碰尖刺不扣血；再點一次就關掉、小字消失")
	print("[測試] ③ 勾「飛行」：上下左右自由飛、可以穿牆，小字多一行「作弊中：飛行穿牆」；取消勾就掉下來")
	print("[測試] ④ 在編輯器點 FlyCheck → 右邊「節點」分頁：toggled 連到 Cheat_Fly 的 set_on")

# 自動檢查：打開、關掉、拔掉組件時效果有沒有跟著變
func _auto_check() -> void:
	_invincible.turn_on()
	_check("打開無敵作弊：玩家變無敵", _player.is_invincible())
	_check("「作弊中」小字的內容", _invincible.get_label_text() == "作弊中：無敵")
	_invincible.turn_off()
	_check("關掉：玩家不是無敵了", not _player.is_invincible())
	_fly.set_on(true)
	_check("set_on(true)：玩家在飛、碰撞遮罩清空", _player.is_free_moving() and _player.collision_mask == 0)
	_fly.set_off(true)
	_check("set_off(true)：玩家不飛了、碰撞遮罩還原", not _player.is_free_moving() and _player.collision_mask != 0)
	var temp: Node = load("res://cheats/Cheat.tscn").instantiate()
	temp.no_death = true
	add_child(temp)
	temp.turn_on()
	remove_child(temp)
	temp.free()
	_check("開著的作弊被拔掉：效果跟著消失", not _player.is_invincible())

# 除錯按鍵：H 受傷
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		print("[測試] 模擬受傷")
		_player.take_damage(1)

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
