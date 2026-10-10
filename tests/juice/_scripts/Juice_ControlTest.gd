extends Node2D

# 手動驗證用：用訊號控制 Juice（clear／turn_on／turn_off）與閃色的 stop_others。
# Flash_Yellow 受傷時閃黃 1 秒、Flash_Red 死亡時閃紅（stop_others 勾著）、Juice_Trail 跑起來有殘影、Juice_ScreenShake 落地震。

@onready var _player: CharacterBody2D = $Player
@onready var _yellow: Node = $Player/Juice/Flash_Yellow
@onready var _red: Node = $Player/Juice/Flash_Red
@onready var _juices: Array = [$Player/Juice/Flash_Yellow, $Player/Juice/Juice_Trail, $Player/Juice/Juice_ScreenShake]

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳、H 受傷（閃黃 1 秒）、K 死亡（閃紅）、O 切換閃紅的 stop_others")
	print("[測試] C＝clear　X＝turn_off　V＝turn_on（對閃黃、殘影、落地震動三個一起做）")
	print("[測試] ① 按 H 閃黃時馬上按 K：直接變成閃紅，看不到黃紅混成的橘色")
	print("[測試] ② 按 O 把 stop_others 關掉，再做一次 ①：顏色會混在一起（偏暗的橘色）")
	print("[測試] ③ 按 H 閃黃時按 C：立刻停止、顏色恢復；之後再按 H 照樣會閃")
	print("[測試] ④ 按 X：受傷不閃黃、跑步沒有殘影、落地不震；按 V 全部恢復")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_H:
			print("[測試] 模擬受傷")
			_player.take_damage(1)
		KEY_K:
			print("[測試] 模擬死亡")
			_player.kill()
		KEY_O:
			_red.stop_others = not _red.stop_others
			print("[測試] 閃紅的 stop_others：%s" % ("勾" if _red.stop_others else "不勾"))
		KEY_C:
			print("[測試] clear")
			for j in _juices: j.clear()
		KEY_X:
			print("[測試] turn_off")
			for j in _juices: j.turn_off()
		KEY_V:
			print("[測試] turn_on")
			for j in _juices: j.turn_on()
