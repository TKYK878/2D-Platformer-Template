extends Node

# 玩家事件（由 Player 轉發，方便跨場景組件接收）
signal player_jumped
signal player_landed(impact_force: float)
signal player_hurt
signal player_died

# 世界事件
signal enemy_died(pos: Vector2)
signal item_collected(pos: Vector2)
signal level_cleared
signal level_restarted                  # 每次重生都會發（RespawnHandler 勾了 send_restart_signal 時），不分回房間或整關重來
signal level_started                    # 關卡開場時發一次（場景裡所有節點都準備好之後），換場景也會再發
signal whole_level_restarted            # 整關從頭來時才發：RespawnHandler 選「整關重來」的重生、過關畫面按再玩一次
signal checkpoint_reached(checkpoint: Node)

# 房間事件（玩家走進某個 Room 時由 Room 發出，鏡頭與重生處理者訂閱）
signal room_entered(room: Node)

# 死亡與重生事件（死亡流程的唯一溝通管道：Player 只發 player_died，重生由處理者決定）
signal respawn_requested(player: Node)   # 由死亡處理者發出，表示「現在請重生」
signal player_respawned(player: Node)    # Player.revive() 完成後發出

# 數值事件（由 Stats 轉發，供 HUD、W3 果汁訂閱）
signal value_changed(kind, old_value: int, new_value: int)

# 受擊事件（由 Hittable 介面實作方轉發，供 W3 頓幀、震動訂閱）
signal hit(target: Node, source: Node)

# 機制卡事件（主限制卡在自己規格書上寫的關鍵瞬間 emit，供 W3 果汁組件訂閱，W1 不用管）
signal mechanic_event(card: String, event: String)

# 表現層請求（W3 Juice 用，讓組件不必知道攝影機在哪）
signal shake_requested(strength: float, duration: float)
signal hitstop_requested(duration: float)
# 鏡頭放大到 1 + strength 倍再回到原本大小；focus 是放大中心（Node2D 跟著它、Vector2 固定位置、null 畫面中心），
# focus_style 是往放大中心偏多少（0 偏一點、1 定在原地、2 拉到正中央）
signal zoom_requested(strength: float, duration: float, focus: Variant, focus_style: int)

var _started_scene_id: int = 0   # 已經發過 level_started 的場景，避免同一個場景發兩次

# 開場等第一幀（所有節點的 _ready 都跑完、訊號都接好）再發 level_started；之後換場景也會發
func _ready() -> void:
	get_tree().scene_changed.connect(_emit_level_started)
	await get_tree().process_frame
	_emit_level_started()

# 目前場景還沒發過 level_started 就發一次
func _emit_level_started() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.get_instance_id() == _started_scene_id:
		return
	_started_scene_id = scene.get_instance_id()
	level_started.emit()
