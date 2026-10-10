@tool
extends JuiceBase

# 閃色：觸發時角色一閃一閃變色，閃完回到原本的顏色。拖進 Player → Juice 底下就能用，預設是受傷時閃紅。
# 顏色是疊在角色原本的顏色上（相乘），跟越跑越快這類會改顏色的卡一起用也不會互相蓋掉。
# 掛了好幾個閃色時，預設後閃的會停掉先閃的（例如閃黃閃到一半死掉，直接換成閃紅，不會兩個顏色混在一起）。

## 閃什麼顏色。白色是變亮，角色圖本身是純白的話看不出來
@export_enum("白", "紅", "黃", "黑") var color: int = 1
## 全部閃完要多久（秒）
@export_range(0.05, 1.0) var duration: float = 0.4
## 總共閃幾次
@export_range(1, 6) var count: int = 3
## 勾選時，開始閃的時候停掉其他還在閃的閃色，只看得到這個顏色；不勾的話顏色會跟其他閃色混在一起
@export var stop_others: bool = true

# 每個選項實際疊上去的顏色：白色超過 1 讓顏色變亮
const _COLORS := [Color(2.5, 2.5, 2.5), Color(1.0, 0.25, 0.25), Color(1.0, 1.0, 0.3), Color(0.1, 0.1, 0.1)]

var _time: float = 0.0
var _flashing: bool = false

# 場景裡所有的閃色，開始閃時用來停掉別的
static var _all: Array = []

# 平常不用每幀更新，播放時才開；記進閃色清單
func _on_setup() -> void:
	set_process(false)
	if self not in _all:
		_all.append(self)

# 拔掉組件時從閃色清單拿掉
func _exit_tree() -> void:
	super()
	_all.erase(self)

# 回傳現在是不是正在閃（還沒閃完）
func _is_flashing() -> bool:
	return is_processing()

# 從頭開始閃；勾了 stop_others 就先把同一個角色身上其他還在閃的閃色清掉
func _on_play() -> void:
	if stop_others:
		for other in _all:
			if other != self and is_instance_valid(other) and other.player == player and other._is_flashing():
				other.clear()
	_time = 0.0
	_flashing = false
	set_process(true)
	_update()

# 停掉閃到一半的效果
func _on_reset() -> void:
	set_process(false)
	_flashing = false

# 每幀前進時間，更新現在是亮還是暗
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_update()

# 依經過的時間決定這一刻要不要疊上顏色：每一次閃分成前半有顏色、後半沒顏色；閃完就撤掉
func _update() -> void:
	if not is_instance_valid(player):
		return
	if _time >= duration:
		set_process(false)
		_flashing = false
		player.clear_juice(self)
		return
	var on := int(_time / (duration / count) * 2.0) % 2 == 0
	if on == _flashing:
		return
	_flashing = on
	player.set_juice_tint(self, _COLORS[color] if on else Color.WHITE)
