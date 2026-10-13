@tool
extends Area2D

# 房間：同一個場景裡切出一塊塊畫面大小的區域，玩家走進來時發出 Events.room_entered，
# 鏡頭與重生處理者訂閱它。碰撞框依格數自動產生，學員不用拉；節點原點 = 房間左上角。
# 玩家走進這個房間時，重生位置改成「房間起點」（用 spawn_x／spawn_y 拉桿調位置，黃點會跟著動）；
# 之後踩到重生點（Checkpoint）會再改成重生點，死掉一律回到最後記下的那個（見 autoload/RespawnMemory.gd）。
# start_trigger 決定每次走進來都改，還是只有第一次；use_room_start 取消勾選時走進來不改。
# 金幣、箱子、敵人這類會放回去的東西要拖到 Room 底下，玩家在這個房間死掉時才會放回去；
# 範圍內有沒掛在任何 Room 底下的，場景樹會顯示黃色驚嘆號。
# 學員用 Scale 把房間拉大時，範圍、中心、房間起點都照縮放後算（編輯器看到多大就是多大），
# 但房間底下的東西也會一起放大，所以出黃色驚嘆號建議改用 width_in_tiles／height_in_tiles。

const _TILE_SIZE := 16
const _BORDER_COLOR := Color(0.35, 0.8, 1.0, 0.9)
const _SPAWN_COLOR := Color(1.0, 0.85, 0.2, 0.9)
const _SPAWN_OFF_COLOR := Color(0.6, 0.6, 0.6, 0.7)
# 編輯器裡每隔幾秒重新檢查一次黃色警告，學員把東西拖進來之後驚嘆號會跟著消失
const _WARNING_REFRESH_SECONDS := 1.0
# 警告裡最多列出幾個沒掛進來的物件名稱，太多就只顯示數量
const _MAX_LISTED_OBJECTS := 3

@export_group("房間設定")
## 房間寬度，以格為單位（16px 一格，30 格 = 一個螢幕寬）；拉到底還可以繼續往右拉，沒有上限
@export_range(16, 256, 1, "or_greater") var width_in_tiles: int = 30:
	set(value):
		width_in_tiles = value
		_update_shape()
## 房間高度，以格為單位（17 格 ≈ 一個螢幕高，最下面半格會被畫面切掉）；拉到底還可以繼續往右拉，沒有上限
@export_range(9, 128, 1, "or_greater") var height_in_tiles: int = 17:
	set(value):
		height_in_tiles = value
		_update_shape()

@export_group("房間起點")
## 房間起點離房間左邊幾格（30 格寬的房間，15 就是正中間）。玩家在這個房間死掉會回到這裡
@export_range(0, 256, 1, "or_greater") var spawn_x: int = 15:
	set(value):
		spawn_x = value
		_update_shape()
## 房間起點離房間底部幾格（2 就是站在最下面一排地板上）
@export_range(0, 128, 1, "or_greater") var spawn_y: int = 2:
	set(value):
		spawn_y = value
		_update_shape()
## 勾選：走進這個房間時，重生位置改成房間起點；不勾：走進來不改，死掉回到之前記下的位置（例如上一個重生點）
@export var use_room_start: bool = true:
	set(value):
		use_room_start = value
		notify_property_list_changed()
		queue_redraw()
## 什麼時候把重生位置改成房間起點：每次走進來都改，或只有第一次走進來才改（走回頭路不會改）
@export_enum("每次進入", "只有第一次進入") var start_trigger: int = 0

# 目前玩家所在房間的 instance id；所有 Room 共用，用來避免重複發出 room_entered
static var _current_room_id: int = 0

var _collision: CollisionShape2D = null
var _player: Node2D = null
var _warning_timer: float = 0.0

# 產生碰撞框；遊戲中設定只偵測玩家，並檢查重生點設定
func _ready() -> void:
	_ensure_collision()
	if Engine.is_editor_hint():
		child_entered_tree.connect(func(_n): _update_shape())
		child_exiting_tree.connect(func(_n): _update_shape())
		return
	add_to_group("room")
	collision_layer = 0       # 房間不需要被任何東西偵測到（子彈、近戰判定不會打到房間）
	collision_mask = Layers.PLAYER
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_print_problems.call_deferred()

# 執行時把房間設定的問題印到輸出面板；延後一幀，等整個場景都進場、current_scene 設好
func _print_problems() -> void:
	for message in _get_problems(get_tree().current_scene):
		push_warning("[房間] %s：%s" % [name, message])
		print("[房間] %s：%s" % [name, message])

# 回傳房間中心的全域座標，鏡頭切換用這個（房間有縮放的話照縮放後算）
func get_center() -> Vector2:
	return to_global(_get_size() / 2.0)

# 回傳房間範圍（全域座標的矩形，房間有縮放的話照縮放後算），鏡頭「房間內跟隨」用這個限制不超出房間
func get_rect() -> Rect2:
	return global_transform * Rect2(Vector2.ZERO, _get_size())

# 回傳玩家在這個房間死掉時要回到的全域座標（房間起點），重生處理者用這個
func get_spawn_point() -> Vector2:
	return to_global(_get_local_spawn_point())

# 回傳這個房間有沒有啟用房間起點，重生記憶用這個
func uses_room_start() -> bool:
	return use_room_start

# 回傳是不是每次走進來都要把重生位置改成房間起點（false＝只有第一次），重生記憶用這個
func start_saves_every_time() -> bool:
	return start_trigger == 0

# 沒有使用房間起點時，隱藏「什麼時候改」的下拉選單
func _validate_property(property: Dictionary) -> void:
	if property.name == "start_trigger" and not use_room_start:
		property.usage = PROPERTY_USAGE_NONE

# 回傳某個全域座標在不在這個房間範圍內，重生處理者找「房間裡的零件」用這個
func has_point(global_point: Vector2) -> bool:
	return get_rect().has_point(global_point)

# 玩家碰到房間邊界時開始追蹤；真正算「進入」要等玩家中心點跨進來
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player = body

# 玩家完全離開房間就停止追蹤
func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null

# 玩家中心點在房間內、而且目前記錄的房間不是自己時，宣告玩家進入這個房間。
# 用中心點判斷，玩家站在兩個房間交界來回走時，鏡頭才不會一直跳
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _player == null:
		return
	if _current_room_id == get_instance_id():
		return
	if not has_point(_player.global_position):
		return
	_current_room_id = get_instance_id()
	print("[房間] 玩家進入 %s" % name)
	Events.room_entered.emit(self)

# 房間的像素尺寸
func _get_size() -> Vector2:
	return Vector2(width_in_tiles, height_in_tiles) * _TILE_SIZE

# 房間起點的區域座標：依 spawn_x／spawn_y 換算，超出房間就夾回房間裡
func _get_local_spawn_point() -> Vector2:
	var x := clampi(spawn_x, 0, width_in_tiles)
	var y := clampi(spawn_y, 0, height_in_tiles)
	return Vector2(x * _TILE_SIZE, (height_in_tiles - y) * _TILE_SIZE)

# 檢查房間設定有沒有問題，回傳中文說明（編輯器黃色警告跟執行時警告共用）
func _get_problems(scene_root: Node) -> PackedStringArray:
	var problems := PackedStringArray()
	var scale_problem := _scale_problem()
	if scale_problem != "":
		problems.append(scale_problem)
	if spawn_x > width_in_tiles:
		problems.append("spawn_x（%d）超過房間寬度（%d 格），房間起點被放在房間最右邊" % [spawn_x, width_in_tiles])
	if spawn_y > height_in_tiles:
		problems.append("spawn_y（%d）超過房間高度（%d 格），房間起點被放在房間最上面" % [spawn_y, height_in_tiles])
	for child in get_children():
		if child is Marker2D:
			problems.append("底下的 %s 已經不會決定重生位置了，請改用 Inspector 的 spawn_x／spawn_y 拉桿，然後把它刪掉" % child.name)
	if scene_root != null:
		var loose := _find_loose_objects(scene_root)
		if not loose.is_empty():
			problems.append("%s 在房間範圍內，但沒有放在 Room 底下，玩家死掉時不會被放回去。把它拖到 %s 底下" % [_list_names(loose), name])
	return problems

# 房間（或它上面的節點）被縮放了：範圍照縮放後算所以鏡頭、重生正常，但房間裡的東西也一起放大，提醒改用拉桿
func _scale_problem() -> String:
	var s := global_scale
	if is_equal_approx(s.x, 1.0) and is_equal_approx(s.y, 1.0):
		return ""
	var size := get_rect().size
	return ("房間被 Scale 縮放成 %s 倍（現在是 %d × %d 像素）：鏡頭、重生照縮放後的大小算，但房間底下的東西也一起變成 %s 倍。"
		+ "要調房間大小建議把 Scale 改回 1，用 width_in_tiles／height_in_tiles 拉桿") 		% [_scale_text(s), roundi(size.x), roundi(size.y), _scale_text(s)]

# 縮放寫成字：左右上下一樣就一個數字，不一樣就「左右 × 上下」
func _scale_text(s: Vector2) -> String:
	if is_equal_approx(s.x, s.y):
		return _num(s.x)
	return "%s × %s" % [_num(s.x), _num(s.y)]

# 數字最多兩位小數，整數不寫小數點（5 而不是 5.0）
func _num(value: float) -> String:
	var v := snappedf(value, 0.01)
	return str(int(v)) if is_equal_approx(v, roundf(v)) else String.num(v)

# 編輯器場景樹的黃色驚嘆號：房間被縮放、房間起點超出房間、底下還放著舊的 Marker2D、範圍內有沒掛進來的物件
func _get_configuration_warnings() -> PackedStringArray:
	if not is_inside_tree():
		return PackedStringArray()
	return _get_problems(get_tree().edited_scene_root)

# 找出落在這個房間範圍內、會被放回去、但沒有掛在任何 Room 底下的物件
func _find_loose_objects(scene_root: Node) -> Array[Node]:
	var out: Array[Node] = []
	_scan_loose(scene_root, out)
	return out

# 往下掃場景樹，碰到 Room 就整棵跳過（掛在任何 Room 底下的都算有歸屬）
func _scan_loose(node: Node, out: Array[Node]) -> void:
	if node.get_script() == get_script():
		return
	if node is Node2D and _is_resettable(node) and has_point((node as Node2D).global_position):
		out.append(node)
	for child in node.get_children():
		_scan_loose(child, out)

# 這個節點的腳本有沒有 reset()（玩家死掉時會被放回去的零件）；看腳本本身，編輯器裡也查得到
func _is_resettable(node: Node) -> bool:
	var script: Script = node.get_script()
	if script == null:
		return false
	for method in script.get_script_method_list():
		if method["name"] == "reset":
			return true
	return false

# 把物件名稱排成「A、B、C 等 5 個」給警告訊息用
func _list_names(nodes: Array[Node]) -> String:
	var names := PackedStringArray()
	for i in mini(nodes.size(), _MAX_LISTED_OBJECTS):
		names.append(nodes[i].name)
	var text := "、".join(names)
	if nodes.size() > _MAX_LISTED_OBJECTS:
		text += " 等 %d 個" % nodes.size()
	return text

# 建立房間自己用的碰撞框節點（不存進場景檔，學員在場景樹裡看不到也改不到）
func _ensure_collision() -> void:
	if _collision != null:
		return
	_collision = CollisionShape2D.new()
	_collision.shape = RectangleShape2D.new()
	add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	_update_shape()

# 依格數更新碰撞框大小與位置，並重畫編輯器邊框、更新黃色警告
func _update_shape() -> void:
	queue_redraw()
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
	if _collision == null:
		return
	var size := _get_size()
	(_collision.shape as RectangleShape2D).size = size
	_collision.position = size / 2.0

# 編輯畫面持續重畫，房間起點標記跟著拉桿即時更新；每隔一段時間重新檢查黃色警告
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	queue_redraw()
	_warning_timer += delta
	if _warning_timer >= _WARNING_REFRESH_SECONDS:
		_warning_timer = 0.0
		update_configuration_warnings()

# 編輯畫面用：畫房間邊框、房間名稱、房間起點標記（不使用房間起點時改成灰色並標註）
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var size := _get_size()
	draw_rect(Rect2(Vector2.ZERO, size), _BORDER_COLOR, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(4, 14), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, _BORDER_COLOR)
	var spawn := _get_local_spawn_point()
	var color := _SPAWN_COLOR if use_room_start else _SPAWN_OFF_COLOR
	var label := "房間起點（不使用）"
	if use_room_start:
		label = "房間起點" if start_trigger == 0 else "房間起點（只有第一次）"
	draw_circle(spawn, 4.0, color)
	draw_string(ThemeDB.fallback_font, spawn + Vector2(6, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
