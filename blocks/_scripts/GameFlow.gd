@tool
extends Node2D

# 遊戲流程：把所有遊戲事件（遊戲開始、玩家死亡、過關…）都變成這個節點自己的訊號。
# 拖進關卡，選它 → 右邊「節點」面板，挑想要的事件雙擊，連到任何零件的函式（例如門的 activate）。
# 全域事件掛在 Events 自動載入上，編輯器的場景樹看不到，學員沒辦法直接連，所以由它一次轉接全部。
# 只想聽一個事件、或要延遲幾秒再觸發，用 EventListener。

## 遊戲開始時：關卡開場、所有東西都準備好之後發一次
signal game_started
## 整關重來時：重生方式選「整關重來」的重生、過關畫面按「再玩一次」
signal whole_level_restarted
## 玩家死亡時
signal player_died
## 玩家重生時（不管是回到房間還是整關重來）
signal player_respawned
## 玩家受傷時
signal player_hurt
## 玩家跳躍時
signal player_jumped
## 玩家走進一個房間時
signal room_entered
## 撿到道具時
signal item_collected
## 敵人被打倒時
signal enemy_died
## 過關時
signal level_cleared

const _COLOR := Color(1.0, 0.75, 0.3, 0.9)

# 把 Events 的每一個事件接到自己對應的訊號（事件帶的參數一律丟掉）；一條都沒連時提醒學員
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("signal_source")
	Events.level_started.connect(game_started.emit)
	Events.whole_level_restarted.connect(whole_level_restarted.emit)
	Events.player_died.connect(player_died.emit)
	Events.player_respawned.connect(func(_player): player_respawned.emit())
	Events.player_hurt.connect(player_hurt.emit)
	Events.player_jumped.connect(player_jumped.emit)
	Events.room_entered.connect(func(_room): room_entered.emit())
	Events.item_collected.connect(func(_pos): item_collected.emit())
	Events.enemy_died.connect(func(_pos): enemy_died.emit())
	Events.level_cleared.connect(level_cleared.emit)
	if not _has_any_connection():
		push_warning("[遊戲流程] %s 的訊號都沒有連到任何東西，事件發生時不會有反應" % name)
		printerr("⚠ [遊戲流程] %s 還沒連線：選它 → 右邊「節點」面板 → 雙擊想要的事件 → 選要控制的零件和函式" % name)

# 回傳自己的訊號裡有沒有任何一條連出去
func _has_any_connection() -> bool:
	for info in get_script().get_script_signal_list():
		if not get_signal_connection_list(info["name"]).is_empty():
			return true
	return false

# 編輯畫面持續請求重畫，讓虛線跟著訊號連接的變化即時更新
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

# 編輯畫面用：畫一個方塊和「遊戲流程」字樣讓學員看得到、點得到，再畫每個訊號連接的虛線
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-6, -6, 12, 12), _COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(9, 4), "遊戲流程", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _COLOR)
	for info in get_script().get_script_signal_list():
		SignalLines.draw(self, Signal(self, info["name"]))
