extends MechanicBase

# 子彈時間：按鍵讓整個世界慢下來幾秒，時間到自動恢復正常。
# 跟頓幀系統（autoload/HitStopManager.gd）一樣都會動到全域的 Engine.time_scale，
# 兩者理論上剛好同時觸發的話效果可能互相蓋掉——這是已知的小限制，備品庫卡優先
# 求簡單，沒有另外做排隊或整合。
# 備品庫卡，不在抽卡池裡，學員許願才拖給他。拖進 Player → Mechanics 底下就能用，
# 不用連任何線。

## 按哪一鍵觸發子彈時間
@export var key: Key = KEY_Q

## 時間變慢的倍率，數值越小越慢
@export_range(0.1, 0.8) var time_scale: float = 0.3

## 子彈時間可以持續幾秒（現實時間，不受變慢影響）
@export_range(0.5, 5.0) var duration: float = 2.0

## 世界變慢之後發出
signal started
## 世界恢復正常速度之後發出
signal ended

var _active: bool = false

# 綁子彈時間鍵
func _on_setup() -> void:
	InputRouter.warn_if_dangerous_key(key, "[子彈時間]")
	InputRouter.bind_key(self, key, InputRouter.PRESSED, _on_key_pressed)

# 正在進行中就不重複觸發；否則開始子彈時間
func _on_key_pressed() -> bool:
	if _active:
		return false
	_run_time_slow()
	return true

# 把時間變慢，過了 duration 秒（現實時間）後自動恢復正常
func _run_time_slow() -> void:
	_active = true
	Engine.time_scale = time_scale * HitStopManager.get_game_speed()
	started.emit()
	Events.mechanic_event.emit("Extra_TimeSlow", "started")
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = HitStopManager.get_game_speed()
	_active = false
	ended.emit()
	Events.mechanic_event.emit("Extra_TimeSlow", "ended")
