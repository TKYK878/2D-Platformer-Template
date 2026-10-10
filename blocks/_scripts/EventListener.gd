@tool
extends Node2D

# 事件轉接器：聽一個遊戲事件（遊戲開始、玩家死亡、進入房間、過關…），發生時發出不帶參數的 triggered，
# 讓學員用「節點」面板的訊號連接接到任何零件（例如門的 activate）。
# 全域事件掛在 Events 自動載入上，編輯器的場景樹看不到，學員沒辦法直接連，所以由它轉接。

## 要聽哪一個遊戲事件
@export_enum("玩家死亡時", "玩家重生時", "玩家受傷時", "玩家跳躍時", "進入房間時", "過關時", "撿到道具時", "敵人被打倒時", "遊戲開始時", "整關重來時") var event: int = 0:
	set(value):
		event = value
		queue_redraw()
## 事件發生後，隔多久才發出訊號（秒）
@export_range(0.0, 3.0) var delay: float = 0.0

## 選的事件發生時發出，拿去連任何零件的函式（例如門的 activate）
signal triggered

const _EVENT_NAMES := ["玩家死亡時", "玩家重生時", "玩家受傷時", "玩家跳躍時", "進入房間時", "過關時", "撿到道具時", "敵人被打倒時", "遊戲開始時", "整關重來時"]
const _COLOR := Color(0.75, 0.55, 1.0, 0.9)

# 接上選的事件；沒連到任何東西時提醒學員，不然看起來像沒反應
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("signal_source")
	_connect_event()
	if triggered.get_connections().is_empty():
		push_warning("[事件轉接器] %s 的 triggered 沒有連到任何東西，事件發生時不會有反應" % name)
		printerr("⚠ [事件轉接器] %s 還沒連線：選它 → 右邊「節點」面板 → 雙擊 triggered → 選要控制的零件和函式" % name)

# 依 event 接上對應的 Events 訊號，事件帶的參數一律丟掉
func _connect_event() -> void:
	match event:
		0: Events.player_died.connect(_on_event)
		1: Events.player_respawned.connect(func(_player): _on_event())
		2: Events.player_hurt.connect(_on_event)
		3: Events.player_jumped.connect(_on_event)
		4: Events.room_entered.connect(func(_room): _on_event())
		5: Events.level_cleared.connect(_on_event)
		6: Events.item_collected.connect(func(_pos): _on_event())
		7: Events.enemy_died.connect(func(_pos): _on_event())
		8: Events.level_started.connect(_on_event)
		9: Events.whole_level_restarted.connect(_on_event)

# 事件發生：等 delay 秒後發出 triggered
func _on_event() -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	triggered.emit()

# 編輯畫面持續請求重畫，讓虛線跟著訊號連接的變化即時更新
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

# 編輯畫面用：畫一個圓點和事件名稱讓學員看得到、點得到，再畫訊號連接的虛線
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 6.0, _COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(9, 4), _EVENT_NAMES[event], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _COLOR)
	SignalLines.draw(self, triggered)
