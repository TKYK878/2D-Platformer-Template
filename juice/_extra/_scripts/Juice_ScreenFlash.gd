@tool
extends JuiceBase

# 全螢幕閃光：觸發時整個畫面蓋上一層顏色，再慢慢淡掉。拖進 Player → Juice 底下就能用，預設是受傷時閃紅。
# 不受頓幀影響（頓幀時畫面停住，閃光照樣淡掉）。

## 閃什麼顏色
@export_enum("白", "紅", "黃", "黑") var color: int = 1
## 一開始有多濃：0.1 = 淡淡一層，1 = 整個畫面看不到
@export_range(0.1, 1.0) var strength: float = 0.4
## 多久淡掉（秒）
@export_range(0.05, 1.0) var duration: float = 0.25

const _COLORS := [Color.WHITE, Color(1.0, 0.15, 0.15), Color(1.0, 0.9, 0.3), Color.BLACK]
# 蓋在遊戲畫面上，但在 Juice 總開關提示（100）底下
const _LAYER := 90

var _rect: ColorRect = null
var _tween: Tween = null

# 建立蓋住整個畫面的色塊，平常藏起來
func _on_setup() -> void:
	if _rect != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = _LAYER
	add_child(layer)
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	layer.add_child(_rect)

# 蓋上顏色，再淡掉
func _on_play() -> void:
	if _rect == null:
		return
	if _tween:
		_tween.kill()
	var c: Color = _COLORS[color]
	_rect.color = Color(c.r, c.g, c.b, clampf(strength * _trigger_power, 0.05, 1.0))
	_rect.visible = true
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_property(_rect, "color:a", 0.0, duration)
	_tween.tween_callback(func(): _rect.visible = false)

# 停掉閃到一半的光
func _on_reset() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if _rect:
		_rect.visible = false
