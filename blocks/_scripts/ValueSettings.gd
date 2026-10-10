@tool
extends Node

# 場景設定節點：一個場景可以放一個或多個，各自對應一個數值種類，
# 拿來覆蓋 Stats 的預設初始值、上限、畫面上顯示的名字，以及要不要出現在 HUD。沒放的種類維持 Stats 原本的預設行為。

## 這一筆設定要套用到哪個數值種類，例如「血量」「金幣」（頭尾空白、全形字會自動整理；打錯字時輸出面板會提醒）。
## 「血量」是特殊名稱（歸零會死），不能改；想改畫面上的名字請用 display_name
@export var kind: String = "血量":
	set(value):
		kind = value
		update_configuration_warnings()

## 畫面左上角顯示的名字，例如把「血量」顯示成「HP」；空白就顯示 kind 的名字
@export var display_name: String = ""

## 初始值
@export_range(0, 999) var start_value: int = 3

## 上限，0 代表不限
@export_range(0, 999) var max_value: int = 3

## 打勾：一開場就顯示在畫面左上角；不勾：永遠不顯示
@export var show_in_hud: bool = true

## 死亡重生時要不要退回踩重生點當下的數值；關閉的話死亡完全不影響這個數值
## （例如累計分數、存活時間這種不該被重置的東西）
@export var reset_on_death: bool = true

# 看起來是想指血量、但不是「血量」的名字（比對前轉小寫）
const _HEALTH_LOOKALIKES := ["hp", "health", "生命", "生命值", "血", "血條", "血值", "血量值"]

# 場景一進樹就套用設定，搶在同一個場景其他節點的 _ready() 用到這個數值之前生效；名稱先整理再套用
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	if _looks_like_health():
		push_warning("[數值設定] %s" % _health_lookalike_message())
		printerr("⚠ [數值設定] %s" % _health_lookalike_message())
	Stats.configure(NameCheck.clean(kind), start_value, max_value, show_in_hud, reset_on_death,
		display_name.strip_edges())

# 編輯器裡就看得到：kind 打成 HP、生命這類字，其實沒有設定到血量
func _get_configuration_warnings() -> PackedStringArray:
	if _looks_like_health():
		return PackedStringArray([_health_lookalike_message()])
	return PackedStringArray()

# kind 是不是看起來想指血量、但不是「血量」
func _looks_like_health() -> bool:
	return NameCheck.clean(kind).to_lower() in _HEALTH_LOOKALIKES

# 把 kind 打成血量的別名時的提醒文字
func _health_lookalike_message() -> String:
	return "kind 打成「%s」，這會變成一個新的數值，不是血量（受傷扣的、歸零會死的是「血量」）。" % NameCheck.clean(kind) 		+ "請把 kind 改回「血量」；想讓畫面上顯示「%s」，把它打在 display_name" % NameCheck.clean(kind)

# 回傳這一筆設定的數值種類名稱（整理過），道具、門檢查打錯字時用來對照
func get_value_kind() -> String:
	return NameCheck.clean(kind)
