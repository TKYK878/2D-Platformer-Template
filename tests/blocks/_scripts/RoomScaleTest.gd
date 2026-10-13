extends Node2D

# 手動驗證用：學員用 Scale 把房間放大（camear_bug 回報的情況）。Room1_Scaled 是預設 30×17 格、Scale 5 倍，
# 等於 2400×1360 像素；鏡頭是瞬切、zoom 0.2，看得到整個房間。以前程式只算沒縮放的左上角那一小塊，
# 玩家走進那一小塊時鏡頭會跳到那一小塊的中心（畫面跑掉）。

@onready var _camera: Camera2D = $Camera2D
@onready var _room: Area2D = $Room1_Scaled
@onready var _player: Node2D = $Player

# 印出操作說明與房間範圍
func _ready() -> void:
	print("[測試] ① 編輯器裡：Room1_Scaled 有黃色驚嘆號「房間被 Scale 縮放成 5 倍…建議改回 1 用拉桿」；房間裡的金幣也被放大 5 倍")
	print("[測試] ② 開場輸出面板有同一則中文警告")
	print("[測試] ③ 按 T：玩家瞬移到房間左上角那一小塊（以前鏡頭會跳走的地方）；畫面不動。按 Y 瞬移回地板右邊；畫面不動")
	print("[測試] ④ 碰撞死掉（按 K）重生：回到房間起點（左邊數來第 3 格×5 倍的位置，地板上）")
	await get_tree().physics_frame
	print("[測試] 房間範圍：%s（應該是 0,0 起、2400 × 1360）" % _room.get_rect())
	print("[測試] 房間中心：%s（應該是 1200, 680）" % _room.get_center())

# 除錯按鍵：T 去左上角、Y 回地板、K 死掉
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_T:
			_player.global_position = Vector2(240, 120)
		KEY_Y:
			_player.global_position = Vector2(2000, 1300)
		KEY_K:
			_player.kill()
			return
		_:
			return
	await get_tree().create_timer(0.3).timeout
	print("[測試] 玩家 %s，畫面中心 %s（應該一直是 1200, 680）" % [_player.global_position.round(), _camera.get_screen_center_position().round()])
