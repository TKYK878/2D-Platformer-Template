@tool
extends MechanicBase

# 脫殼：縮小（或按下按鍵）時在原地留下一顆殼，玩家依方向鍵往某個方向脫出去。備品庫卡，不在抽卡池裡。
# 殼的種類＝卡片底下的殼（Shell）子節點，脫殼時複製一份放進關卡；底下沒有殼就用內建的殼。
# 按 Q／E 切換要脫哪種殼；數量上限、可脫次數照每種殼自己的設定。
# 「縮小時」聽忽大忽小卡的廣播，不用連線；拖進 Player → Mechanics 底下就能用。

## 什麼時候脫殼：跟著忽大忽小卡縮小的那一刻，或是自己按一個按鍵
@export_enum("縮小時", "按下按鍵") var trigger_timing: int = 0:
	set(value):
		trigger_timing = value
		notify_property_list_changed()
		update_configuration_warnings()

## 按下按鍵時用鍵盤按鍵還是滑鼠按鍵（只有「觸發時機」選按下按鍵時才會顯示這一欄）
@export_enum("鍵盤按鍵", "滑鼠左鍵", "滑鼠右鍵", "滑鼠中鍵") var input_type: int = 0:
	set(value):
		input_type = value
		notify_property_list_changed()

## 按哪一鍵脫殼（「觸發時機」選按下按鍵、「按鍵種類」選鍵盤按鍵時才會顯示這一欄）
@export var key: Key = KEY_C

## 同時按著好幾個方向鍵時，先看哪個方向；沒按方向鍵就往排第一的方向（排第一的是左右的話，往面向的方向；「start_inside」不勾時改看預設方向）
@export_enum("上 > 左右 > 下", "左右 > 上 > 下", "下 > 左右 > 上", "左右 > 下 > 上") var direction_order: int = 0

## 脫出去的力道，0 表示不彈出去、留在原地
@export_range(0.0, 800.0) var strength: float = 300.0

## 脫殼的那一刻玩家窩在殼裡面，再慢慢鑽出來；不勾的話直接擠到殼外面（脫出方向被牆或地板擋住時，還是會窩在殼裡）
@export var start_inside: bool = true:
	set(value):
		start_inside = value
		notify_property_list_changed()

## 擠到殼外面時，什麼方向鍵都沒按的話往哪邊脫出（「start_inside」不勾時才會顯示這一欄）
@export_enum("上", "面向的方向", "背對的方向", "下") var default_direction: int = 0

@export_group("切換殼")

## 切換到上一種殼的按鍵（直接指定按鍵）
@export var prev_key: Key = KEY_Q
## 切換到下一種殼的按鍵（直接指定按鍵）
@export var next_key: Key = KEY_E
## 上一首/上一種殼的 Input Map 動作名稱

@export var prev_action_name: StringName = &"prev_shell"
## 下一首/下一種殼的 Input Map 動作名稱
@export var next_action_name: StringName = &"next_shell"

## 目前選中哪種殼要怎麼顯示在畫面上
@export_enum("玩家頭上", "畫面右上角", "兩個都要", "不顯示") var show_selected: int = 0

@export_group("玩家死掉時")
## 玩家死掉時，已經脫下來的殼怎麼處理（清掉時，可以脫的次數也一起恢復）
@export_enum("重生時清掉", "死掉時馬上清掉", "保留") var on_death: int = 0

## 脫出一顆殼之後發出
signal shell_created
## 用切換鍵換了一種殼之後發出
signal shell_changed
## 想脫殼但脫不了（這種殼的次數用完了，或數量滿了又設定成不能再脫）時發出，可以接「無效」提示
signal molt_blocked

const _TRIGGER_SHRINK := 0
const _TRIGGER_KEY := 1
const _UP := "上"
const _SIDE := "左右"
const _DOWN := "下"
const _DEFAULT_UP := 0
const _DEFAULT_FACING := 1
const _DEFAULT_BEHIND := 2
const _DEFAULT_DOWN := 3
const _ORDERS := [
	[_UP, _SIDE, _DOWN],
	[_SIDE, _UP, _DOWN],
	[_DOWN, _SIDE, _UP],
	[_SIDE, _DOWN, _UP],
]
# 卡片底下沒有放殼時用的內建殼：蟬殼（什麼都不加）、塑膠殼（彈彈的）、蜘蛛殼（不受重力、推不動）
const _BUILT_IN_SHELLS := [
	"res://mechanics/_extra/_molt/Shell_Cicada.tscn",
	"res://mechanics/_extra/_molt/Shell_Plastic.tscn",
	"res://mechanics/_extra/_molt/Shell_Spider.tscn",
]
const _SIZE_SHIFT_CARD := "Mechanic_SizeShift"
const _SHOW_HEAD := 0
const _SHOW_CORNER := 1
const _SHOW_BOTH := 2
const _CLEAR_ON_RESPAWN := 0
const _CLEAR_ON_DEATH := 1
# 殼設定裡「數量上限怎麼算」「滿了怎麼辦」的選項
const _SCOPE_ROOM := 0
const _FULL_BLOCK := 1
# 頭上小方塊的大小、離頭頂多遠
const _HEAD_ICON_SIZE := 8.0
const _HEAD_ICON_GAP := 10.0
# 往左右脫出時暫時鎖住方向鍵，不然按著方向鍵會馬上把彈出去的速度蓋掉
const _SIDE_LOCK_DURATION := 0.2
# 擠到殼外面時，玩家跟殼之間留一點空隙（殼頂端還有一片薄平台，要站在它上面）
const _OUTSIDE_GAP := 3.0
# 檢查殼外面有沒有空間時，形狀每邊縮一點，避免剛好貼著地板也被當成擋住
const _OVERLAP_MARGIN := 1.0
# 編輯器裡每隔幾秒重新檢查一次，學員加減忽大忽小卡之後黃色警告會跟著更新
const _WARNING_REFRESH_SECONDS := 1.0

var _templates: Array[Shell] = []
var _collected: bool = false
var _selected: int = 0
var _facing: int = 1
var _up_held: bool = false
var _down_held: bool = false
var _pending: bool = false
var _pending_position: Vector2 = Vector2.ZERO
var _pending_size: Vector2 = Vector2.ZERO
var _last_position: Vector2 = Vector2.ZERO
var _last_size: Vector2 = Vector2.ZERO
var _side_lock_left: float = 0.0
var _warning_timer: float = 0.0
# 場景裡還在的殼（照脫出的順序，最舊的在前面），以及每顆殼是哪種、在哪個房間脫的
var _shells: Array[Shell] = []
var _shell_template: Dictionary = {}   # Shell -> 模板編號
var _shell_room: Dictionary = {}       # Shell -> 房間（沒有房間的關卡是 null）
var _uses: Dictionary = {}             # 模板編號 -> 已經脫了幾次
var _head_icon: Node2D = null
var _head_label: Label = null
var _corner_icon: ColorRect = null
var _corner_label: Label = null

# 只在「觸發時機」選按下按鍵時顯示按鍵欄位；選滑鼠按鍵時也隱藏 key 欄位；窩在殼裡時隱藏預設方向
func _validate_property(property: Dictionary) -> void:
	if property.name == "input_type" and trigger_timing != _TRIGGER_KEY:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "key" and (trigger_timing != _TRIGGER_KEY or input_type != 0):
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "default_direction" and start_inside:
		property.usage = PROPERTY_USAGE_NONE

# 一進場景就把底下的殼收起來當模板（趁它們還沒啟動），不然它們會變成黏在玩家身上的真的殼
func _enter_tree() -> void:
	if Engine.is_editor_hint() or _collected:
		return
	_collected = true
	for child in get_children():
		if child is Shell:
			remove_child(child)
			_templates.append(child)
		else:
			push_warning("[脫殼] 卡片底下的「%s」不是殼（Shell），脫殼時不會用到" % child.name)
			printerr("⚠ [脫殼] 卡片底下只能放殼（Shell），請把「%s」拖出去" % child.name)
	if _templates.is_empty():
		for path in _BUILT_IN_SHELLS:
			_templates.append(load(path).instantiate())

# 編輯器裡不做執行時的檢查
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(false)
	super._ready()

# 卡片被刪掉時，一起刪掉收起來的殼模板
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for t in _templates:
			if is_instance_valid(t):
				t.free()
	elif what == NOTIFICATION_CHILD_ORDER_CHANGED and Engine.is_editor_hint():
		update_configuration_warnings()

# 依觸發時機接忽大忽小卡的廣播或按鍵，記住角色面向，聽上下方向鍵
func _on_setup() -> void:
	if trigger_timing == _TRIGGER_SHRINK:
		Events.mechanic_event.connect(_on_mechanic_event)
		_check_size_shift.call_deferred()
	else:
		if input_type == 0:
			InputRouter.warn_if_dangerous_key(key, "[脫殼]")
		InputRouter.bind_input(self, input_type, key, InputRouter.PRESSED, _on_key_pressed)
	
	InputRouter.warn_if_dangerous_key(prev_key, "[脫殼]")
	InputRouter.warn_if_dangerous_key(next_key, "[脫殼]")
	InputRouter.bind_key(self, prev_key, InputRouter.PRESSED, func(): return _switch(-1))
	InputRouter.bind_key(self, next_key, InputRouter.PRESSED, func(): return _switch(1))

	if on_death == _CLEAR_ON_DEATH:
		Events.player_died.connect(clear_shells)
	_make_display()
	InputRouter.bind(self, "move_up", InputRouter.HELD, func(_t: float): _up_held = true)
	InputRouter.bind(self, "move_down", InputRouter.HELD, func(_t: float): _down_held = true)
	player.direction_changed.connect(func(dir: int): _facing = dir)
	_remember_body()

# 處理這一幀要不要脫殼，並記住玩家現在的位置和大小（縮小之後還要知道縮小前多大）
func apply(ctx: MoveContext) -> void:
	if Input.is_action_just_pressed(prev_action_name):
		_switch(-1)
	if Input.is_action_just_pressed(next_action_name):
		_switch(1)
	if _side_lock_left > 0.0:
		_side_lock_left -= ctx.delta
		ctx.input_locked = true
	if _pending:
		_pending = false
		_molt()
	_up_held = false
	_down_held = false
	_remember_body()
	_update_head_icon()

# 重生時取消還沒處理的脫殼、解除方向鎖；死亡處理選「重生時清掉」就把殼清掉
func on_respawn() -> void:
	_pending = false
	_side_lock_left = 0.0
	_remember_body()
	if on_death == _CLEAR_ON_RESPAWN:
		clear_shells()

# 把脫下來的殼全部碎掉，可以脫的次數也全部恢復；可以接其他零件的訊號來呼叫（例如按鈕被踩下）
func clear_shells() -> void:
	for shell in _shells.duplicate():
		if is_instance_valid(shell):
			shell.break_shell()
	_shells.clear()
	_shell_template.clear()
	_shell_room.clear()
	_uses.clear()
	_refresh_display()

# 忽大忽小卡縮小的那一刻：用縮小前的大小準備脫殼
func _on_mechanic_event(card: String, event: String) -> void:
	if not enabled or player == null or player.is_dead():
		return
	if card == _SIZE_SHIFT_CARD and event == "shrank":
		_request_molt(_last_position, _last_size)

# 按下脫殼鍵：用現在的大小準備脫殼
func _on_key_pressed() -> bool:
	if player.is_dead():
		return false
	_remember_body()
	_request_molt(_last_position, _last_size)
	return true

# 記下要脫殼，等這一幀的 apply() 再一起處理（那時才知道這一幀按著哪些方向鍵）
func _request_molt(at_position: Vector2, size: Vector2) -> void:
	_pending = true
	_pending_position = at_position
	_pending_size = size

# 在記下的位置放一顆目前選中的殼，再把玩家往方向鍵的方向彈出去
func _molt() -> void:
	if _templates.is_empty():
		return
	var index := clampi(_selected, 0, _templates.size() - 1)
	var template := _templates[index]
	var room := _room_at(_pending_position)
	if not _make_room_for(index, template, room):
		molt_blocked.emit()
		Events.mechanic_event.emit("Extra_Molt", "molt_blocked")
		return
	var shell := template.duplicate() as Shell
	shell.name = template.name
	var dir := _pick_direction()
	# 殼還沒放進場景前先找殼外面的位置，才不會被剛生出來的殼擋到
	var outside: Variant = null if start_inside else _find_outside_position(dir)
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	shell.position = (parent as Node2D).to_local(_pending_position) if parent is Node2D else _pending_position
	parent.add_child(shell, true)
	shell.set_body_size(_pending_size)
	# 擠到殼外面的話，玩家是瞬間移過去的，物理引擎這一步還會以為玩家穿過殼、把殼推開，所以也先不互撞
	shell.ignore_until_apart(player)
	if outside != null:
		player.global_position += (outside as Vector2) - _body_center()
	_shells.append(shell)
	_shell_template[shell] = index
	_shell_room[shell] = room
	shell.tree_exited.connect(_forget_shell.bind(shell))
	_uses[index] = int(_uses.get(index, 0)) + 1
	_refresh_display()
	# 會推玩家的訊號在推之前發出（跟其他卡一樣，連到 stop_motion 是「先停住再推」）
	shell_created.emit()
	Events.mechanic_event.emit("Extra_Molt", "shell_created")
	_push_player(dir)

# 依殼的設定檢查能不能再脫一顆：次數用完、或數量滿了又不能再脫就回傳 false；
# 數量滿了要碎掉最舊的，就在這裡碎掉
func _make_room_for(index: int, template: Shell, room: Node) -> bool:
	if template.max_uses > 0 and int(_uses.get(index, 0)) >= template.max_uses:
		print("[脫殼] 「%s」可以脫的次數用完了" % template.name)
		return false
	var same: Array[Shell] = []
	for shell in _shells:
		if not is_instance_valid(shell) or shell.is_broken() or _shell_template.get(shell, -1) != index:
			continue
		if template.count_scope == _SCOPE_ROOM and _shell_room.get(shell) != room:
			continue
		same.append(shell)
	if same.size() < template.max_count:
		return true
	if template.when_full == _FULL_BLOCK:
		print("[脫殼] 「%s」的數量滿了（最多 %d 顆），不能再脫" % [template.name, template.max_count])
		return false
	for i in same.size() - template.max_count + 1:
		_forget_shell(same[i])
		same[i].break_shell()
	return true

# 殼離開場景（碎掉、被刪掉）時不再記它
func _forget_shell(shell: Shell) -> void:
	_shells.erase(shell)
	_shell_template.erase(shell)
	_shell_room.erase(shell)

# 找某個位置在哪個房間裡，沒有房間的關卡回傳 null（整個關卡當成同一個房間）
func _room_at(global_point: Vector2) -> Node:
	for room in get_tree().get_nodes_in_group("room"):
		if room.has_method("has_point") and room.has_point(global_point):
			return room
	return null

# 切換到上一種（-1）或下一種（1）殼；只有一種殼時不用切換
func _switch(step: int) -> bool:
	if not enabled or player == null or player.is_dead() or _templates.size() <= 1:
		return false
	_selected = posmod(_selected + step, _templates.size())
	_refresh_display()
	shell_changed.emit()
	Events.mechanic_event.emit("Extra_Molt", "shell_changed")
	return true

# 依「顯示方式」建立頭上小方塊和畫面右上角那一列（學員不用擺任何 UI 節點）
func _make_display() -> void:
	if show_selected == _SHOW_HEAD or show_selected == _SHOW_BOTH:
		_head_icon = Node2D.new()
		_head_icon.name = "SelectedShellIcon"
		_head_icon.top_level = true
		_head_icon.draw.connect(_draw_head_icon)
		add_child(_head_icon)
		_head_label = Label.new()
		_head_label.add_theme_font_size_override("font_size", 12)
		_head_label.position = Vector2(_HEAD_ICON_SIZE / 2.0 + 2.0, -9.0)
		_head_icon.add_child(_head_label)
	if show_selected == _SHOW_CORNER or show_selected == _SHOW_BOTH:
		var layer := CanvasLayer.new()
		layer.name = "SelectedShellHud"
		add_child(layer)
		var row := HBoxContainer.new()
		row.anchor_left = 1.0
		row.anchor_right = 1.0
		row.offset_left = -240.0
		row.offset_right = -4.0
		row.offset_top = 4.0
		row.alignment = BoxContainer.ALIGNMENT_END
		layer.add_child(row)
		_corner_icon = ColorRect.new()
		_corner_icon.custom_minimum_size = Vector2(10, 10)
		_corner_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_corner_icon)
		_corner_label = Label.new()
		row.add_child(_corner_label)
	_refresh_display()

# 把頭上小方塊和右上角那一列更新成目前選中的殼、剩下的次數
func _refresh_display() -> void:
	if _templates.is_empty():
		return
	var template := _templates[clampi(_selected, 0, _templates.size() - 1)]
	var left_text := _uses_left_text(template)
	if _head_icon != null:
		# 只有一種殼又不限次數時，頭上不用顯示
		_head_icon.visible = _templates.size() > 1 or template.max_uses > 0
		_head_label.text = left_text
		_head_icon.queue_redraw()
	if _corner_label != null:
		_corner_icon.color = template.get_color()
		_corner_label.text = "殼：%s" % template.name
		if left_text != "":
			_corner_label.text += "（剩 %s 次）" % left_text

# 這種殼還能脫幾次，不限次數回傳空字串
func _uses_left_text(template: Shell) -> String:
	if template.max_uses <= 0:
		return ""
	var index := _templates.find(template)
	return str(maxi(template.max_uses - int(_uses.get(index, 0)), 0))

# 每幀把頭上小方塊擺到玩家頭頂（重力翻轉時也是頭頂那一邊）
func _update_head_icon() -> void:
	if _head_icon == null:
		return
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var half_height: float = 16.0
	var center: Vector2 = player.global_position
	if col != null and col.shape is RectangleShape2D:
		half_height = (col.shape as RectangleShape2D).size.y / 2.0
		center = col.global_position
	_head_icon.global_position = center + player.up_direction * (half_height + _HEAD_ICON_GAP)

# 畫頭上的小方塊（目前選中那種殼的顏色）
func _draw_head_icon() -> void:
	if _templates.is_empty():
		return
	var template := _templates[clampi(_selected, 0, _templates.size() - 1)]
	var c: Color = template.get_color()
	var rect := Rect2(-Vector2.ONE * _HEAD_ICON_SIZE / 2.0, Vector2.ONE * _HEAD_ICON_SIZE)
	_head_icon.draw_rect(rect, c)
	_head_icon.draw_rect(rect, c.darkened(0.4), false, 1.0)

# 找玩家擠到殼外面（往脫出方向、緊貼著殼）的碰撞形狀中心位置；那裡被地形擋住就回傳 null
func _find_outside_position(dir: Vector2) -> Variant:
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or not (col.shape is RectangleShape2D):
		return null
	var body_size: Vector2 = (col.shape as RectangleShape2D).size
	var target: Vector2 = col.global_position
	if dir.x != 0.0:
		target.x = _pending_position.x + dir.x * (_pending_size.x / 2.0 + body_size.x / 2.0 + _OUTSIDE_GAP)
	else:
		var along: Vector2 = dir * (_pending_size.y / 2.0 + body_size.y / 2.0 + _OUTSIDE_GAP)
		target = Vector2(col.global_position.x, _pending_position.y + along.y)
	var shape := RectangleShape2D.new()
	shape.size = (body_size - Vector2.ONE * _OVERLAP_MARGIN * 2.0).max(Vector2.ONE)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, target)
	query.collision_mask = Layers.TERRAIN
	if not player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return null
	return target

# 玩家碰撞形狀現在的中心位置（沒有碰撞形狀就用玩家位置）
func _body_center() -> Vector2:
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return col.global_position if col != null else player.global_position

# 擠到殼外面又沒按方向鍵時，依「預設方向」決定往哪邊脫出
func _default_vector() -> Vector2:
	match default_direction:
		_DEFAULT_FACING:
			return Vector2(float(_facing), 0.0)
		_DEFAULT_BEHIND:
			return Vector2(-float(_facing), 0.0)
		_DEFAULT_DOWN:
			return -player.up_direction
	return player.up_direction

# 依方向鍵和優先順序決定往哪個方向脫出（擠到殼外面又沒按方向鍵時用預設方向）
func _pick_direction() -> Vector2:
	var side: float = player.get_move_input()
	var held := {
		_UP: _up_held,
		_SIDE: not is_zero_approx(side),
		_DOWN: _down_held,
	}
	if not start_inside and not held.values().has(true):
		return _default_vector()
	var order: Array = _ORDERS[clampi(direction_order, 0, _ORDERS.size() - 1)]
	var chosen: String = order[0]
	for d in order:
		if held[d]:
			chosen = d
			break
	match chosen:
		_UP:
			return player.up_direction
		_DOWN:
			return -player.up_direction
	var dir: float = signf(side) if not is_zero_approx(side) else float(_facing)
	return Vector2(dir, 0.0)

# 把玩家往指定方向彈出去；往左右的話暫時鎖住方向鍵，彈出去的速度才不會馬上被蓋掉
func _push_player(dir: Vector2) -> void:
	if strength <= 0.0:
		return
	player.add_impulse(dir * strength)
	if dir.x != 0.0:
		_side_lock_left = _SIDE_LOCK_DURATION

# 記住玩家碰撞形狀現在的中心位置和大小
func _remember_body() -> void:
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		_last_position = player.global_position
		_last_size = Vector2(16, 32)
		return
	_last_position = col.global_position
	if col.shape is RectangleShape2D:
		_last_size = (col.shape as RectangleShape2D).size

# 選了「縮小時」但場景裡沒有忽大忽小卡，就印中文警告
func _check_size_shift() -> void:
	var root := get_tree().current_scene
	if root == null or _find_size_shift(root) != null:
		return
	push_warning("[脫殼] 觸發時機選了「縮小時」，但場景裡沒有忽大忽小卡，永遠不會脫殼")
	printerr("⚠ [脫殼] 請在 Player → Mechanics 底下加忽大忽小卡，或把觸發時機改成「按下按鍵」")

# 在場景裡找忽大忽小卡，找不到回傳 null
func _find_size_shift(root: Node) -> Node:
	for n in root.find_children("*", "", true, false):
		var script := n.get_script() as Script
		if script != null and script.resource_path.get_file().get_basename() == _SIZE_SHIFT_CARD:
			return n
	return null

# 編輯器裡定時重新檢查黃色警告
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_warning_timer -= delta
	if _warning_timer <= 0.0:
		_warning_timer = _WARNING_REFRESH_SECONDS
		update_configuration_warnings()

# 編輯器裡的黃色驚嘆號：底下放了不是殼的東西、選縮小時但沒有忽大忽小卡
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for child in get_children():
		if not (child is Shell):
			warnings.append("「%s」不是殼（Shell），脫殼時不會用到，請把它拖出去" % child.name)
	if trigger_timing == _TRIGGER_SHRINK:
		var root := get_tree().edited_scene_root if is_inside_tree() else null
		if root != null and root != self and _find_size_shift(root) == null:
			warnings.append("觸發時機選了「縮小時」，但場景裡沒有忽大忽小卡，永遠不會脫殼；加一張忽大忽小卡，或把觸發時機改成「按下按鍵」")
	return warnings
