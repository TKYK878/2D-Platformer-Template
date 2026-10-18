extends Node

# 重生記憶：全關卡只記一個「重生位置」，死掉一律回到最後記下的那個（RespawnHandler 來問）。
# 會覆蓋重生位置的有兩種：走進房間（記房間起點，看 Room 的 use_room_start／start_trigger）、
# 踩到重生點（記重生點，看 Checkpoint 的 save_trigger）。
# 數值不在這裡記：死掉時放回去的金幣、門會自己把當初加的／扣的數值倒回（rewind_values()），
# 物件跟數值永遠一起動，不會出現「同一枚金幣撿兩次」。見 documents/00b_rooms_and_soft_respawn.md §5。

# 重生後等幾個物理幀才恢復「進房間就記房間起點」，讓重生造成的進房間不算存檔
const _RESPAWN_IGNORE_FRAMES := 3

var _has_respawn_point: bool = false
var _respawn_point: Vector2 = Vector2.ZERO
var _rooms_saved: Dictionary = {}   # 房間的 instance id(int) -> true，「只有第一次進入」的房間記過一次就不再記
var _ignore_room_enter: bool = false

# 接上重生點、進房間、重生、死亡、過關的訊號
func _ready() -> void:
	Events.checkpoint_reached.connect(_on_checkpoint_reached)
	Events.room_entered.connect(_on_room_entered)
	Events.respawn_requested.connect(_on_respawn_requested)
	Events.player_died.connect(_on_player_died)
	Events.level_cleared.connect(_on_level_cleared)

# 踩到重生點（Checkpoint 依 save_trigger 決定要不要發出）：重生位置改成這個重生點
func _on_checkpoint_reached(checkpoint: Node2D) -> void:
	_save(checkpoint.global_position, "重生點「%s」" % checkpoint.name)

# 走進房間：房間有起點、而且這次該記（每次進入，或第一次進入）就把重生位置改成房間起點；
# 重生造成的進房間不算，不然會蓋掉剛剛用來重生的重生點
func _on_room_entered(room: Node) -> void:
	if _ignore_room_enter or not room.uses_room_start():
		return
	var id := room.get_instance_id()
	if not room.start_saves_every_time() and _rooms_saved.has(id):
		return
	_rooms_saved[id] = true
	_save(room.get_spawn_point(), "%s 的房間起點" % room.name)

# 要重生了：接下來幾個物理幀內的進房間都不算存檔
func _on_respawn_requested(_player: Node) -> void:
	_ignore_room_enter = true
	for i in _RESPAWN_IGNORE_FRAMES:
		await get_tree().physics_frame
	_ignore_room_enter = false

# 把重生位置改成指定的位置，作弊的「在這裡設重生點」這類組件用這個；label 是印在輸出面板的說明
func save_point(at_position: Vector2, label: String) -> void:
	_save(at_position, label)

# 記下新的重生位置，並在輸出面板說一聲，學員看得出現在會重生在哪
func _save(at_position: Vector2, label: String) -> void:
	_has_respawn_point = true
	_respawn_point = at_position
	print("[重生] 重生位置改成 %s" % label)

# 玩家死了但場景裡沒有重生處理者：提醒學員，不然看起來像當機
func _on_player_died() -> void:
	if get_tree().get_first_node_in_group("respawn_handler") == null:
		print("[重生] 玩家死亡了，但場景裡沒有 RespawnHandler，所以不會重生。想要重生就把 blocks/RespawnHandler.tscn 拖進關卡")

# 到達終點：清空所有重生記憶；場景裡沒有過關畫面的話提醒學員，不然看起來像沒反應
func _on_level_cleared() -> void:
	clear()
	if get_tree().get_first_node_in_group("clear_screen") == null:
		print("[過關] 過關了，但場景裡沒有過關畫面（ClearScreen），所以畫面上不會有反應。想要過關畫面就把 blocks/ClearScreen.tscn 拖進關卡")

# 整關重來時呼叫：清空記下的重生位置（數值由放回去的物件自己倒回）
func restart_level() -> void:
	clear()

# 清空所有記錄，過關、整關重來時用；場景裡的重生點也跟著變回沒踩過，房間也變回沒進過，才能再記一次
func clear() -> void:
	_has_respawn_point = false
	_respawn_point = Vector2.ZERO
	_rooms_saved.clear()
	get_tree().call_group("checkpoint", "forget")

# 查詢有沒有記下重生位置
func has_respawn_point() -> bool:
	return _has_respawn_point

# 查詢記下的重生位置，沒記過就回傳 (0, 0)
func get_respawn_point() -> Vector2:
	return _respawn_point
