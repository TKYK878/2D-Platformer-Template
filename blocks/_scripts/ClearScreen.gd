extends CanvasLayer

# 過關畫面：拖進關卡就生效，不用連任何線。終點、存活計時卡這類東西發出過關事件時自動跳出來，
# 遊戲暫停，顯示「過關！」、用了幾秒、死了幾次、製作者自己寫的一行字；按 R 整關重來再玩一次。
# 也可以用 activate 讓別的零件的訊號叫出來（例如打倒魔王就過關）。
# 畫面用 ui/templates/ClearScreenTemplate.tscn 範本；關卡裡有學員自己的過關畫面（UISettings 欄位或直接放進關卡）就改顯示那一個。
# 要顯示什麼（秒數、死亡次數、製作者的話）照這裡的欄位，畫面裡的 ClearStat 零件會跟著。

## 顯示從開場（或上一次再玩一次）到過關用了幾秒
@export var show_time: bool = true

## 顯示這一輪死了幾次
@export var show_deaths: bool = true

## 過關畫面最下面多顯示一行字，例如「感謝遊玩！」「製作：小明」；空白就不顯示（這一格可以打字）
@export var message: String = ""

const _TEMPLATE := preload("res://ui/templates/ClearScreenTemplate.tscn")

var _showing: bool = false
var _default_root: Control = null   # 預設的範本畫面（第一次過關時才生）
var _shown: Control = null          # 現在顯示中的畫面

## 顯示過關畫面（已經在顯示就不重複）
func activate() -> void:
	if _showing:
		return
	_showing = true
	_shown = _pick_screen()
	_refresh_stats(_shown)
	_shown.visible = true
	get_tree().paused = true
	print("[過關畫面] 過關！用了 %.1f 秒、死了 %d 次，按 R 再玩一次" % [get_time(), get_deaths()])

# 讀這一輪用了幾秒，過關畫面的「用了幾秒」用這個
func get_time() -> float:
	return HudData.get_value(HudData.PLAY_TIME)

# 讀這一輪死了幾次，過關畫面的「死了幾次」用這個
func get_deaths() -> int:
	return int(HudData.get_value(HudData.DEATHS))

# 讀製作者的話（去掉頭尾空白），空白就是不顯示
func get_message() -> String:
	return message.strip_edges()

# 加入群組（讓終點、重生記憶知道場景裡有過關畫面），接上過關事件；暫停時也要能收按鍵
func _ready() -> void:
	add_to_group("clear_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	Events.level_cleared.connect(activate)
	if get_tree().get_nodes_in_group("clear_screen").size() > 1:
		push_warning("[過關畫面] 場景裡有不只一個 ClearScreen，會疊在一起")
		printerr("⚠ [過關畫面] 場景裡有不只一個 ClearScreen，%s 可以刪掉" % name)

# 顯示中按 R（restart 動作）：關掉畫面、解除暫停、整關重來
func _unhandled_input(event: InputEvent) -> void:
	if not _showing or not event.is_action_pressed("restart"):
		return
	get_viewport().set_input_as_handled()
	_play_again()

# 再玩一次：時間、死亡次數歸零，請重生處理者整關重來；終點恢復成還沒踩過
func _play_again() -> void:
	_showing = false
	if is_instance_valid(_shown):
		_shown.visible = false
	_shown = null
	get_tree().paused = false
	HudData.reset_run()
	get_tree().call_group("goal", "reset")
	var handler := get_tree().get_first_node_in_group("respawn_handler")
	if handler == null or not handler.has_method("restart_level_now"):
		print("[過關畫面] 場景裡沒有 RespawnHandler，沒辦法整關重來，只關掉過關畫面。想要重來就把 blocks/RespawnHandler.tscn 拖進關卡")
		return
	handler.restart_level_now()

# 這次要顯示哪個畫面：關卡裡有學員的過關畫面就用它，沒有就用預設範本（第一次才生，放在自己這一層）
func _pick_screen() -> Control:
	var custom := get_tree().get_first_node_in_group("custom_ui_%d" % UIRoot.KIND_CLEAR_SCREEN)
	if custom is Control and not custom.is_queued_for_deletion():
		return custom
	if _default_root == null:
		_default_root = _TEMPLATE.instantiate()
		_default_root.set_meta(HudBinding.DEFAULT_META, true)
		add_child(_default_root)
	return _default_root

# 通知畫面裡的 ClearStat 照這裡的欄位更新內容、決定要不要出現
func _refresh_stats(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("refresh_clear_stat"):
			child.refresh_clear_stat(self)
		_refresh_stats(child)
