@tool
extends Area2D

# 按鈕：踩到（或被攻擊）時發出 turned_on / turned_off，行為依「觸發方式」決定。
# 拖進場景就能用，不用連任何線；要讓它控制別的零件，在「節點」面板把這兩個訊號連過去即可
# （見 documents/01a_shared_systems.md §6，這是零連線鐵律在零件之間唯一的例外）。

## 觸發方式：踩住的時候算開著、踩一下就切換開關、踩一下之後永久開著（不會再關）、被攻擊時觸發
@export_enum("踩住才開", "踩一下切換", "踩一下永久開", "被攻擊觸發") var mode: int = 0

## 誰踩得動：玩家跟箱子都算、只有玩家、只有箱子，或只有屬於某個群組的東西（群組在「節點」面板 → 群組加）
@export_enum("玩家與箱子", "只有玩家", "只有箱子", "指定群組") var pressed_by: int = 0:
	set(value):
		pressed_by = value
		notify_property_list_changed()
		update_configuration_warnings()

## 群組名稱：只有屬於這個群組的玩家／箱子／敵人踩得動。先在要踩按鈕的物體上加群組（「節點」面板 → 群組），
## 再把一樣的名字打在這裡；頭尾空白、全形字會自動整理
@export var tag: String = "":
	set(value):
		tag = value
		update_configuration_warnings()

## 玩家死掉重生時，這顆按鈕要不要回到關著的狀態（開著的話會發出 turned_off，連著的門、平台、敵人射擊也會跟著關）；
## 不勾的話維持死掉前的樣子
@export var reset_on_death: bool = false

## 開啟時發出，依「觸發方式」決定時機
signal turned_on
## 關閉時發出（踩一下永久開模式不會用到這個）
signal turned_off

const _MODE_HOLD := 0
const _MODE_TOGGLE := 1
const _MODE_PERMANENT := 2
const _MODE_HIT := 3

const _WHO_PLAYER_ONLY := 1
const _WHO_BOX_ONLY := 2
const _WHO_GROUP := 3

# 程式執行時才加上的群組，編輯器裡看不到，檢查群組名稱時要當作存在
const _BUILT_IN_GROUPS := ["player", "box", "enemy"]
# 編輯器裡每隔幾秒重新檢查一次群組名稱，學員在別的物體加了群組之後黃色警告會跟著消失
const _WARNING_REFRESH_SECONDS := 1.0

var _overlapping: Array[Node] = []
var _is_on: bool = false
var _permanently_triggered: bool = false
var _tag: String = ""
var _warning_timer: float = 0.0
var _skin: SkinLink = null

# 設定碰撞層／遮罩，並依模式決定要不要監聽踩踏；底下有皮就換上皮。
# 預設重生時維持原狀（開關狀態連著別的零件，維持原狀才不會卡關），勾了 reset_on_death 才會 reset()。
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("signal_source")
	_skin = SkinLink.new(self, $Visual)
	collision_layer = Layers.SENSOR
	collision_mask = Layers.PLAYER | Layers.BOX
	if pressed_by == _WHO_GROUP and mode != _MODE_HIT:
		collision_mask |= Layers.ENEMY  # 指定群組時敵人也可能踩得動
		_tag = NameCheck.clean(tag)
		_check_tag.call_deferred()
	if mode != _MODE_HIT:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	_update_visual()

# 判斷這個 body 算不算「踩得動」，依 pressed_by 欄位過濾
func _is_valid(body: Node) -> bool:
	match pressed_by:
		_WHO_PLAYER_ONLY:
			return body.is_in_group("player")
		_WHO_BOX_ONLY:
			return body.is_in_group("box")
		_WHO_GROUP:
			return _tag != "" and body.is_in_group(_tag)
		_:
			return body.is_in_group("player") or body.is_in_group("box")

# 有東西踩上來：依模式決定要不要 emit turned_on
func _on_body_entered(body: Node) -> void:
	if not _is_valid(body):
		return
	_overlapping.append(body)
	if _overlapping.size() != 1:
		return
	match mode:
		_MODE_HOLD:
			turned_on.emit()
		_MODE_TOGGLE:
			_toggle()
		_MODE_PERMANENT:
			if not _permanently_triggered:
				_permanently_triggered = true
				turned_on.emit()
	_update_visual()

# 東西離開：踩住才開模式在完全沒人踩的時候才 emit turned_off
func _on_body_exited(body: Node) -> void:
	_overlapping.erase(body)
	if mode == _MODE_HOLD and _overlapping.is_empty():
		turned_off.emit()
	_update_visual()

# 被攻擊打到，被攻擊觸發模式下每打一次切換開關
func take_hit(_damage: int, _knockback: Vector2, source: Node) -> void:
	Events.hit.emit(self, source)
	if mode != _MODE_HIT:
		return
	_toggle()
	_update_visual()

# 重生時回到關著的狀態（重生處理者呼叫，reset_on_death 有勾才做）；原本開著就發出 turned_off，
# 連著的零件跟著關掉，兩邊才不會對不上
func reset() -> void:
	if not reset_on_death:
		return
	var was_on := _is_on or _permanently_triggered
	_is_on = false
	_permanently_triggered = false
	if was_on:
		turned_off.emit()
	_update_visual()

# 切換開關狀態並 emit 對應訊號
func _toggle() -> void:
	_is_on = not _is_on
	if _is_on:
		turned_on.emit()
	else:
		turned_off.emit()

# 依目前開關狀態換顏色（有皮就換皮的樣子），讓學員看得出按鈕有沒有生效
func _update_visual() -> void:
	if _skin == null:
		return
	var is_lit := _permanently_triggered or _is_on or (mode == _MODE_HOLD and not _overlapping.is_empty())
	_skin.show_state(is_lit, Color(0.3, 0.85, 0.35) if is_lit else Color(0.55, 0.55, 0.55))

# 編輯畫面持續請求重畫，讓虛線跟著訊號連接的變化即時更新；每隔一段時間重新檢查群組名稱
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	queue_redraw()
	_warning_timer += delta
	if _warning_timer >= _WARNING_REFRESH_SECONDS:
		_warning_timer = 0.0
		update_configuration_warnings()

# 「指定群組」以外的模式不顯示 tag 欄位，學員沒選到就看不到
func _validate_property(property: Dictionary) -> void:
	if property.name == "tag" and pressed_by != _WHO_GROUP:
		property.usage = PROPERTY_USAGE_NONE

# 編輯器場景樹的黃色驚嘆號：群組名稱空白，或場景裡沒有任何玩家／箱子／敵人屬於這個群組（被攻擊觸發模式不看這個）
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if pressed_by != _WHO_GROUP or mode == _MODE_HIT or not is_inside_tree():
		return warnings
	var clean_tag := NameCheck.clean(tag)
	if clean_tag == "":
		warnings.append("「誰踩得動」選了「指定群組」，但 tag 是空的，請打上群組名稱。")
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

# 執行時檢查：場景裡沒有任何東西屬於這個群組就印中文警告，不然按鈕會永遠踩不動卻沒有任何提示
func _check_tag() -> void:
	if _tag == "":
		var empty_message := "[按鈕] %s：「誰踩得動」選了「指定群組」，但 tag 是空的，這個按鈕誰都踩不動。" % name
		push_warning(empty_message)
		print(empty_message)
		return
	var groups: Array = []
	var root := get_tree().current_scene
	if root != null:
		groups = _collect_body_groups(root)
	if _tag in groups:
		return
	var message := "[按鈕] %s：%s" % [name, _missing_tag_message(_tag, groups)]
	push_warning(message)
	print(message)

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

# 編輯畫面用：幫這個零件自己發出的每個訊號的每條連接畫一條虛線到目標節點
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	SignalLines.draw(self, turned_on)
	SignalLines.draw(self, turned_off)
