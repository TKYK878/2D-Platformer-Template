extends Node2D

# 手動驗證用：全螢幕閃光（一次型，備品）。
# Juice_ScreenFlash：預設值（受傷時、紅、濃度 0.4、0.25 秒）。
# Juice_ScreenFlash_Manual：不自動觸發、白、濃度 0.8、0.5 秒，按 F 呼叫 play()。
# 另外掛了頓幀（受傷時 0.3 秒），確認頓幀時閃光照樣淡掉；右邊有一根尖刺。

@onready var _player: CharacterBody2D = $Player
@onready var _manual: Node = $Player/Juice/Juice_ScreenFlash_Manual

# 印出操作說明
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳、H 受傷、F 白色閃光、K 死亡、0 Juice 總開關")
	print("[測試] ① 碰尖刺或按 H：整個畫面閃一下紅色、0.25 秒淡掉；頓幀畫面停住時閃光照樣在淡")
	print("[測試] ② 按 F：整個畫面白光一閃，比紅色濃、久一點")
	print("[測試] ③ 白光淡到一半按 K 死亡：重生後畫面沒有殘留顏色")
	print("[測試] ④ 按 0 關掉 Juice：H、F 都不會閃；再按 0 打開恢復")

# 除錯按鍵：H 受傷、F 白色閃光、K 死亡
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_H:
			_player.take_damage(1)
		KEY_F:
			_manual.play()
		KEY_K:
			print("[測試] 模擬死亡")
			_player.kill()
