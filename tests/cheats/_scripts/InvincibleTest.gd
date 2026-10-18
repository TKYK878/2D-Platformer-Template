extends Node2D

# 手動驗證用（U232）：Player 的無敵 API。I 開關無敵（不扣血、不被擊退），K 開關「連死都不會死」。
# 地上有尖刺、敵人、會秒殺的岩漿，開著無敵走過去都沒事；只開無敵、沒開「不會死」的話，踩岩漿照樣會死。

@onready var _player: CharacterBody2D = $Player

var _invincible: bool = false
var _no_death: bool = false

# 印出操作說明，先自動檢查一輪 API
func _ready() -> void:
	Stats.value_changed.connect(func(kind: String, _old: int, new_value: int):
		if kind == Stats.HEALTH_KIND:
			print("[測試] 血量變成 %d" % new_value))
	_auto_check()
	print("[測試] 方向鍵移動、空白跳；I 開關無敵、K 開關「連死都不會死」、H 受傷一下")
	print("[測試] ① 什麼都不開：碰尖刺、敵人會扣血被彈開；踩右邊的岩漿會死")
	print("[測試] ② 按 I（無敵）：碰尖刺、敵人、按 H 都不扣血、不被彈開；踩岩漿還是會死")
	print("[測試] ③ 再按 K（不會死）：踩岩漿什麼事都沒發生，可以站在上面")
	print("[測試] ④ 按 I、K 都關掉：又會受傷、會死")

# 自動檢查：無敵時受傷、被打、被秒殺的反應；開無敵的組件被刪掉時效果跟著消失
func _auto_check() -> void:
	var health := Stats.get_value(Stats.HEALTH_KIND)
	_player.set_invincible(self, true)
	_player.take_damage(1)
	_player.take_hit(1, Vector2(300, -300), self)
	_check("無敵時受傷、被打都不扣血", Stats.get_value(Stats.HEALTH_KIND) == health)
	_check("無敵時被打不會被彈開", _player.velocity == Vector2.ZERO)
	_player.set_invincible(self, true, true)
	_player.kill()
	_check("開了「不會死」，kill() 什麼事都沒發生", not _player.is_dead())
	_player.set_invincible(self, false)
	_check("關掉之後就不是無敵了", not _player.is_invincible())
	var temp := Node.new()
	_player.set_invincible(temp, true)
	temp.free()
	_check("開無敵的組件被刪掉，無敵跟著消失", not _player.is_invincible())

# 除錯按鍵：I 無敵、K 不會死、H 受傷
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_I:
			_invincible = not _invincible
			_apply()
		KEY_K:
			_no_death = not _no_death
			_apply()
		KEY_H:
			print("[測試] 模擬受傷")
			_player.take_damage(1)

# 把目前的開關套到 Player 上並印出來
func _apply() -> void:
	_player.set_invincible(self, _invincible or _no_death, _no_death)
	print("[測試] 無敵：%s　不會死：%s" % ["開" if _invincible else "關", "開" if _no_death else "關"])

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
