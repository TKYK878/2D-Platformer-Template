extends Node2D

# 手動驗證用：GameFlow 遊戲流程。GameFlow 的 7 個訊號各自連到這個場景的 _on_<訊號名稱> 印出來；
# GameFlow_NotConnected 故意一條都沒連。RespawnHandler 選「整關重來」，按 K 死亡、H 受傷、C 過關、R 整關重來、T 切換重生方式。

@onready var _player: CharacterBody2D = $Player
@onready var _handler: Node = $RespawnHandler

# 印出操作說明
func _ready() -> void:
	print("[測試] 開場：印一次「▶ 遊戲開始」；輸出面板有 GameFlow_NotConnected 還沒連線的警告")
	print("[測試] 空白鍵跳：「▶ 玩家跳躍」；H：「▶ 玩家受傷」；C：「▶ 過關」")
	print("[測試] K 死亡（整關重來）：「▶ 玩家死亡」，0.8 秒後「▶ 玩家重生」「▶ 整關重來」；R：「▶ 玩家重生」「▶ 整關重來」")
	print("[測試] T 切成「回到目前房間」再按 K：只有「▶ 玩家死亡」「▶ 玩家重生」，沒有整關重來")
	print("[測試] 編輯器裡：GameFlow 是橘色方塊寫著「遊戲流程」，連出去的訊號有虛線；節點面板滑過訊號有中文說明")

# GameFlow 的 game_started 連到這裡
func _on_game_started() -> void:
	print("[測試] ▶ 遊戲開始")

# GameFlow 的 whole_level_restarted 連到這裡
func _on_whole_level_restarted() -> void:
	print("[測試] ▶ 整關重來")

# GameFlow 的 player_died 連到這裡
func _on_player_died() -> void:
	print("[測試] ▶ 玩家死亡")

# GameFlow 的 player_respawned 連到這裡
func _on_player_respawned() -> void:
	print("[測試] ▶ 玩家重生")

# GameFlow 的 player_hurt 連到這裡
func _on_player_hurt() -> void:
	print("[測試] ▶ 玩家受傷")

# GameFlow 的 player_jumped 連到這裡
func _on_player_jumped() -> void:
	print("[測試] ▶ 玩家跳躍")

# GameFlow 的 level_cleared 連到這裡
func _on_level_cleared() -> void:
	print("[測試] ▶ 過關")

# 除錯按鍵：K 死亡、H 受傷、C 過關、R 整關重來、T 切換重生方式
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_K:
			_player.kill()
		KEY_H:
			_player.take_damage(1.0)
		KEY_C:
			Events.level_cleared.emit()
		KEY_R:
			_handler.restart_level_now()
		KEY_T:
			_handler.mode = 1 - _handler.mode
			print("[測試] 重生方式：%s" % ("回到目前房間" if _handler.mode == 0 else "整關重來"))
