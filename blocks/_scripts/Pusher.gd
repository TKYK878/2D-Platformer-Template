@tool
extends Node2D

# 推力器：被訊號叫到 activate 時，把玩家（或範圍內的箱子、敵人）往指定方向推一下。
# 例：道具的 collected → 推力器的 activate，撿到就往左飛。編輯器裡畫箭頭，看得出往哪推、多用力。

## 要推誰：玩家（不管在哪裡都推），或範圍內的東西（範圍在場景裡畫成方框）
@export_enum("玩家", "範圍內全部", "範圍內的玩家", "範圍內的箱子", "範圍內的敵人") var target: int = 0:
	set(value):
		target = value
		_refresh()
## 範圍寬度，單位是格（1 格 = 16 像素），以推力器為中心
@export_range(1, 30) var range_width: int = 4:
	set(value):
		range_width = value
		_refresh()
## 範圍高度，單位是格（1 格 = 16 像素），以推力器為中心
@export_range(1, 30) var range_height: int = 4:
	set(value):
		range_height = value
		_refresh()
## 往哪個方向推；選「自訂」可以用 custom_x、custom_y 調任意方向
@export_enum("上", "下", "左", "右", "左上", "右上", "左下", "右下", "自訂") var direction: int = 2:
	set(value):
		direction = value
		_refresh()
## 自訂方向的左右：-1 是往左、1 是往右、0 是不左不右
@export_range(-1.0, 1.0) var custom_x: float = -1.0:
	set(value):
		custom_x = value
		_refresh()
## 自訂方向的上下：-1 是往上、1 是往下、0 是不上不下
@export_range(-1.0, 1.0) var custom_y: float = -0.5:
	set(value):
		custom_y = value
		_refresh()
## 推多用力（推出去的速度）
@export_range(50.0, 1500.0) var strength: float = 500.0:
	set(value):
		strength = value
		queue_redraw()
## 怎麼推：疊加＝在原本的速度上再加一股力（往反方向衝的話會被抵銷一些）；先停住再推＝不管原本怎麼動，每次都推出一樣的結果
@export_enum("疊加在原本的速度上", "先停住再推") var push_mode: int = 0
## 玩家重力翻轉時：跟著翻轉＝「上」變成玩家頭頂的方向；不翻轉＝永遠是畫面的方向（只影響玩家）
@export_enum("跟著翻轉", "不翻轉") var on_gravity_flip: int = 0

## 推了東西時發出，帶被推的物件，給學員自己接特效／音效用
signal pushed(body: Node)

const _TILE_SIZE := 16.0
const _TARGET_PLAYER := 0
const _TARGET_ALL := 1
const _TARGET_RANGE_PLAYER := 2
const _TARGET_RANGE_BOX := 3
const _TARGET_RANGE_ENEMY := 4
const _CUSTOM := 8
const _MODE_SET := 1
const _FLIP_FOLLOW := 0
const _DIRECTIONS := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
	Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
const _COLOR := Color(1.0, 0.55, 0.2, 0.9)
# 箭頭長度：力道 500 時畫 32 像素
const _ARROW_SCALE := 32.0 / 500.0

var _area: Area2D = null
var _shape: CollisionShape2D = null

# 推一下：照 target 找出要推的東西，往設定的方向推（訊號帶的參數會被忽略，任何訊號都能連）
func activate(..._args: Array) -> void:
	if Engine.is_editor_hint():
		return
	var dir := _base_direction()
	if dir == Vector2.ZERO:
		_warn("自訂方向的 custom_x、custom_y 都是 0，不知道要往哪推")
		return
	var bodies := _find_targets()
	if bodies.is_empty() and target == _TARGET_PLAYER:
		_warn("場景裡找不到玩家，沒東西可以推")
	for body in bodies:
		_push(body, dir)

# 建立範圍偵測區、加入訊號群組；編輯器裡只負責畫
func _ready() -> void:
	_area = Area2D.new()
	_area.monitorable = false
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_area.add_child(_shape)
	add_child(_area)
	_refresh()
	if Engine.is_editor_hint():
		set_process(true)
		return
	set_process(false)
	add_to_group("signal_source")
	_area.collision_layer = 0
	_area.collision_mask = Layers.PLAYER | Layers.BOX | Layers.ENEMY
	if _base_direction() == Vector2.ZERO:
		_warn("自訂方向的 custom_x、custom_y 都是 0，不知道要往哪推，請至少把一個拉離 0")

# 回傳設定的方向（還沒套用重力翻轉），長度是 1；自訂兩個都是 0 時回傳 0
func _base_direction() -> Vector2:
	if direction == _CUSTOM:
		return Vector2(custom_x, custom_y).normalized()
	return (_DIRECTIONS[direction] as Vector2).normalized()

# 依 target 列出這一次要推的東西
func _find_targets() -> Array:
	if target == _TARGET_PLAYER:
		var player := get_tree().get_first_node_in_group("player")
		return [player] if player != null else []
	var result := []
	for body in _area.get_overlapping_bodies():
		match target:
			_TARGET_RANGE_PLAYER:
				if body.is_in_group("player"): result.append(body)
			_TARGET_RANGE_BOX:
				if body is RigidBody2D: result.append(body)
			_TARGET_RANGE_ENEMY:
				if body is CharacterBody2D and not body.is_in_group("player"): result.append(body)
			_:
				result.append(body)
	return result

# 推一個東西：玩家和敵人用 add_impulse，箱子這類物理物件改它的速度；推不動的（固定住的殼）跳過
func _push(body: Node, dir: Vector2) -> void:
	if body.is_in_group("player") and on_gravity_flip == _FLIP_FOLLOW and body.get("up_direction") == Vector2.DOWN:
		dir.y = -dir.y
	var wanted := dir * strength
	if body is RigidBody2D:
		var rigid := body as RigidBody2D
		if rigid.freeze:
			return
		rigid.linear_velocity = wanted if push_mode == _MODE_SET else rigid.linear_velocity + wanted
	elif body.has_method("add_impulse"):
		var current: Vector2 = body.velocity if push_mode == _MODE_SET else Vector2.ZERO
		body.add_impulse(wanted - current)
	else:
		return
	pushed.emit(body)

# 欄位改了之後：更新範圍大小、Inspector 顯示的欄位、編輯器的圖、黃色驚嘆號
func _refresh() -> void:
	if _shape != null:
		(_shape.shape as RectangleShape2D).size = Vector2(range_width, range_height) * _TILE_SIZE
	notify_property_list_changed()
	update_configuration_warnings()
	queue_redraw()

# 只顯示用得到的欄位：推範圍內的東西才有範圍大小；自訂方向才有 custom_x、custom_y
func _validate_property(property: Dictionary) -> void:
	var should_hide := false
	match property.name:
		"range_width", "range_height": should_hide = target == _TARGET_PLAYER
		"custom_x", "custom_y": should_hide = direction != _CUSTOM
	if should_hide:
		property.usage &= ~PROPERTY_USAGE_EDITOR

# 編輯器裡就看得到設定錯誤：自訂方向兩個都是 0
func _get_configuration_warnings() -> PackedStringArray:
	if direction == _CUSTOM and is_zero_approx(custom_x) and is_zero_approx(custom_y):
		return PackedStringArray(["自訂方向的 custom_x、custom_y 都是 0，不知道要往哪推"])
	return PackedStringArray()

# 編輯畫面持續請求重畫，讓虛線跟著訊號連接的變化即時更新
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

# 編輯畫面用：畫圓點、方向箭頭（越長越用力）、推範圍內的東西時畫範圍方框，再畫訊號連接的虛線
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 5.0, _COLOR)
	var dir := _base_direction()
	if dir != Vector2.ZERO:
		var tip := dir * maxf(strength * _ARROW_SCALE, 12.0)
		draw_line(Vector2.ZERO, tip, _COLOR, 2.0)
		draw_line(tip, tip - dir.rotated(0.5) * 6.0, _COLOR, 2.0)
		draw_line(tip, tip - dir.rotated(-0.5) * 6.0, _COLOR, 2.0)
	if target != _TARGET_PLAYER:
		var size := Vector2(range_width, range_height) * _TILE_SIZE
		draw_rect(Rect2(-size * 0.5, size), Color(_COLOR, 0.12))
		draw_rect(Rect2(-size * 0.5, size), _COLOR, false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(8, -6), "推力器", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _COLOR)
	SignalLines.draw(self, pushed)

# 印出中文警告：push_warning 給偵錯器，printerr 讓輸出面板看得見
func _warn(message: String) -> void:
	push_warning("[推力器] %s：%s" % [name, message])
	printerr("⚠ [推力器] %s：%s" % [name, message])
