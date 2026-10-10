extends Node

# 全域數值系統：數值種類由學員自己決定名稱（字串），第一次用到某個名稱時自動出現，不用先宣告。
# 機制卡與零件透過這裡讀寫數值，不要自己存狀態。這裡只管數值本身，畫面怎麼顯示是 StatsHud 的事，
# 它訂閱 value_changed 訊號自己同步，這裡不知道也不在意有沒有人在聽。

## 血量是唯一有特殊意義的種類名稱：歸零時 Player 會死亡（見 player/Player.gd 的 take_damage）
const HEALTH_KIND := "血量"

signal value_changed(kind: String, old_value: int, new_value: int)
# ValueSettings 套用設定之後發出，HUD 用它決定要不要一開場就顯示這個數值
signal configured(kind: String)

var _values: Dictionary = {}       # kind(String) -> int
var _max_values: Dictionary = {}   # kind(String) -> int，0 代表不限
var _known_kinds: Array[String] = []
var _hud_visible: Dictionary = {}  # kind(String) -> bool，沒設定過的種類預設 true
var _reset_on_death: Dictionary = {}  # kind(String) -> bool，沒設定過的種類預設 true
var _display_names: Dictionary = {}   # kind(String) -> String，畫面上顯示的名字，沒設定過就顯示種類名稱

# 血量是系統內建的預設種類，其他種類都是第一次用到才出現，初始 0、不限。
# 用 has() 檢查而不是直接覆蓋：遊戲第一次啟動時，主場景裡 ValueSettings 的 _enter_tree
# 會搶在這個 _ready 之前執行（見 ValueSettings.gd 註解），已經套用的設定不能被這裡蓋掉。
func _ready() -> void:
	if not _values.has(HEALTH_KIND):
		_values[HEALTH_KIND] = 3
	if not _max_values.has(HEALTH_KIND):
		_max_values[HEALTH_KIND] = 3
	if HEALTH_KIND not in _known_kinds:
		_known_kinds.append(HEALTH_KIND)

# 增加數值，amount 給負數就是減少；會被夾在 0 到上限之間（上限 0 代表不限）
func add(kind: String, amount: int) -> void:
	_check_typo(kind)
	var old_value: int = _values.get(kind, 0)
	var new_value: int = old_value + amount
	var max_value: int = _max_values.get(kind, 0)
	if max_value > 0:
		new_value = min(new_value, max_value)
	new_value = max(new_value, 0)
	if new_value == old_value:
		return
	_values[kind] = new_value
	value_changed.emit(kind, old_value, new_value)
	Events.value_changed.emit(kind, old_value, new_value)
	if kind == HEALTH_KIND and new_value <= 0:
		_kill_player()

# 場景設定節點 ValueSettings 用這個套用初始值、上限、要不要顯示在 HUD、死亡要不要退回重生點、畫面上顯示的名字（空白＝種類名稱），
# 搶在同場景其他節點用到這個數值之前生效（ValueSettings 在 _enter_tree 呼叫，比一般 _ready 早）
func configure(kind: String, start_value: int, max_value: int, show_in_hud: bool, reset_on_death: bool = true,
		display_name: String = "") -> void:
	_check_typo(kind)
	_max_values[kind] = max_value
	var clamped := start_value
	if max_value > 0:
		clamped = min(clamped, max_value)
	clamped = max(clamped, 0)
	_values[kind] = clamped
	_hud_visible[kind] = show_in_hud
	_reset_on_death[kind] = reset_on_death
	_display_names[kind] = display_name
	configured.emit(kind)

# 查詢目前數值
func get_value(kind: String) -> int:
	_check_typo(kind)
	return _values.get(kind, 0)

# 查詢上限，0 代表不限；HUD 之類的畫面組件要知道滿條在哪裡時用這個
func get_max_value(kind: String) -> int:
	return _max_values.get(kind, 0)

# 檢查目前數值是不是至少有 n
func has_at_least(kind: String, n: int) -> bool:
	return get_value(kind) >= n

# 數值足夠就扣掉並回傳 true，不夠就什麼都不做並回傳 false
func consume(kind: String, n: int) -> bool:
	if not has_at_least(kind, n):
		return false
	add(kind, -n)
	return true

# 查詢某個種類是否允許顯示在 HUD，沒被 ValueSettings 設定過的種類預設允許
func is_hud_visible(kind: String) -> bool:
	return _hud_visible.get(kind, true)

# 查詢某個種類在畫面上要顯示的名字，ValueSettings 沒設定 display_name 就是種類名稱本身
func get_display_name(kind: String) -> String:
	var shown: String = _display_names.get(kind, "")
	return shown if shown != "" else kind

# 查詢某個種類死亡時要不要退回重生點當下的數值，沒被 ValueSettings 設定過的種類預設要
func is_reset_on_death(kind: String) -> bool:
	return _reset_on_death.get(kind, true)

# 直接把某個種類設成指定的值（一樣會被夾在 0 到上限之間），重生記憶還原進度用這個
func set_value(kind: String, value: int) -> void:
	add(kind, value - get_value(kind))

# 把某個種類補滿到上限；上限 0（不限）的話這個函式不會做任何事
func refill(kind: String) -> void:
	var max_value := get_max_value(kind)
	if max_value > 0:
		set_value(kind, max_value)

# 查詢目前用過的所有數值種類名稱，重生記憶抓「除了血量以外全部種類」時用這個
func get_known_kinds() -> Array[String]:
	return _known_kinds.duplicate()

# 血量歸零時呼叫，找到場景裡的 Player 讓它死亡；用 group 找，不記節點路徑
func _kill_player() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("kill"):
			p.kill()

# 第一次看到這個名稱時，跟已經用過的名稱比對，太像但不一樣就印警告，抓可能的打錯字
func _check_typo(kind: String) -> void:
	if kind in _known_kinds:
		return
	var similar := NameCheck.find_similar(kind, _known_kinds)
	if similar != "":
		push_warning("[Stats] 數值種類「%s」跟已經用過的「%s」很像，是不是打錯字了？" % [kind, similar])
	_known_kinds.append(kind)
