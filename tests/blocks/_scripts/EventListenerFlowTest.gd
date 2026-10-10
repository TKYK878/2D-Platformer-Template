extends Node2D

# 手動驗證用：EventListener 的「遊戲開始時」「整關重來時」。
# Listener_Started（遊戲開始時）、Listener_WholeRestart（整關重來時）、Listener_Respawned（玩家重生時）
# 各自連到這個場景的函式印出訊息。RespawnHandler 選「整關重來」，按 K 死亡、R 直接整關重來、T 切換重生方式。

@onready var _player: CharacterBody2D = $Player
@onready var _handler: Node = $RespawnHandler

# 印出操作說明
func _ready() -> void:
	print("[測試] 開場應該印一次「遊戲開始時」，而且只有一次")
	print("[測試] 按 K 死亡（整關重來）：印「玩家重生時」和「整關重來時」，不會再印「遊戲開始時」")
	print("[測試] 按 R：直接整關重來（同過關畫面的再玩一次），印「玩家重生時」和「整關重來時」")
	print("[測試] 按 T 把重生方式切成「回到目前房間」再按 K：只印「玩家重生時」，不印「整關重來時」")

# 遊戲開始時的轉接器連到這裡
func _on_started() -> void:
	print("[測試] ▶ 遊戲開始時")

# 整關重來時的轉接器連到這裡
func _on_whole_restart() -> void:
	print("[測試] ▶ 整關重來時")

# 玩家重生時的轉接器連到這裡
func _on_respawned() -> void:
	print("[測試] ▶ 玩家重生時")

# 除錯按鍵：K 死亡、R 整關重來、T 切換重生方式
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_K:
			print("[測試] 模擬死亡")
			_player.kill()
		KEY_R:
			print("[測試] 直接整關重來")
			_handler.restart_level_now()
		KEY_T:
			_handler.mode = 1 - _handler.mode
			print("[測試] 重生方式：%s" % ("回到目前房間" if _handler.mode == 0 else "整關重來"))
