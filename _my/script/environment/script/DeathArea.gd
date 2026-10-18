@tool
extends Area2D

# 死亡區：遊戲中看不見的一塊範圍，從觸發區（AreaTrigger）改來的，不用連任何線就會生效。
# 死亡區域：玩家整個身體進到範圍裡就死掉；計時死亡區：整個身體待在範圍裡一段時間才死掉，中途出來重新算；
# 扣血：玩家身體邊緣一碰到範圍就扣血，出去再進來會再扣一次。
# 拖進關卡、用拉桿調大小；編輯器裡畫成半透明的紅框，方便擺位置。

## 範圍有幾格寬（一格 16 像素）
@export_range(1, 40) var width_tiles: int = 4:
	set(value):
		width_tiles = value
		_apply_size()
## 範圍有幾格高（一格 16 像素）
@export_range(1, 40) var height_tiles: int = 4:
	set(value):
		height_tiles = value
		_apply_size()

## 死亡區域：玩家整個身體進到範圍裡就死掉；計時死亡區：整個身體待在範圍裡 delay 秒才死掉（中途出來重新算）；
## 扣血：玩家身體邊緣一碰到範圍就扣 damage 點血
@export_enum("死亡區域", "計時死亡區", "扣血") var mode: int = MODE_DEATH:
	set(value):
		mode = value
		notify_property_list_changed()

## 整個身體要在範圍裡待幾秒才會死掉（「計時死亡區」才會顯示這一欄）
@export_range(0.1, 10.0, 0.1) var delay: float = 2.0

## 碰到範圍時扣幾點血（「扣血」才會顯示這一欄）
@export_range(1, 10) var damage: int = 1

## 玩家在這裡死掉時發出（死亡區域、計時死亡區）
signal killed
## 玩家在這裡被扣血時發出（扣血）
signal hurt

const MODE_DEATH := 0
const MODE_TIMED := 1
const MODE_DAMAGE := 2

const _TILE_SIZE := 16
const _FILL_COLOR := Color(1.0, 0.25, 0.25, 0.18)
const _EDGE_COLOR := Color(1.0, 0.25, 0.25, 0.8)

var _players: Array[Node] = []
var _inside_time: Dictionary = {}   # 玩家 -> 整個身體連續待在範圍裡幾秒（計時死亡區用）

# 建碰撞範圍；遊戲中設定碰撞層、接上進出
func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	add_to_group("signal_source")
	collision_layer = Layers.SENSOR
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# 依格數設定碰撞範圍（以節點位置為中心）
func _apply_size() -> void:
	if not is_inside_tree():
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node, false, Node.INTERNAL_MODE_FRONT)
	if not shape_node.shape is RectangleShape2D:
		shape_node.shape = RectangleShape2D.new()
	(shape_node.shape as RectangleShape2D).size = _get_size()
	queue_redraw()

# 範圍的像素大小
func _get_size() -> Vector2:
	return Vector2(width_tiles, height_tiles) * _TILE_SIZE

# 玩家碰到範圍：記下來；「扣血」模式這時候直接扣血
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or body in _players:
		return
	_players.append(body)
	_inside_time[body] = 0.0
	if mode == MODE_DAMAGE and not body.is_dead():
		body.take_hit(damage, Vector2.ZERO, self)
		hurt.emit()

# 玩家離開範圍：不再記它，計時歸零
func _on_body_exited(body: Node) -> void:
	_players.erase(body)
	_inside_time.erase(body)

# 每個物理幀檢查範圍裡的玩家：整個身體都在範圍裡的話，死亡區域直接死、計時死亡區累積時間，身體有一部分在外面就重新算
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or mode == MODE_DAMAGE:
		return
	for player in _players.duplicate():
		if not is_instance_valid(player) or player.is_dead():
			continue
		if not _fully_inside(player):
			_inside_time[player] = 0.0
			continue
		if mode == MODE_TIMED:
			_inside_time[player] = float(_inside_time.get(player, 0.0)) + delta
			if _inside_time[player] < delay:
				continue
		_inside_time[player] = 0.0
		player.kill()
		killed.emit()

# 玩家的碰撞框是不是整個都在範圍裡（框的大小會跟著忽大忽小變）
func _fully_inside(player: Node2D) -> bool:
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or not (col.shape is RectangleShape2D):
		return get_global_rect().has_point(player.global_position)
	var size: Vector2 = (col.shape as RectangleShape2D).size
	var player_rect := Rect2(col.global_position - size / 2.0, size)
	return get_global_rect().encloses(player_rect)

# 範圍在世界座標裡的長方形
func get_global_rect() -> Rect2:
	var size := _get_size()
	return Rect2(global_position - size / 2.0, size)

# 重生時呼叫（重生處理者會叫）：計時歸零
func reset() -> void:
	for player in _inside_time.keys():
		_inside_time[player] = 0.0

# 編輯器裡持續重畫（訊號連線的虛線要跟著更新）
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

# 用不到的欄位不顯示：delay 只在「計時死亡區」、damage 只在「扣血」
func _validate_property(property: Dictionary) -> void:
	if property.name == "delay" and mode != MODE_TIMED:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "damage" and mode != MODE_DAMAGE:
		property.usage = PROPERTY_USAGE_NO_EDITOR

# 編輯器裡畫半透明的紅色範圍框和訊號連線的虛線；遊戲中看不見
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(-_get_size() / 2.0, _get_size())
	draw_rect(rect, _FILL_COLOR)
	draw_rect(rect, _EDGE_COLOR, false, 1.0)
	SignalLines.draw(self, killed)
	SignalLines.draw(self, hurt)
