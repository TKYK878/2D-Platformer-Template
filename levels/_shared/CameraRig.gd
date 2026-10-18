extends Camera2D

# 接 Events.shake_requested，執行螢幕震動；接 Events.zoom_requested，執行鏡頭推近；
# 接 Events.room_entered，依鏡頭模式處理換房間。掛在關卡場景根節點底下，跟 Player 是平行關係。
# 鏡頭模式：
# - 瞬切：玩家進哪個房間，鏡頭就對準那個房間中心；場景裡沒有 Room 時維持原本擺的位置不動。
# - 房間內跟隨：跟著玩家跑，但畫面不會超出目前的房間；房間比畫面小的那一軸固定在房間中心。
#   場景裡沒有 Room 時就是一般的跟著玩家跑。
# - 自由跟隨：忽略房間，一直跟著玩家跑（例如展示間那種一路橫向走的長場地）。
# 換房間方式（瞬切、房間內跟隨模式才有用；遊戲剛開始進第一個房間一律直接到位）：
# - 直接切換：鏡頭一瞬間到新房間。
# - 黑畫面淡入淡出：畫面先慢慢變黑，全黑的那一刻鏡頭換到新房間，再慢慢亮回來。黑畫面由程式自己產生，不用擺節點。
# - 平滑移動：鏡頭從舊房間滑到新房間（房間內跟隨模式會一路滑到玩家在新房間該看的位置）。
# 震動是疊加在鏡頭位置上的偏移（offset），不會改到鏡頭位置；同時有好幾個震動請求時取比較強的那個。
# 推近是放大到 1 + strength 倍再回到原本大小，放大時畫面往請求指定的放大中心偏（偏一點／定在原地／拉到正中央），
# 偏移的限制範圍用放大後的畫面大小計算
# （鏡頭本身的跟隨範圍不變，推近結束時不會露出房間外）。Juice 總開關關掉、玩家重生時，進行中的震動與推近立刻停止；
# 玩家重生時進行中的換房間轉場也會立刻結束。

## 鏡頭模式：瞬切（每個房間一個固定畫面）、房間內跟隨（跟著玩家但不超出房間）、自由跟隨（不管房間，一直跟著玩家）
@export_enum("瞬切", "房間內跟隨", "自由跟隨") var mode: int = 0

## 換房間方式：直接切換、先變黑再亮回來、鏡頭平滑移動到下一間房間（自由跟隨模式不管房間，這個選項沒作用）
@export_enum("直接切換", "黑畫面淡入淡出", "平滑移動") var room_transition: int = 0

## 換房間轉場花幾秒（黑畫面是「變黑＋亮回來」的總時間，平滑移動是滑過去的時間）
@export_range(0.05, 3.0, 0.05) var transition_duration: float = 0.5

## 黑畫面的顏色（黑畫面淡入淡出用）
@export var fade_color: Color = Color.BLACK

const _MODE_SNAP := 0
const _MODE_ROOM_FOLLOW := 1
const _MODE_FREE_FOLLOW := 2
const _TRANSITION_INSTANT := 0
const _TRANSITION_FADE := 1
const _TRANSITION_SLIDE := 2
# 黑畫面要蓋在所有東西上面（包含 UI），圖層數字要夠大
const _FADE_LAYER := 100
# 推近時畫面往放大中心偏多少的三種方式（對應 Juice_CameraZoom.focus_style）
const _STYLE_LEAN := 0      # 偏一點：放大中心在畫面上的位置移動一半
const _STYLE_PIN := 1       # 定在原地：放大中心在畫面上的位置完全不動
const _STYLE_CENTER := 2    # 拉到正中央：放大到最大時放大中心在畫面正中間
# 推近的前面這段比例時間用來放大，剩下的時間慢慢回到原本大小
const _ZOOM_IN_PART := 0.25

var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_time_left: float = 0.0
var _zoom_strength: float = 0.0
var _zoom_duration: float = 0.0
var _zoom_time_left: float = 0.0
var _zoom_focus: Variant = null   # 放大中心：Node2D 跟著它、Vector2 固定位置、null 畫面中心
var _zoom_style: int = _STYLE_LEAN
var _base_zoom: Vector2 = Vector2.ONE
var _follow_target: Node2D = null
var _room: Node = null
var _view_sources: Dictionary = {}   # 把鏡頭拉遠的組件(Node) -> 畫面看到幾倍大，好幾個同時拉取最大的

var _fade_rect: ColorRect = null
var _fade_tween: Tween = null
var _pending_room: Node = null      # 黑畫面變黑中，等全黑才換過去的房間
var _slide_from: Vector2 = Vector2.ZERO
var _slide_time_left: float = 0.0

# 接上震動、推近、房間、重生、Juice 總開關訊號；記住原本的縮放；跟隨模式才開平滑，瞬切模式不平滑；
# 準備好換房間用的黑畫面
func _ready() -> void:
	_base_zoom = zoom
	Events.shake_requested.connect(_on_shake_requested)
	Events.zoom_requested.connect(_on_zoom_requested)
	Events.room_entered.connect(_on_room_entered)
	Events.player_respawned.connect(_on_player_respawned)
	JuiceSwitch.toggled.connect(_on_juice_switch_toggled)
	position_smoothing_enabled = mode != _MODE_SNAP
	_build_fade_overlay()

# 做一張蓋滿整個畫面的色塊放在最上層，平常完全透明，也不會擋到滑鼠
func _build_fade_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = _FADE_LAYER
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color(fade_color, 0.0)
	layer.add_child(_fade_rect)

# 玩家進入房間：自由跟隨只記下房間；其他模式依「換房間方式」換過去。
# 第一次進房間（遊戲剛開始）沒有舊房間可以轉場，一律直接到位
func _on_room_entered(room: Node) -> void:
	if mode == _MODE_FREE_FOLLOW:
		_room = room
		return
	if _pending_room != null:
		_pending_room = room  # 還在變黑：改成等一下換到最新進入的房間
		return
	if not is_instance_valid(_room) or room == _room:
		_apply_room(room)
		return
	match room_transition:
		_TRANSITION_FADE:
			_start_fade(room)
		_TRANSITION_SLIDE:
			_start_slide(room)
		_:
			_apply_room(room)

# 直接換到這個房間：瞬切模式跳到房間中心，房間內跟隨模式換成這個房間的範圍並瞬間到位
func _apply_room(room: Node) -> void:
	_room = room
	_slide_time_left = 0.0
	if mode == _MODE_SNAP:
		global_position = room.get_center()
	else:
		_follow_player()
	reset_smoothing()

# 黑畫面：前半段變黑，全黑時換房間，後半段亮回來（從目前的透明度開始，連續換房間也不會閃一下）
func _start_fade(room: Node) -> void:
	_pending_room = room
	if _fade_tween != null:
		_fade_tween.kill()
	var half := transition_duration / 2.0
	_fade_rect.color = Color(fade_color, _fade_rect.color.a)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", 1.0, half)
	_fade_tween.tween_callback(_on_fade_black)
	_fade_tween.tween_property(_fade_rect, "color:a", 0.0, half)

# 畫面全黑的那一刻：鏡頭換到新房間
func _on_fade_black() -> void:
	var room := _pending_room
	_pending_room = null
	if is_instance_valid(room):
		_apply_room(room)

# 平滑移動：記下鏡頭現在的位置，之後每幀從這裡滑向新房間該看的位置
func _start_slide(room: Node) -> void:
	_slide_from = global_position
	_room = room
	_slide_time_left = transition_duration

# 立刻結束進行中的換房間轉場：黑畫面拿掉、等著換的房間直接換過去、平滑移動直接到位
func _cancel_transition() -> void:
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	if _fade_rect != null:
		_fade_rect.color = Color(fade_color, 0.0)
	var room := _pending_room
	_pending_room = null
	if is_instance_valid(room):
		_apply_room(room)
	elif _slide_time_left > 0.0 and is_instance_valid(_room):
		_apply_room(_room)

# 玩家重生：停掉震動、推近與換房間轉場；跟隨模式直接跳到玩家身上，不要從死掉的地方一路滑過去
func _on_player_respawned(_player: Node) -> void:
	_stop_effects()
	_cancel_transition()
	if mode == _MODE_SNAP:
		return
	_follow_player()
	reset_smoothing()

# 接到震動請求：比正在進行的震動剩下的強度還強才換成新的，不然維持原本的
func _on_shake_requested(strength: float, duration: float) -> void:
	if duration <= 0.0 or strength < _current_shake_strength():
		return
	_shake_strength = strength
	_shake_duration = duration
	_shake_time_left = duration

# 接到推近請求：比正在進行的推近現在的放大量還大才換成新的，不然維持原本的
func _on_zoom_requested(strength: float, duration: float, focus: Variant, focus_style: int) -> void:
	if duration <= 0.0 or strength <= 0.0 or strength < _current_zoom_amount():
		return
	_zoom_strength = strength
	_zoom_duration = duration
	_zoom_time_left = duration
	_zoom_focus = focus
	_zoom_style = focus_style

# Juice 總開關關掉時，停掉進行中的震動與推近
func _on_juice_switch_toggled(on: bool) -> void:
	if not on:
		_stop_effects()

# 停掉震動與推近，鏡頭回到原本的大小
func _stop_effects() -> void:
	_shake_time_left = 0.0
	_zoom_time_left = 0.0
	zoom = _view_zoom()
	offset = Vector2.ZERO

# 正在進行的震動現在剩下多強
func _current_shake_strength() -> float:
	if _shake_time_left <= 0.0:
		return 0.0
	return _shake_strength * _shake_time_left / _shake_duration

# 正在進行的推近現在放大了多少（0 = 沒有放大）：前段快速放大，後段慢慢回到原本大小
func _current_zoom_amount() -> float:
	if _zoom_time_left <= 0.0:
		return 0.0
	var t: float = 1.0 - _zoom_time_left / _zoom_duration
	var envelope: float
	if t < _ZOOM_IN_PART:
		envelope = ease(t / _ZOOM_IN_PART, 0.5)
	else:
		envelope = 1.0 - ease((t - _ZOOM_IN_PART) / (1.0 - _ZOOM_IN_PART), 2.0)
	return _zoom_strength * envelope

# 每幀更新推近、跟隨（或換房間的平滑移動）與震動偏移
func _process(delta: float) -> void:
	_zoom_time_left = maxf(_zoom_time_left - delta, 0.0)
	var zoom_amount := _current_zoom_amount()
	zoom = _view_zoom() * (1.0 + zoom_amount)

	if _slide_time_left > 0.0:
		_update_slide(delta)
	elif mode != _MODE_SNAP:
		_follow_player()

	var shake := Vector2.ZERO
	if _shake_time_left > 0.0:
		shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _current_shake_strength()
		_shake_time_left = maxf(_shake_time_left - delta, 0.0)
	offset = _zoom_lean(zoom_amount) + shake

# 平滑移動中：從出發位置往新房間該看的位置滑，頭尾放慢；目的地每幀重算，玩家邊走鏡頭也會跟上
func _update_slide(delta: float) -> void:
	_slide_time_left = maxf(_slide_time_left - delta, 0.0)
	var t := 1.0 - _slide_time_left / transition_duration
	global_position = _slide_from.lerp(_desired_position(), smoothstep(0.0, 1.0, t))
	reset_smoothing()  # 自己算好了平滑，不要再被內建平滑拖慢

# 鏡頭這一刻「應該」在哪：瞬切模式是房間中心，跟隨模式是（限制在房間內的）玩家位置
func _desired_position() -> Vector2:
	if mode == _MODE_SNAP:
		return _room.get_center() if is_instance_valid(_room) else global_position
	return _follow_position()

# 推近時畫面往放大中心偏；不是自由跟隨的話，偏移後的畫面也不能超出目前的房間
func _zoom_lean(zoom_amount: float) -> Vector2:
	if zoom_amount <= 0.0:
		return Vector2.ZERO
	var focus_position: Vector2
	if _zoom_focus is Vector2:
		focus_position = _zoom_focus
	elif is_instance_valid(_zoom_focus) and _zoom_focus is Node2D:
		focus_position = _zoom_focus.global_position
	else:
		return Vector2.ZERO
	var center := get_screen_center_position() - offset
	var lean_ratio: float
	match _zoom_style:
		_STYLE_PIN:
			lean_ratio = 1.0 - 1.0 / (1.0 + zoom_amount)
		_STYLE_CENTER:
			lean_ratio = zoom_amount / _zoom_strength
		_:
			lean_ratio = 0.5 * (1.0 - 1.0 / (1.0 + zoom_amount))
	var target := center + (focus_position - center) * lean_ratio
	if mode != _MODE_FREE_FOLLOW and is_instance_valid(_room):
		target = _clamp_to_room(target, _room.get_rect(), zoom)
	return target - center

# 讓鏡頭跟著玩家（房間內跟隨模式再限制在房間範圍內）
func _follow_player() -> void:
	global_position = _follow_position()

# 跟隨時鏡頭該在的位置：找到玩家（還沒進場就維持原地，下一幀再試），房間內跟隨模式限制在房間範圍內
func _follow_position() -> Vector2:
	if not is_instance_valid(_follow_target):
		_follow_target = get_tree().get_first_node_in_group("player")
		if _follow_target == null:
			return global_position
	var target := _follow_target.global_position
	if mode == _MODE_ROOM_FOLLOW and is_instance_valid(_room):
		target = _clamp_to_room(target, _room.get_rect(), _view_zoom())
	return target

# 把鏡頭拉遠，作弊這類組件用這個：size 是畫面看到原本的幾倍大；on 傳 false 就把這個組件的拉遠拿掉
func set_view_size(source: Node, on: bool, size: float = 2.0) -> void:
	if on:
		_view_sources[source] = maxf(size, 1.0)
	else:
		_view_sources.erase(source)

# 現在不算推近的鏡頭縮放：原本的縮放，有人拉遠就照拉最遠的那個縮小
func _view_zoom() -> Vector2:
	var size := 1.0
	for source in _view_sources.keys():
		if is_instance_valid(source):
			size = maxf(size, _view_sources[source])
		else:
			_view_sources.erase(source)
	return _base_zoom / size

# 把鏡頭中心限制在房間裡，讓畫面不超出房間（view_zoom 決定畫面多大：跟隨用原本大小，
# 推近時往玩家偏移用放大後的大小）；房間比畫面小的那一軸固定在房間中心
func _clamp_to_room(target: Vector2, room_rect: Rect2, view_zoom: Vector2) -> Vector2:
	var half_view := get_viewport_rect().size / view_zoom / 2.0
	var result := target
	for axis in [0, 1]:
		var low: float = room_rect.position[axis] + half_view[axis]
		var high: float = room_rect.end[axis] - half_view[axis]
		if low >= high:
			result[axis] = room_rect.get_center()[axis]
		else:
			result[axis] = clampf(target[axis], low, high)
	return result
