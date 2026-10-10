extends Node

# 顯示來源：所有可以被 HUD 顯示的數值都從這裡讀，HUD 零件只認這一個入口。
# Stats 的每個數值種類自動成為來源（名稱就是種類名稱）；遊玩時間、死亡次數由這裡自己算；
# 機制卡、零件想讓自己的數值能被顯示，就呼叫 publish()。
# 學員的 HUD 有顯示某個來源時會 claim() 它，預設 UI 顯示前先問 is_claimed()，被認領的就讓位。

const PLAY_TIME := "遊玩時間"
const DEATHS := "死亡次數"
const STAMINA := "體力"           # Mechanic_Stamina 公開
const SURVIVAL := "存活倒數"      # Mechanic_SurvivalTimer 公開
const MOLT := "脫殼次數"          # Extra_Molt 公開（目前選中的殼還能脫幾次）
const TIMELINE := "時間軸"        # Timeline 公開（場景裡第一個時間軸的秒數）

signal source_changed(source_name: String)
# 有來源被認領或放掉時發出，預設 HUD 用它決定哪幾列要讓位
signal claims_changed

var _values: Dictionary = {}      # 來源名稱 -> float
var _max_values: Dictionary = {}  # 來源名稱 -> float，0 代表沒有上限
var _claims: Dictionary = {}      # 來源名稱 -> Array[Node]，認領這個來源的 HUD 零件
var _play_time: float = 0.0

# 接上 Stats 與死亡事件，先把已經有的數值種類、遊玩時間、死亡次數公開出去
func _ready() -> void:
	Stats.value_changed.connect(func(kind: String, _old: int, _new: int): _publish_stat(kind))
	Stats.configured.connect(_publish_stat)
	Events.player_died.connect(_on_player_died)
	for kind in Stats.get_known_kinds():
		_publish_stat(kind)
	publish(PLAY_TIME, 0.0)
	publish(DEATHS, 0.0)

# 累計遊玩時間（遊戲暫停時這個節點跟著停，所以暫停中不算）
func _process(delta: float) -> void:
	_play_time += delta
	publish(PLAY_TIME, _play_time)

# 公開一個可以被 HUD 顯示的數值（機制卡、零件用這個），max_value 0 代表沒有上限
func publish(source_name: String, value: float, max_value: float = 0.0) -> void:
	if _values.get(source_name) == value and _max_values.get(source_name) == max_value:
		return
	_values[source_name] = value
	_max_values[source_name] = max_value
	source_changed.emit(source_name)

# 拿掉一個顯示來源（公開它的卡片、零件被拔掉時呼叫），綁著它的 HUD 零件會變成「找不到來源」
func remove_source(source_name: String) -> void:
	if not _values.has(source_name):
		return
	_values.erase(source_name)
	_max_values.erase(source_name)
	source_changed.emit(source_name)

# 讀取某個顯示來源目前的值，沒有這個來源就是 0
func get_value(source_name: String) -> float:
	return _values.get(source_name, 0.0)

# 讀取某個顯示來源的上限，0 代表沒有上限
func get_max_value(source_name: String) -> float:
	return _max_values.get(source_name, 0.0)

# 這個顯示來源有沒有人公開過，HUD 零件拿來提示「找不到這個名稱」
func has_source(source_name: String) -> bool:
	return _values.has(source_name)

# 目前所有顯示來源的名稱，找不到名稱時列出來給學員看
func get_source_names() -> Array:
	return _values.keys()

# 學員的 HUD 零件認領一個來源，表示「這個我來顯示」；零件真的離開場景時自動放掉
# （只是換位置，例如 UIRoot 自己移進 CanvasLayer，不算離開）
func claim(source_name: String, by: Node) -> void:
	var owners: Array = _claims.get(source_name, [])
	if by in owners:
		return
	owners.append(by)
	_claims[source_name] = owners
	var on_exit := _on_claimer_exiting.bind(source_name, by)
	if not by.tree_exiting.is_connected(on_exit):
		by.tree_exiting.connect(on_exit)
	claims_changed.emit()

# 這個來源有沒有被學員的 HUD 認領，預設 UI 顯示前先問這個，被認領的就不顯示
func is_claimed(source_name: String) -> bool:
	for n in _claims.get(source_name, []):
		if is_instance_valid(n) and n.is_inside_tree():
			return true
	return false

# 這一輪重新開始：遊玩時間、死亡次數歸零（過關畫面按 R 再玩一次時呼叫）
func reset_run() -> void:
	_play_time = 0.0
	publish(PLAY_TIME, 0.0)
	publish(DEATHS, 0.0)

# 把 Stats 某個數值種類的目前值與上限公開出去
func _publish_stat(kind: String) -> void:
	publish(kind, Stats.get_value(kind), Stats.get_max_value(kind))

# 玩家死掉：死亡次數加一
func _on_player_died() -> void:
	publish(DEATHS, get_value(DEATHS) + 1.0)

# 認領的零件離開場景樹：等下一幀再看，沒有回到樹上（被刪掉、被拿走）才放掉它的認領
func _on_claimer_exiting(source_name: String, by: Node) -> void:
	_check_release.call_deferred(source_name, by)

# 零件已經不在場景樹上就放掉它的認領（by 不標型別：零件可能已經被刪掉，被刪掉的節點傳不進 Node 型別的參數）
func _check_release(source_name: String, by) -> void:
	if is_instance_valid(by) and by.is_inside_tree():
		return
	var owners: Array = _claims.get(source_name, [])
	owners.erase(by)
	claims_changed.emit()
