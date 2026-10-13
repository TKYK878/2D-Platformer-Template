@tool
extends Area2D

# 觸發區：遊戲中看不見的一塊範圍，玩家（或箱子、指定群組）走進去發出 entered、離開發出 exited。
# 拖進關卡、用拉桿調大小，在「節點」面板把 entered／exited 連到別的零件（例如門的 activate、時間軸的 play）。
# 編輯器裡畫成半透明的框，方便擺位置。一條線都沒連時，執行時印中文提醒。

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

## 誰會觸發：只有玩家、玩家與箱子、只有箱子，或只有屬於某個群組的東西（群組在「節點」面板 → 群組加）
@export_enum("只有玩家", "玩家與箱子", "只有箱子", "指定群組") var triggered_by: int = WHO_PLAYER:
	set(value):
		triggered_by = value
		notify_property_list_changed()
		update_configuration_warnings()

## 群組名稱：只有屬於這個群組的玩家／箱子／敵人會觸發。先在那個物體上加群組（「節點」面板 → 群組），
## 再把一樣的名字打在這裡；頭尾空白、全形字會自動整理
@export var tag: String = "":
	set(value):
		tag = value
		update_configuration_warnings()

## 什麼時候觸發：每次進入都觸發，或只有第一次進入（之後進出都不再發出訊號）
@export_enum("每次進入", "只有第一次進入") var trigger_mode: int = MODE_EVERY_TIME:
	set(value):
		trigger_mode = value
		notify_property_list_changed()

## 只有第一次進入時：玩家死掉重生後，可以再觸發一次
@export var reset_on_death: bool = false

## 有東西走進範圍時發出（範圍裡已經有東西時，再進來的不會重複發出）
signal entered
## 範圍裡的東西都離開時發出（「只有第一次進入」觸發過之後就不再發出）
signal exited

const WHO_PLAYER := 0
const WHO_PLAYER_AND_BOX := 1
const WHO_BOX := 2
const WHO_GROUP := 3

const MODE_EVERY_TIME := 0
const MODE_FIRST_TIME := 1

const _TILE_SIZE := 16
const _FILL_COLOR := Color(0.3, 0.8, 1.0, 0.18)
const _EDGE_COLOR := Color(0.3, 0.8, 1.0, 0.8)
# 程式執行時才加上的群組，編輯器裡看不到，檢查群組名稱時要當作存在
const _BUILT_IN_GROUPS := ["player", "box", "enemy"]
const _WARNING_REFRESH_SECONDS := 1.0

var _overlapping: Array[Node] = []
var _used_up := false   # 「只有第一次進入」已經觸發過了
var _tag := ""
var _warning_timer := 0.0

# 建碰撞範圍；遊戲中設定碰撞層、接上進出，等場景都準備好再檢查群組名稱和有沒有連線
func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	add_to_group("signal_source")
	collision_layer = Layers.SENSOR
	collision_mask = Layers.PLAYER | Layers.BOX
	if triggered_by == WHO_GROUP:
		collision_mask |= Layers.ENEMY
		_tag = NameCheck.clean(tag)
		_check_tag.call_deferred()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_warn_if_not_connected.call_deferred()

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

# 判斷這個東西算不算會觸發，依 triggered_by 欄位過濾
func _is_valid(body: Node) -> bool:
	match triggered_by:
		WHO_PLAYER_AND_BOX:
			return body.is_in_group("player") or body.is_in_group("box")
		WHO_BOX:
			return body.is_in_group("box")
		WHO_GROUP:
			return _tag != "" and body.is_in_group(_tag)
		_:
			return body.is_in_group("player")

# 有東西走進來：範圍裡原本沒有東西才發出 entered；「只有第一次進入」發過一次就不再發
func _on_body_entered(body: Node) -> void:
	if not _is_valid(body) or body in _overlapping:
		return
	_overlapping.append(body)
	if _overlapping.size() != 1 or _used_up:
		return
	if trigger_mode == MODE_FIRST_TIME:
		_used_up = true
	entered.emit()

# 東西離開：範圍裡都沒有東西了才發出 exited；「只有第一次進入」觸發過之後不發
func _on_body_exited(body: Node) -> void:
	if not body in _overlapping:
		return
	_overlapping.erase(body)
	if _overlapping.is_empty() and trigger_mode == MODE_EVERY_TIME:
		exited.emit()

# 重生時呼叫（重生處理者會叫）：勾了 reset_on_death 的話，「只有第一次進入」可以再觸發一次
func reset() -> void:
	if reset_on_death:
		_used_up = false

# 編輯器裡持續重畫（訊號連線的虛線要跟著更新），每隔一段時間重新檢查群組名稱
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	queue_redraw()
	_warning_timer += delta
	if _warning_timer >= _WARNING_REFRESH_SECONDS:
		_warning_timer = 0.0
		update_configuration_warnings()

# 用不到的欄位不顯示：「指定群組」以外的 tag、「每次進入」時的 reset_on_death
func _validate_property(property: Dictionary) -> void:
	if property.name == "tag" and triggered_by != WHO_GROUP:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "reset_on_death" and trigger_mode != MODE_FIRST_TIME:
		property.usage = PROPERTY_USAGE_NO_EDITOR

# 編輯器裡畫半透明的範圍框和訊號連線的虛線；遊戲中看不見
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(-_get_size() / 2.0, _get_size())
	draw_rect(rect, _FILL_COLOR)
	draw_rect(rect, _EDGE_COLOR, false, 1.0)
	SignalLines.draw(self, entered)
	SignalLines.draw(self, exited)

# 編輯器場景樹的黃色驚嘆號：選了「指定群組」但群組名稱空白，或場景裡沒有東西屬於這個群組
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if triggered_by != WHO_GROUP or not is_inside_tree():
		return warnings
	var clean_tag := NameCheck.clean(tag)
	if clean_tag == "":
		warnings.append("「誰會觸發」選了「指定群組」，但 tag 是空的，請打上群組名稱。")
		return warnings
	var root := get_tree().edited_scene_root
	if root == null:
		return warnings
	var groups := _collect_body_groups(root)
	for g in _BUILT_IN_GROUPS:
		if g not in groups:
			groups.append(g)
	if clean_tag not in groups:
		warnings.append(_missing_tag_message(clean_tag, groups))
	return warnings

# 執行時檢查群組名稱：場景裡沒有東西屬於這個群組就印中文警告，不然永遠不會觸發卻沒有任何提示
func _check_tag() -> void:
	if _tag == "":
		var empty_message := "[觸發區] %s：「誰會觸發」選了「指定群組」，但 tag 是空的，誰走進來都不會觸發。" % name
		push_warning(empty_message)
		print(empty_message)
		return
	var groups: Array = []
	var root := get_tree().current_scene
	if root != null:
		groups = _collect_body_groups(root)
	if _tag in groups:
		return
	var message := "[觸發區] %s：%s" % [name, _missing_tag_message(_tag, groups)]
	push_warning(message)
	print(message)

# 兩個訊號都沒連到任何東西時提醒學員，不然走進去沒反應會以為壞掉
func _warn_if_not_connected() -> void:
	if not entered.get_connections().is_empty() or not exited.get_connections().is_empty():
		return
	push_warning("[觸發區] %s 的 entered／exited 沒有連到任何東西，走進去不會有反應" % name)
	printerr("⚠ [觸發區] %s 還沒連線：選它 → 右邊「節點」面板 → 雙擊 entered（或 exited）→ 選要控制的零件和函式" % name)

# 找出場景裡所有會動的物體（玩家、箱子、敵人…）身上的群組名稱，列給學員對照
func _collect_body_groups(root: Node) -> Array:
	var groups: Array = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is PhysicsBody2D:
			for g in node.get_groups():
				var text := str(g)
				if not text.begins_with("_") and text != "signal_source" and text not in groups:
					groups.append(text)
		stack.append_array(node.get_children())
	return groups

# 組出「找不到群組」的中文說明，附上現有群組跟近似名稱建議
func _missing_tag_message(clean_tag: String, groups: Array) -> String:
	var message := "找不到屬於群組「%s」的玩家／箱子／敵人。現有的群組：%s。" % [clean_tag, NameCheck.list_text(groups)]
	var similar := NameCheck.find_similar(clean_tag, groups)
	if similar != "":
		message += "是不是想打「%s」？" % similar
	else:
		message += "記得群組要加在物體本身（例如箱子），不是加在它底下的圖片。"
	return message
