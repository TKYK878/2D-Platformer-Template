@tool
extends MechanicBase

# 脫殼：縮小（或按下按鍵）時在原地留下一顆殼，玩家依方向鍵往某個方向脫出去，殼被反推往相反方向（作用力與反作用力）。備品庫卡，不在抽卡池裡。
# 脫出方向：手把搖桿推哪個角度就往哪個角度；鍵盤的上下左右可以合成八個方向（上、右上、右、右下、下、左下、左、左上）。
# 殼的種類＝卡片底下的殼（Shell）子節點，脫殼時複製一份放進關卡；底下沒有殼就用內建的殼。
# 按 Q／E 切換要脫哪種殼；數量上限、可脫次數照每種殼自己的設定。
# 勾「脫殼前必須先回收」時，每種殼各自照自己的數量上限、可脫次數計算，滿了就不能再脫那一種，要長按 Input Map 動作（時間可調）把殼收回來；
# 回收時玩家到殼中間被指定碰撞層的碰撞箱擋住的話，那顆殼收不回來。
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

## 什麼方向鍵都沒按、搖桿也沒推時往哪邊脫出：排第一的方向（排第一的是左右的話，往面向的方向；「start_inside」不勾時改看預設方向）。有按方向鍵時照方向鍵合成的八方向（搖桿照推的角度）
@export_enum("上 > 左右 > 下", "左右 > 上 > 下", "下 > 左右 > 上", "左右 > 下 > 上") var direction_order: int = 0

## 脫出去的力道，0 表示不彈出去、留在原地
@export_range(0.0, 800.0) var strength: float = 300.0

## 殼被反推的力道（作用力與反作用力：玩家往哪邊脫出，殼就往相反方向被推），0 表示殼留在原地；推不動的殼不受影響
@export_range(0.0, 800.0) var shell_strength: float = 200.0

## 脫出時，玩家往彈出方向的速度最多到多少（像素／秒）；已經很快的時候（例如跳起來的瞬間脫殼）只會補到這個上限，不會再疊上完整的力道。0 表示不限制
@export_range(0.0, 1200.0, 10.0, "or_greater") var max_push_speed: float = 450.0

## 脫殼的那一刻玩家窩在殼裡面，再慢慢鑽出來；不勾的話直接擠到殼外面（脫出方向被牆或地板擋住時，還是會窩在殼裡）
@export var start_inside: bool = true:
	set(value):
		start_inside = value
		notify_property_list_changed()

## 擠到殼外面時，什麼方向鍵都沒按的話往哪邊脫出（「start_inside」不勾時才會顯示這一欄）
@export_enum("上", "面向的方向", "背對的方向", "下") var default_direction: int = 0

@export_group("切換殼")

## 上一首/上一種殼的 Input Map 動作名稱
@export var prev_action_name: StringName = &"prev_shell"
## 下一首/下一種殼的 Input Map 動作名稱
@export var next_action_name: StringName = &"next_shell"

## 目前選中哪種殼要怎麼顯示在畫面上
@export_enum("玩家頭上", "畫面右上角", "兩個都要", "不顯示") var show_selected: int = 0

@export_group("回收殼")

## 每一種殼照自己的設定（數量上限、可脫次數）各自計算：某一種殼滿了或次數用完，就不能再脫那一種，要長按回收鍵把殼收回來才行（不會自動碎掉最舊的）；其他種類的殼不受影響，照樣可以脫（避免一直脫殼、一直被彈起來，變成無限飛行）
@export var require_recall: bool = true:
	set(value):
		require_recall = value
		notify_property_list_changed()

## 長按哪個 Input Map 動作回收場上的殼（動作在「專案設定 → Input Map」裡加，可以綁手把；回收後可以脫的次數也一起恢復）
@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin") var recall_action: StringName = &""

## 要連續按住回收鍵幾秒才會回收，中途放開就重新算
@export_range(0.1, 5.0, 0.05, "or_greater") var recall_hold_time: float = 1.0

## 長按回收鍵的時候，在玩家頭上顯示一條小進度條（場上沒有殼可以回收時不顯示）
@export var show_recall_bar: bool = true

## 長按回收鍵的進度條滿了的那一刻，在玩家跟殼之間顯示一條虛線（沒被擋住是白色，被擋住是紅色、畫到擋住的地方）
@export var show_recall_line: bool = true

## 回收時，玩家到殼中間如果有這些碰撞層的碰撞箱（實體或 Area 都算）擋著，那顆殼就收不回來；一個都不勾就不檢查
@export_flags_2d_physics var recall_block_mask: int = 0

## 只有站在地面上才能回收；不勾的話在空中也能回收，就能「脫殼、回收、再脫殼」一直飛上去
@export var recall_on_ground_only: bool = true

@export_group("換房間時")
## 玩家走進別的房間時，把留在其他房間的殼都碎掉（碎掉的殼用掉的次數也還回去）；殼不會留在玩家回不去的地方害玩家卡關
@export var clear_on_room_change: bool = true

@export_group("玩家死掉時")
## 玩家死掉時，已經脫下來的殼怎麼處理（清掉時，可以脫的次數也一起恢復）
@export_enum("重生時清掉", "死掉時馬上清掉", "保留") var on_death: int = 0

## 脫出一顆殼之後發出
signal shell_created
## 用切換鍵換了一種殼之後發出
signal shell_changed
## 長按回收鍵，至少有一顆殼被收回來之後發出
signal shells_recalled
## 想回收但回收不了時發出（按下回收鍵時不在地面，或回收時有殼被碰撞箱擋著；可以接「無效」提示）
signal recall_blocked
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
# 回收進度條的大小、離頭頂多遠（比頭上的小方塊再高一點）
const _RECALL_BAR_SIZE := Vector2(24.0, 4.0)
const _RECALL_BAR_GAP := 22.0
# 回收虛線顯示幾秒、虛線每一段多長
const _RECALL_LINE_DURATION := 0.35
const _RECALL_LINE_DASH := 4.0
# 方向鍵鎖定結束後，速度從彈出去的速度平順降回正常跑速要花幾秒（不然會瞬間被拉回正常速度，看起來像突然煞車）
const _GLIDE_DURATION := 0.15
# 手把搖桿推超過這麼多才算有推（0～1），以及看哪兩個軸（左搖桿）
const _STICK_DEADZONE := 0.3
# 斜的方向在某一軸上至少要有這麼多（約 22.5 度），擠到殼外面時才往那一軸擠
const _AXIS_MIN := 0.38
# 擠到殼外面時，玩家跟殼之間留一點空隙（殼頂端還有一片薄平台，要站在它上面）
const _OUTSIDE_GAP := 3.0
# 檢查殼外面有沒有空間時，形狀每邊縮一點，避免剛好貼著地板也被當成擋住
const _OVERLAP_MARGIN := 1.0
# 編輯器裡每隔幾秒重新檢查一次，學員加減忽大忽小卡之後黃色警告會跟著更新
const _WARNING_REFRESH_SECONDS := 1.0

var _templates: Array[Shell] = []
# process_mode 設成 Disabled 的殼視為「待解鎖」，不放進 _templates
var _locked_shells: Array[Shell] = []
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
var _glide_left: float = 0.0
var _recall_held: float = 0.0     # 回收鍵已經連續按住幾秒
var _recall_bar: Node2D = null
var _recall_line: Node2D = null
var _recall_index: int = -1      # 這次長按要回收哪一種殼（按下回收鍵當下選中的那一種）
var _recalling: bool = false      # 已經按下回收鍵、正在長按計時（按下的那一刻就判斷過能不能回收）
var _recall_lines: Array = []     # 回收虛線：每條是 {"to": 終點, "blocked": 有沒有被擋住}
var _recall_line_left: float = 0.0
var _recall_done: bool = false    # 這一次按住已經回收過了，放開之前不再重複回收
var _glide_ratio: float = 1.0   # 鎖定剛結束時的水平速度是正常跑速的幾倍
var _warning_timer: float = 0.0
# 場景裡還在的殼（照脫出的順序，最舊的在前面），以及每顆殼是哪種、在哪個房間脫的
var _shells: Array[Shell] = []
var _shell_template: Dictionary = {}    # Shell -> 模板編號
var _shell_room: Dictionary = {}        # Shell -> 房間（沒有房間的關卡是 null）
var _uses: Dictionary = {}              # 模板編號 -> 已經脫了幾次
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
	elif property.name in ["recall_action", "recall_hold_time", "show_recall_bar", "show_recall_line", "recall_block_mask", "recall_on_ground_only"] and not require_recall:
		property.usage = PROPERTY_USAGE_NONE

# 一進場景就把底下的殼收起來當模板（趁它們還沒啟動），不然它們會變成黏在玩家身上的真的殼。
# process_mode == PROCESS_MODE_DISABLED 的殼視為「待解鎖」，存進 _locked_shells，
# 等 unlock_shell() 呼叫後才加入 _templates
func _enter_tree() -> void:
	if Engine.is_editor_hint() or _collected:
		return
	_collected = true
	for child in get_children():
		if child is Shell:
			remove_child(child)
			if child.process_mode == Node.PROCESS_MODE_DISABLED:
				_locked_shells.append(child)
			else:
				_templates.append(child)
		else:
			push_warning("[脫殼] 卡片底下的「%s」不是殼（Shell），脫殼時不會用到" % child.name)
			printerr("⚠ [脫殼] 卡片底下只能放殼（Shell），請把「%s」拖出去" % child.name)
	if _templates.is_empty() and _locked_shells.is_empty():
		for path in _BUILT_IN_SHELLS:
			_templates.append(load(path).instantiate())

# 編輯器裡不做執行時的檢查
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(false)
	super._ready()

# 卡片被刪掉時，一起刪掉收起來的殼模板（包含尚未解鎖的）
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for t in _templates:
			if is_instance_valid(t):
				t.free()
		for t in _locked_shells:
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

	if require_recall:
		_check_recall_setup()
		if show_recall_bar:
			_make_recall_bar()
		if show_recall_line:
			_make_recall_line()

	if on_death == _CLEAR_ON_DEATH:
		Events.player_died.connect(clear_shells)
	if clear_on_room_change:
		Events.room_entered.connect(_on_room_entered)
	_make_display()
	InputRouter.bind(self, "move_up", InputRouter.HELD, func(_t: float): _up_held = true)
	InputRouter.bind(self, "move_down", InputRouter.HELD, func(_t: float): _down_held = true)
	player.direction_changed.connect(func(dir: int): _facing = dir)
	_remember_body()
	_connect_shell_pickups()

# 掃場景裡所有 Pickup，若其 custom_kind 對應到某個鎖定殼的名稱，就自動連接 collected 訊號
func _connect_shell_pickups() -> void:
	if _locked_shells.is_empty():
		return
	var root := get_tree().current_scene
	if root == null:
		return
	# 建立鎖定殼名稱的快速查找表
	var locked_names: Dictionary = {}
	for shell in _locked_shells:
		locked_names[shell.name] = true
	# 掃場景裡有 get_value_kind() 方法的節點（即 Pickup）
	for node in root.find_children("*", "", true, false):
		if not node.has_method("get_value_kind"):
			continue
		var kind: String = node.get_value_kind()
		if kind in locked_names and not node.collected.is_connected(unlock_shell.bind(kind)):
			node.collected.connect(unlock_shell.bind(kind))
			print("[脫殼] 已連接道具「%s」→ 解鎖殼「%s」" % [node.name, kind])

# 將指定名稱的鎖定殼解鎖（恢復 process_mode 並加入 _templates）；
# 用 Pickup 的 collected 訊號連過來，或在程式裡直接呼叫皆可
func unlock_shell(shell_name: String) -> void:
	for i in range(_locked_shells.size() - 1, -1, -1):
		var shell := _locked_shells[i]
		if shell.name == shell_name:
			_locked_shells.remove_at(i)
			shell.process_mode = Node.PROCESS_MODE_INHERIT
			_templates.append(shell)
			_refresh_display()
			print("[脫殼] 已解鎖殼「%s」" % shell_name)
			return

# 處理這一幀要不要脫殼，並記住玩家現在的位置和大小（縮小之後還要知道縮小前多大）
func apply(ctx: MoveContext) -> void:
	if Input.is_action_just_pressed(prev_action_name):
		_switch(-1)
	if Input.is_action_just_pressed(next_action_name):
		_switch(1)
	_update_recall(ctx)
	if _side_lock_left > 0.0:
		_side_lock_left -= ctx.delta
		ctx.input_locked = true
		# 鎖定期間不套用地面摩擦力，彈出去的速度才不會被煞掉
		ctx.friction_scale = 0.0
		if _side_lock_left <= 0.0:
			_start_glide()
	elif _glide_left > 0.0:
		_apply_glide(ctx)
	if _pending:
		_pending = false
		_molt()
		# 脫殼的這一幀就要鎖住方向鍵，不然按著方向鍵的話，往側邊彈出去的速度這一幀就被跑速蓋掉
		if _side_lock_left > 0.0:
			ctx.input_locked = true
			ctx.friction_scale = 0.0
	_up_held = false
	_down_held = false
	_remember_body()
	_update_head_icon()
	_update_recall_bar()
	_update_recall_line(ctx.delta)

# 重生時取消還沒處理的脫殼、解除方向鎖；死亡處理選「重生時清掉」就把殼清掉
func on_respawn() -> void:
	_pending = false
	_side_lock_left = 0.0
	_glide_left = 0.0
	_stop_recall()
	_recall_line_left = 0.0
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

# 玩家走進某個房間：不在這個房間裡的殼都碎掉，用掉的次數還回去（沒有房間的關卡不會發這個訊號）
func _on_room_entered(room: Node) -> void:
	if room == null:
		return
	var cleared := 0
	for shell in _shells.duplicate():
		if not is_instance_valid(shell) or shell.is_broken():
			continue
		# 看殼現在在哪個房間（被推過去、帶過去的殼算新房間的），不在任何房間裡的也碎掉
		if _room_at(shell.global_position) == room:
			continue
		var index: int = _shell_template.get(shell, -1)
		if index >= 0:
			_uses[index] = maxi(int(_uses.get(index, 0)) - 1, 0)
		_forget_shell(shell)
		shell.break_shell()
		cleared += 1
	if cleared > 0:
		_refresh_display()
		print("[脫殼] 換了房間，留在其他房間的 %d 顆殼碎掉了" % cleared)

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
	_push_shell(shell, -dir)

# 場上現在有沒有還沒碎掉的殼
func _has_shell() -> bool:
	for shell in _shells:
		if is_instance_valid(shell) and not shell.is_broken():
			return true
	return false

# 建立回收進度條（跟頭上的小方塊一樣是程式建的，學員不用擺節點）
func _make_recall_bar() -> void:
	_recall_bar = Node2D.new()
	_recall_bar.name = "RecallProgressBar"
	_recall_bar.top_level = true
	_recall_bar.visible = false
	_recall_bar.draw.connect(_draw_recall_bar)
	add_child(_recall_bar)

# 長按回收鍵、場上有殼、這一次還沒回收的時候，把進度條擺到玩家頭頂（重力翻轉時也是頭頂那一邊）
func _update_recall_bar() -> void:
	if _recall_bar == null:
		return
	var show_bar := _recalling and _has_shell_of(_recall_index)
	_recall_bar.visible = show_bar
	if not show_bar:
		return
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var half_height: float = 16.0
	var center: Vector2 = player.global_position
	if col != null and col.shape is RectangleShape2D:
		half_height = (col.shape as RectangleShape2D).size.y / 2.0
		center = col.global_position
	_recall_bar.global_position = center + player.up_direction * (half_height + _RECALL_BAR_GAP)
	_recall_bar.queue_redraw()

# 畫進度條：黑底、白色填滿到按住的比例
func _draw_recall_bar() -> void:
	var ratio := clampf(_recall_held / maxf(recall_hold_time, 0.01), 0.0, 1.0)
	var rect := Rect2(-_RECALL_BAR_SIZE / 2.0, _RECALL_BAR_SIZE)
	_recall_bar.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.6))
	_recall_bar.draw_rect(Rect2(rect.position, Vector2(_RECALL_BAR_SIZE.x * ratio, _RECALL_BAR_SIZE.y)), Color.WHITE)
	_recall_bar.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.9), false, 1.0)

# 場上有沒有還沒碎掉的、指定種類（模板編號）的殼；每一種殼各算各的，不會互相擋
func _has_shell_of(index: int) -> bool:
	for shell in _shells:
		if is_instance_valid(shell) and not shell.is_broken() and _shell_template.get(shell, -1) == index:
			return true
	return false

# 開場檢查回收設定：沒選回收動作、動作找不到、沒勾阻擋碰撞層，都印中文警告
func _check_recall_setup() -> void:
	if recall_action == &"":
		var message := "[脫殼] 勾了「脫殼前必須先回收」，但還沒選回收用的 Input Map 動作，場上有殼之後就永遠脫不出新的殼"
		push_warning(message)
		printerr("⚠ %s" % message)
		return
	InputRouter.check_action(recall_action, "[脫殼]")
	if recall_block_mask == 0:
		var message := "[脫殼] 回收殼的「阻擋碰撞層」一個都沒勾，回收時不會檢查玩家跟殼中間有沒有被擋住"
		push_warning(message)
		printerr("⚠ %s" % message)

# 建立回收虛線（程式建的，用世界座標畫，學員不用擺節點）
func _make_recall_line() -> void:
	_recall_line = Node2D.new()
	_recall_line.name = "RecallLine"
	_recall_line.top_level = true
	_recall_line.visible = false
	_recall_line.draw.connect(_draw_recall_line)
	add_child(_recall_line)

# 虛線顯示的這段時間每幀重畫；時間到就隱藏
func _update_recall_line(delta: float) -> void:
	if _recall_line == null:
		return
	if _recall_line_left > 0.0:
		_recall_line_left -= delta
		_recall_line.visible = true
		_recall_line.queue_redraw()
	else:
		_recall_line.visible = false

# 從玩家身體中心畫虛線到每顆殼：沒被擋住是白色，被擋住是紅色、畫到擋住的地方
func _draw_recall_line() -> void:
	var from := _body_center()
	for line in _recall_lines:
		var color: Color = Color(1.0, 0.3, 0.3) if line["blocked"] else Color.WHITE
		_recall_line.draw_dashed_line(from, line["to"], color, 1.5, _RECALL_LINE_DASH)

# 回收鍵的處理：按下的那一刻先判斷能不能回收（場上有殼、站在地面），可以才開始長按計時；
# 計時中玩家不能走動、不能跳，中途放開、殼沒了、離開地面都會取消，要重新按；計時滿了回收一次
func _update_recall(ctx: MoveContext) -> void:
	if not require_recall or recall_action == &"" or not InputMap.has_action(recall_action) or player.is_dead():
		_stop_recall()
		return
	if Input.is_action_just_pressed(recall_action):
		_try_start_recall()
	if not Input.is_action_pressed(recall_action):
		_stop_recall()
		return
	if not _recalling:
		return
	# 計時中換了選中的殼、這種殼沒了、或離開地面都取消
	if _selected != _recall_index or not _has_shell_of(_recall_index) \
			or (recall_on_ground_only and not player.is_on_ground()):
		_stop_recall()
		return
	ctx.input_locked = true
	_recall_held += ctx.delta
	if _recall_held >= recall_hold_time:
		_recalling = false
		_recall_done = true
		_recall_shells(_recall_index)

# 按下回收鍵：場上沒有殼就不處理；設定只能在地面回收卻人在空中，就提示回收不了；都可以才開始計時
func _try_start_recall() -> void:
	if _templates.is_empty():
		return
	var index := clampi(_selected, 0, _templates.size() - 1)
	if not _has_shell_of(index):
		print("[脫殼] 場上沒有「%s」可以回收" % _templates[index].name)
		return
	if recall_on_ground_only and not player.is_on_ground():
		print("[脫殼] 要站在地面上才能回收殼")
		recall_blocked.emit()
		Events.mechanic_event.emit("Extra_Molt", "recall_blocked")
		return
	_recall_index = index
	_recalling = true
	_recall_held = 0.0
	_recall_done = false

# 取消計時，回到沒在回收的狀態
func _stop_recall() -> void:
	_recall_index = -1
	_recalling = false
	_recall_held = 0.0
	_recall_done = false

# 計時滿了，回收場上「這一種」的殼（其他種類不動）：玩家到殼中間沒被擋住的就收回來（這顆殼用掉的次數也還回去），
# 被擋住的留在原地；同時記下虛線要畫到哪裡
func _recall_shells(index: int) -> void:
	var recalled := 0
	var blocked := 0
	_recall_lines.clear()
	for shell in _shells.duplicate():
		if not is_instance_valid(shell) or shell.is_broken() or _shell_template.get(shell, -1) != index:
			continue
		var hit: Variant = _recall_hit(shell)
		if hit != null:
			blocked += 1
			_recall_lines.append({"to": hit, "blocked": true})
			continue
		_recall_lines.append({"to": shell.global_position, "blocked": false})
		_uses[index] = maxi(int(_uses.get(index, 0)) - 1, 0)
		_forget_shell(shell)
		shell.break_shell()
		recalled += 1
	_recall_line_left = _RECALL_LINE_DURATION
	if blocked > 0:
		print("[脫殼] 有 %d 顆殼跟玩家中間被碰撞箱擋住，收不回來" % blocked)
		recall_blocked.emit()
		Events.mechanic_event.emit("Extra_Molt", "recall_blocked")
	if recalled > 0:
		_refresh_display()
		shells_recalled.emit()
		Events.mechanic_event.emit("Extra_Molt", "shells_recalled")

# 從玩家身體中心到殼的中心拉一條線，碰到 recall_block_mask 的碰撞箱就回傳碰到的位置（被擋住），
# 沒碰到（或沒勾任何層）回傳 null；殼自己跟玩家不算
func _recall_hit(shell: Shell) -> Variant:
	if recall_block_mask == 0:
		return null
	var query := PhysicsRayQueryParameters2D.create(_body_center(), shell.global_position, recall_block_mask)
	query.collide_with_areas = true
	var exclude: Array[RID] = [player.get_rid()]
	if shell is CollisionObject2D:
		exclude.append((shell as CollisionObject2D).get_rid())
	for child in shell.find_children("*", "CollisionObject2D", true, false):
		exclude.append((child as CollisionObject2D).get_rid())
	query.exclude = exclude
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result["position"]

# 依殼的設定檢查能不能再脫一顆：次數用完、或數量滿了又不能再脫就回傳 false；
# 數量滿了要碎掉最舊的，就在這裡碎掉
func _make_room_for(index: int, template: Shell, room: Node) -> bool:
	if template.max_uses > 0 and int(_uses.get(index, 0)) >= template.max_uses:
		var used_hint := "，先長按回收鍵把殼收回來" if require_recall else ""
		print("[脫殼] 「%s」可以脫的次數用完了%s" % [template.name, used_hint])
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
	if template.when_full == _FULL_BLOCK or require_recall:
		var full_hint := "，先長按回收鍵把殼收回來" if require_recall else ""
		print("[脫殼] 「%s」的數量滿了（最多 %d 顆），不能再脫%s" % [template.name, template.max_count, full_hint])
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
	# 斜的方向兩軸都要擠出去（擠到殼的斜角外面）
	if absf(dir.x) >= _AXIS_MIN:
		target.x = _pending_position.x + signf(dir.x) * (_pending_size.x / 2.0 + body_size.x / 2.0 + _OUTSIDE_GAP)
	if absf(dir.y) >= _AXIS_MIN:
		target.y = _pending_position.y + signf(dir.y) * (_pending_size.y / 2.0 + body_size.y / 2.0 + _OUTSIDE_GAP)
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

# 決定往哪個方向脫出：搖桿有推就照推的角度，不然照方向鍵合成八方向；
# 都沒按時，窩在殼裡的話照優先順序排第一的方向，擠到殼外面的話照預設方向
func _pick_direction() -> Vector2:
	var input := _stick_vector()
	if input == Vector2.ZERO:
		input = _key_vector()
	if input == Vector2.ZERO:
		if not start_inside:
			return _default_vector()
		var order: Array = _ORDERS[clampi(direction_order, 0, _ORDERS.size() - 1)]
		match order[0]:
			_UP:
				return player.up_direction
			_DOWN:
				return -player.up_direction
		return Vector2(float(_facing), 0.0)
	# 輸入的上下是畫面上的上下，換成玩家的頭頂方向（重力翻轉時上下跟著翻）
	return (Vector2(input.x, 0.0) + player.up_direction * -input.y).normalized()

# 手把左搖桿推的方向（畫面座標，往下是正 y）；沒接手把或推得不夠多回傳 0
func _stick_vector() -> Vector2:
	for device in Input.get_connected_joypads():
		var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if v.length() >= _STICK_DEADZONE:
			return v.normalized()
	return Vector2.ZERO

# 鍵盤方向鍵合成的方向（畫面座標）：上下左右各一，同時按就是斜的，總共八個方向；沒按回傳 0
func _key_vector() -> Vector2:
	var v := Vector2(signf(player.get_move_input()), 0.0)
	if _up_held:
		v.y -= 1.0
	if _down_held:
		v.y += 1.0
	return v.normalized() if v != Vector2.ZERO else Vector2.ZERO

# 把玩家往指定方向彈出去；有往左右（含斜的）的話暫時鎖住方向鍵，彈出去的速度才不會馬上被蓋掉
func _push_player(dir: Vector2) -> void:
	if strength <= 0.0:
		return
	var impulse: float = strength
	if max_push_speed > 0.0:
		# 只補到上限：玩家本來就朝這個方向飛得很快的話，補得少甚至不補
		impulse = clampf(max_push_speed - player.velocity.dot(dir), 0.0, strength)
	if impulse <= 0.0:
		return
	player.add_impulse(dir * impulse)
	if absf(dir.x) >= _AXIS_MIN:
		_side_lock_left = _SIDE_LOCK_DURATION

# 反作用力：殼往玩家脫出的反方向被推出去（推不動、固定住的殼不動）
func _push_shell(shell: Shell, dir: Vector2) -> void:
	if shell_strength <= 0.0 or shell.freeze:
		return
	shell.linear_velocity = dir * shell_strength

# 方向鍵鎖定剛結束：如果水平速度比正常跑速快，接下來一小段時間讓跑速從這個速度慢慢降回正常，
# 不然玩家按著方向鍵的話，速度會在這一幀被直接設回正常跑速
func _start_glide() -> void:
	var ratio: float = absf(player.velocity.x) / maxf(player.move_speed, 1.0)
	if ratio > 1.0:
		_glide_ratio = ratio
		_glide_left = _GLIDE_DURATION

# 平順降速：沒按方向鍵（交給摩擦力）或改按反方向（照玩家的意思立刻轉向）就不再處理
func _apply_glide(ctx: MoveContext) -> void:
	_glide_left -= ctx.delta
	var input_dir: float = player.get_move_input()
	if is_zero_approx(input_dir) or signf(input_dir) != signf(player.velocity.x):
		_glide_left = 0.0
		return
	ctx.speed_scale *= lerpf(1.0, _glide_ratio, clampf(_glide_left / _GLIDE_DURATION, 0.0, 1.0))

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
