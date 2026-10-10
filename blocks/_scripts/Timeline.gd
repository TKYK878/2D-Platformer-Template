@tool
extends Node2D

# 時間軸：開始計時後，跑到底下每個時間軸事件（TimelineEvent 子節點）設定的秒數時，讓那個事件發出 triggered。
# 秒數一律從時間軸開始算起（像影片的時間刻度），不是等上一列之後幾秒，所以子節點的上下順序不影響觸發時間。
# 一個子節點一列，要多一個事件就複製一列；子節點可以改名成「10秒開門」方便辨認。
# 本身也可以用訊號控制：activate 開始／繼續、deactivate 暫停、toggle 切換、restart 從 0 重來。
# 編輯器裡會在旁邊按秒數列出「第幾秒｜事件名稱」，並畫出每個事件的訊號虛線。

## 一開場就開始計時（關掉的話要靠別的零件的訊號 activate 才會開始）
@export var start_on: bool = true

## 玩家死掉重生時：時間從 0 重來（事件會再觸發一次），或繼續跑不受影響
@export_enum("從 0 重來", "繼續跑") var on_death: int = 0

## 跑完最後一個事件之後，要不要從 0 再來一輪
@export var loop: bool = false

## 在畫面右上角顯示目前跑到第幾秒，方便對時間
@export var show_time: bool = false

const _ON_DEATH_RESTART := 0
const _EVENT_SCRIPT_PATH := "res://blocks/_scripts/TimelineEvent.gd"
const _LABEL_COLOR := Color(0.6, 0.95, 0.75, 0.9)
const _OFF_COLOR := Color(0.6, 0.6, 0.6, 0.7)

var _running: bool = false
var _elapsed: float = 0.0
var _fired: Array[Node] = []
var _time_label: Label = null

## 開始計時（暫停中的話從暫停的地方繼續）
func activate() -> void:
	_running = true

## 暫停計時
func deactivate() -> void:
	_running = false

## 切換開始／暫停
func toggle() -> void:
	_running = not _running

## 時間從 0 重來並開始計時，事件會再觸發一次
func restart() -> void:
	_elapsed = 0.0
	_fired.clear()
	_running = true

# 檢查底下的子節點、接上重生事件、準備畫面上的秒數，套用一開始要不要跑
func _ready() -> void:
	if Engine.is_editor_hint():
		child_entered_tree.connect(func(_n): _refresh_editor())
		child_exiting_tree.connect(func(_n): _refresh_editor.call_deferred())
		return
	add_to_group("timeline")
	_check_children()
	Events.player_respawned.connect(_on_player_respawned)
	if show_time:
		_create_time_label()
	_running = start_on
	_update_time_label()

# 每個物理幀：時間往前走，到了就觸發還沒觸發過的事件；loop 開啟時全部觸發完就從頭再來
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _running:
		return
	_elapsed += delta
	for event in _get_events():
		if event.enabled and event not in _fired and _elapsed >= event.time:
			_fired.append(event)
			event.fire()
	if loop:
		_loop_if_done()
	_update_time_label()

# 全部啟用的事件都觸發過了就從頭再來；最後一個事件在第 0 秒的話不重來（不然每一幀都會觸發）
func _loop_if_done() -> void:
	var length := 0.0
	for event in _get_events():
		if event.enabled:
			if event not in _fired:
				return
			length = maxf(length, event.time)
	if length <= 0.0:
		return
	_elapsed -= length
	_fired.clear()

# 玩家重生：依 on_death 決定時間要不要從 0 重來（暫停中的時間軸只歸零、不會自己開始跑）
func _on_player_respawned(_player: Node) -> void:
	if on_death != _ON_DEATH_RESTART:
		return
	_elapsed = 0.0
	_fired.clear()
	_update_time_label()

# 底下所有的時間軸事件（不是時間軸事件的子節點跳過）
func _get_events() -> Array[Node]:
	var events: Array[Node] = []
	for child in get_children():
		if _is_event(child):
			events.append(child)
	return events

# 這個節點是不是時間軸事件
func _is_event(node: Node) -> bool:
	var node_script: Script = node.get_script()
	return node_script != null and node_script.resource_path == _EVENT_SCRIPT_PATH

# 執行時檢查子節點：沒有任何事件、或混進不是事件的東西，就印中文警告
func _check_children() -> void:
	if _get_events().is_empty():
		push_warning("[時間軸] %s 底下沒有任何時間軸事件，不會觸發任何東西" % name)
		printerr("⚠ [時間軸] 把 blocks/TimelineEvent.tscn 拖到 %s 底下，一個事件一列" % name)
	for child in get_children():
		if not _is_event(child):
			push_warning("[時間軸] %s 不是時間軸事件，放在 Timeline 底下不會有作用" % child.name)
			printerr("⚠ [時間軸] %s 不是時間軸事件（TimelineEvent），請拖到關卡的其他地方" % child.name)

# 編輯器裡的黃色驚嘆號：底下沒有任何事件，或混進不是事件的東西
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if _get_events().is_empty():
		warnings.append("時間軸底下還沒有事件：把 blocks/TimelineEvent.tscn 拖到這個節點上，一個事件一列。")
	for child in get_children():
		if not _is_event(child):
			warnings.append("「%s」不是時間軸事件，放在這裡不會有作用。" % child.name)
	return warnings

# 子節點增減或改秒數時，更新黃色警告和編輯器裡的清單
func _refresh_editor() -> void:
	update_configuration_warnings()
	queue_redraw()

# 在畫面右上角的共用容器加一行顯示秒數的文字；場景裡有好幾個時間軸、或有其他卡的預設 UI 時自動往下排
func _create_time_label() -> void:
	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	StatsHud.get_corner(StatsHud.CORNER_TOP_RIGHT).add_child(_time_label)
	_update_time_label()

# 更新畫面上的秒數；場景裡第一個時間軸把秒數公開給 HUD，學員的 HUD 有顯示時間軸時預設的秒數讓位
func _update_time_label() -> void:
	if _is_first_timeline():
		HudData.publish(HudData.TIMELINE, _elapsed)
	if _time_label != null:
		_time_label.text = "%s：%.1f 秒" % [name, _elapsed]
		_time_label.visible = not HudData.is_claimed(HudData.TIMELINE)

# 是不是場景裡第一個時間軸（只有它的秒數會公開給 HUD）
func _is_first_timeline() -> bool:
	return get_tree().get_first_node_in_group("timeline") == self

# 被拔掉時，時間軸的秒數不再是顯示來源（是第一個時間軸才拿掉），右上角的秒數也一起拿掉
func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if _is_first_timeline():
		HudData.remove_source(HudData.TIMELINE)
	if is_instance_valid(_time_label):
		_time_label.queue_free()

# 編輯畫面持續重畫，讓清單跟著改名、改秒數、訊號連接即時更新
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

# 編輯畫面用：畫一個時鐘圓點和名稱，下面按秒數排出每個事件，再畫每個事件的訊號虛線
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 6.0, _LABEL_COLOR)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(9, 4), "時間軸 %s（從開始算起）" % name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _LABEL_COLOR)
	var events := _get_events()
	events.sort_custom(func(a, b): return a.time < b.time)
	var y := 16.0
	for event in events:
		var color := _LABEL_COLOR if event.enabled else _OFF_COLOR
		draw_string(font, Vector2(9, y), event.get_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
		y += 10.0
	for event in events:
		SignalLines.draw(self, event.triggered)
