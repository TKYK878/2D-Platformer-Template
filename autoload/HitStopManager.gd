extends Node

# 頓幀單例：Engine.time_scale 是全域的，集中在這裡管理避免多處搶著改。
# 也管「遊戲速度」（作弊這類組件調的整體快慢）：頓幀、子彈時間結束後回到遊戲速度，不是固定回到 1。

const 時長上限 := 0.3

var _active: bool = false
var _speed_sources: Dictionary = {}   # 調遊戲速度的組件(Node) -> 倍率，好幾個同時調就乘起來

func _ready() -> void:
	Events.hitstop_requested.connect(_on_hitstop_requested)

func _on_hitstop_requested(duration: float) -> void:
	if _active:
		return
	var clamped_duration: float = clampf(duration, 0.0, 時長上限)
	if clamped_duration <= 0.0:
		return
	_active = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(clamped_duration, true, false, true).timeout
	Engine.time_scale = get_game_speed()
	_active = false

# 調整遊戲速度（1 = 正常、0.5 = 慢一半），作弊這類組件用這個；on 傳 false 就把這個組件調的拿掉
func set_game_speed(source: Node, on: bool, speed: float = 1.0) -> void:
	if on:
		_speed_sources[source] = speed
	else:
		_speed_sources.erase(source)
	if not _active:
		Engine.time_scale = get_game_speed()

# 回傳現在的遊戲速度（所有組件調的倍率乘起來，沒人調就是 1），頓幀、子彈時間結束時回到這個速度
func get_game_speed() -> float:
	var speed := 1.0
	for source in _speed_sources.keys():
		if is_instance_valid(source):
			speed *= _speed_sources[source]
		else:
			_speed_sources.erase(source)
	return speed
