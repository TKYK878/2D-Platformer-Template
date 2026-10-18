extends Node

# 重生處理者：聽到玩家死亡後，等一下再把玩家復活，不重新載入場景。
# 放在關卡場景裡，學員看得到、刪得掉、換得掉；刪掉的話玩家死了就不會回來（遊戲不會壞）。
# 重生時放回去的是掛在房間底下的東西（沒有 Room 的關卡是整個場景），數值由那些東西自己倒回（金幣扣回、門還鑰匙）。
# 重生位置：最後記下的重生位置（走進房間記房間起點、踩到重生點記重生點，見 RespawnMemory），
# 一個都沒記過就回到玩家一開始的位置。重生到別的房間時，死掉的房間跟重生的房間都會復位。
# 長按 Input Map 的 restart 動作（預設 R、手把 Y）可以馬上重來，玩家沒死也可以，箱子推錯卡關時用。

@export_group("重生設定")
## 死亡後隔多久重生（秒）
@export_range(0.0, 3.0) var delay: float = 0.8
## 死亡後要怎麼重來：回到目前房間，或是整關從頭開始
@export_enum("回到目前房間", "整關重來") var mode: int = 0
## 重生時把房間裡的箱子、敵人、金幣等零件放回去，撿到的金幣、用掉的鑰匙也跟著倒回（整關重來時處理整個關卡）；
## 不勾的話什麼都不放回、數值也不倒回
@export var reset_room_objects: bool = true
## 每次重生都發出「關卡重新開始」事件，給想在重來時做事的組件聽
@export var send_restart_signal: bool = true

@export_group("長按重來")
## 長按 restart 動作（預設鍵盤 R、手把 Y）幾秒就馬上重來（跟死掉後一樣照上面的設定：回到目前房間或整關重來），箱子推錯卡關時用；0 表示不能長按重來
@export_range(0.0, 3.0, 0.05) var hold_time: float = 0.6
## 長按的時候在玩家頭上顯示一條進度條
@export var show_hold_bar: bool = true

const _MODE_ROOM := 0
const _MODE_LEVEL := 1
const _RESTART_ACTION := &"restart"
# 進度條的大小、離玩家多高（玩家位置往頭頂方向）
const _BAR_SIZE := Vector2(28.0, 4.0)
const _BAR_GAP := 30.0

var _current_room: Node2D = null
var _start_position: Vector2 = Vector2.ZERO
var _has_start_position: bool = false
var _warned_no_room: bool = false
var _held: float = 0.0          # restart 已經連續按住幾秒
var _holding: bool = false      # 這次按住是在遊戲中按下的（暫停、過關畫面中按下的不算），而且還沒重來過
var _bar: Node2D = null

# 加入群組、接上訊號，記住玩家一開始的位置
func _ready() -> void:
	add_to_group("respawn_handler")
	Events.room_entered.connect(_on_room_entered)
	Events.player_died.connect(_on_player_died)
	if not _remember_start_position():
		_remember_start_position.call_deferred()
	_warn_loose_groups.call_deferred()
	if not _is_active_handler():
		push_warning("[重生] 場景裡有不只一個 RespawnHandler，只有第一個會生效")
		printerr("⚠ [重生] 場景裡有不只一個 RespawnHandler，%s 不會生效，可以刪掉" % name)
	elif hold_time > 0.0:
		_check_restart_action()
		if show_hold_bar:
			_make_bar()

# 記住玩家一開始的位置，找得到玩家就回傳 true
func _remember_start_position() -> bool:
	if _has_start_position:
		return true
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	_start_position = player.global_position
	_has_start_position = true
	return true

# 只有群組裡的第一個重生處理者會真的處理死亡，避免放兩個時玩家被復活兩次
func _is_active_handler() -> bool:
	return get_tree().get_first_node_in_group("respawn_handler") == self

# 記住玩家目前在哪個房間
func _on_room_entered(room: Node) -> void:
	_current_room = room as Node2D

# 玩家死亡：等 delay 秒，復位零件、還原數值，再把玩家復活到重生位置
func _on_player_died() -> void:
	if not _is_active_handler():
		return
	await get_tree().create_timer(delay).timeout
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("revive"):
		return
	if player.has_method("is_dead") and not player.is_dead():
		return  # 等待期間已經被別人復活了
	if mode == _MODE_LEVEL:
		_restart_level(player)
	else:
		_respawn_in_room(player)
	if send_restart_signal:
		Events.level_restarted.emit()

# 長按重來用的 restart 動作不在 Input Map、或沒有任何按鍵時印中文警告
func _check_restart_action() -> void:
	if InputMap.has_action(_RESTART_ACTION) and not InputMap.action_get_events(_RESTART_ACTION).is_empty():
		return
	var message := "[重生] Input Map 裡沒有 restart 動作（或沒有綁按鍵），不能長按重來。到「專案設定 → Input Map」加一個叫 restart 的動作"
	push_warning(message)
	printerr("⚠ %s" % message)

# 每幀檢查長按重來：在遊戲中按下才開始算，按滿 hold_time 秒重來一次，要放開再按才會再重來
func _physics_process(delta: float) -> void:
	if hold_time <= 0.0 or not _is_active_handler() or not InputMap.has_action(_RESTART_ACTION):
		return
	var player := get_tree().get_first_node_in_group("player")
	var alive: bool = player != null and not (player.has_method("is_dead") and player.is_dead())
	if Input.is_action_just_pressed(_RESTART_ACTION) and alive:
		_holding = true
		_held = 0.0
	if not Input.is_action_pressed(_RESTART_ACTION) or not alive:
		_holding = false
	if _holding:
		_held += delta
		if _held >= hold_time:
			_holding = false
			print("[重生] 長按重來")
			restart_now()
	_update_bar(player)

# 馬上重來（玩家沒死也可以），跟死掉後一樣照「重來方式」回到目前房間或整關重來；長按重來用這個
func restart_now() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("revive"):
		return
	if mode == _MODE_LEVEL:
		_restart_level(player)
	else:
		_respawn_in_room(player)
	if send_restart_signal:
		Events.level_restarted.emit()

# 建立長按進度條（程式建的，學員不用擺節點）
func _make_bar() -> void:
	_bar = Node2D.new()
	_bar.name = "HoldRestartBar"
	_bar.top_level = true
	_bar.z_index = 100
	_bar.visible = false
	_bar.draw.connect(_draw_bar)
	add_child(_bar)

# 長按時把進度條擺到玩家頭頂（重力翻轉時也是頭頂那一邊），沒在按就藏起來
func _update_bar(player: Node) -> void:
	if _bar == null:
		return
	_bar.visible = _holding and player is Node2D
	if not _bar.visible:
		return
	var up: Vector2 = player.up_direction if "up_direction" in player else Vector2.UP
	_bar.global_position = (player as Node2D).global_position + up * _BAR_GAP
	_bar.queue_redraw()

# 畫進度條：黑底、白色填滿到按住的比例
func _draw_bar() -> void:
	var ratio := clampf(_held / maxf(hold_time, 0.01), 0.0, 1.0)
	var rect := Rect2(-_BAR_SIZE / 2.0, _BAR_SIZE)
	_bar.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.6))
	_bar.draw_rect(Rect2(rect.position, Vector2(_BAR_SIZE.x * ratio, _BAR_SIZE.y)), Color.WHITE)
	_bar.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.9), false, 1.0)

# 馬上整關重來（玩家沒死也可以），過關畫面按「再玩一次」用這個
func restart_level_now() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("revive"):
		return
	_restart_level(player)
	if send_restart_signal:
		Events.level_restarted.emit()

# 回到目前房間：放回死掉的房間的東西並倒回數值；重生到別的房間時，重生的房間也一起處理
func _respawn_in_room(player: Node) -> void:
	var target := _pick_respawn()
	var death_room: Node2D = _current_room if _current_room != null and is_instance_valid(_current_room) else null
	var target_room: Node2D = target["room"]
	if reset_room_objects:
		if death_room == null and target_room == null:
			_reset_objects(player, null, true)
		else:
			if death_room != null:
				_reset_objects(player, death_room, true)
			if target_room != null and target_room != death_room:
				_reset_objects(player, target_room, true)
	_revive(player, target["position"])

# 整關重來：放回整個關卡的東西、倒回它們帶來的數值（不看重生分組），清空踩過的重生點，玩家回到起點
func _restart_level(player: Node) -> void:
	if reset_room_objects:
		_reset_objects(player, null, false)
	RespawnMemory.restart_level()
	_revive(player, _start_position)
	Events.whole_level_restarted.emit()

# 通知大家要重生了，再請玩家復活到指定位置
func _revive(player: Node, at_position: Vector2) -> void:
	Events.respawn_requested.emit(player)
	player.revive(at_position)

# 決定「回到目前房間」模式要重生在哪裡：最後記下的重生位置，沒有就回玩家一開始的位置；回傳位置與那個位置所在的房間
func _pick_respawn() -> Dictionary:
	if get_tree().get_first_node_in_group("room") == null:
		_warn_no_room()
	if RespawnMemory.has_respawn_point():
		var point: Vector2 = RespawnMemory.get_respawn_point()
		return {"position": point, "room": _find_room_at(point)}
	print("[重生] 還沒記下任何重生位置（沒踩過重生點、也沒進過有起點的房間），回到玩家一開始的位置")
	return {"position": _start_position, "room": _find_room_at(_start_position)}

# 找出某個全域座標落在哪一個房間，沒有就回傳 null
func _find_room_at(global_point: Vector2) -> Node2D:
	for room in get_tree().get_nodes_in_group("room"):
		if room.has_point(global_point):
			return room
	return null

# 場景裡沒有 Room 時，第一次死亡印一次中文提示
func _warn_no_room() -> void:
	if _warned_no_room:
		return
	_warned_no_room = true
	push_warning("[重生] 場景裡沒有 Room，玩家會重生在一開始的位置（踩過重生點就在重生點）")
	print("[重生] 場景裡沒有任何房間（Room），玩家會重生在一開始的位置；踩過重生點的話就在重生點。想分房間重生，把 blocks/Room.tscn 拖進關卡")

# 放回範圍內的零件、倒回它們帶來的數值；room 是 null 代表整個關卡。玩家身上的組件不算。
# 有 Room 的關卡只處理掛在 Room 底下的東西（沒掛的 Room 會顯示黃色警告）；完全沒有 Room 的關卡處理整個場景。
# use_groups 為 true 時（在房間裡死掉）照重生分組的規則；整關重來傳 false，全部放回、全部倒回。
# 先倒回數值再放回物件：rewind_values() 要靠「還沒放回」的狀態判斷有沒有被撿過
func _reset_objects(player: Node, room: Node2D, use_groups: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var roots: Array[Node] = []
	if room != null:
		roots.append(room)
	else:
		roots.assign(get_tree().get_nodes_in_group("room"))
		if roots.is_empty():
			roots.append(scene)
	var to_rewind: Array[Node] = []
	var to_reset: Array[Node] = []
	for root in roots:
		_collect_targets(root, player, use_groups, true, true, to_rewind, to_reset)
	for target in to_rewind:
		target.rewind_values()
	for target in to_reset:
		target.reset()

# 遞迴收集要倒回數值（有 rewind_values()）與要放回（有 reset()）的節點；碰到重生分組就改用那個分組的規則
func _collect_targets(node: Node, player: Node, use_groups: bool, do_reset: bool, do_rewind: bool,
		to_rewind: Array[Node], to_reset: Array[Node]) -> void:
	if node == player:
		return
	if use_groups and node.has_method("resets_objects"):
		do_reset = node.resets_objects()
		do_rewind = node.rewinds_values()
	if node is Node2D:
		if do_rewind and node.has_method("rewind_values"):
			to_rewind.append(node)
		if do_reset and node.has_method("reset"):
			to_reset.append(node)
	for child in node.get_children():
		_collect_targets(child, player, use_groups, do_reset, do_rewind, to_rewind, to_reset)

# 有 Room 的關卡，重生分組放在 Room 外面不會有作用：延後一幀等 Room 都進場，掃出來印中文警告。
# 完全沒有 Room 的關卡整個場景一起復位，分組放哪裡都有效，不用警告
func _warn_loose_groups() -> void:
	if not _is_active_handler() or get_tree().get_nodes_in_group("room").is_empty():
		return
	var scene := get_tree().current_scene
	if scene != null:
		_scan_loose_groups(scene)

# 往下掃場景樹，碰到 Room 就整棵跳過，剩下的重生分組都是放錯位置的
func _scan_loose_groups(node: Node) -> void:
	if node.is_in_group("room"):
		return
	if node.has_method("resets_objects"):
		push_warning("[重生] %s 沒有放在 Room 底下，這個分組的規則不會生效" % node.name)
		print("[重生] 重生分組 %s 沒有放在任何 Room 底下，規則不會生效。把它拖到房間（Room）底下" % node.name)
	for child in node.get_children():
		_scan_loose_groups(child)
