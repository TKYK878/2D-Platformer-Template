@tool
extends TextureProgressBar

# 顯示一個數值的條（血條、體力條）：選要顯示哪一個，值變了自己更新，不用連線。
# 想換成自己的圖：把底圖拖進 Textures 的 Under、填滿的圖拖進 Progress（建議勾 Nine Patch Stretch 讓圖跟著拉長）；
# 填滿方向用 Fill Mode 選。沒放圖時畫成預設的樣子（跟原本的血條一樣），配色跟著 UIRoot。
# 編輯器裡用假資料（半滿）顯示，方便擺位置。

## 數值變多時發出（例如補血），可以連到 Juice 的 play() 播音效
signal value_increased
## 數值變少時發出（例如扣血）
signal value_decreased
## 數值變化時發出，帶著變化前、變化後的值
signal amount_changed(old_value: float, new_value: float)

## 要顯示哪一個數值：選「數值」再打名稱（例如血量），或直接選內建的（體力、存活倒數…）
@export_enum("數值", "遊玩時間", "死亡次數", "體力", "存活倒數", "脫殼次數", "時間軸") var source: int = 0:
	set(value):
		source = value
		notify_property_list_changed()
		_refresh_editor()
## 數值的名稱，例如「血量」（頭尾空白、全形字會自動整理；打錯字時會提醒）
@export var kind: String = "血量":
	set(value):
		kind = value
		_refresh_editor()
## 數值變化時閃一下（變多閃白、變少閃紅）
@export var flash_on_change: bool = false
## 數值變少時左右抖一下
@export var shake_on_decrease: bool = false

var _binding: HudBinding = null
var _found: bool = true
var _seen_max: float = 1.0   # 沒有上限的數值用「出現過的最大值」當滿格

# 條要能顯示小數（體力是秒數）；編輯器裡畫半滿的假資料，遊戲中接上顯示來源
func _ready() -> void:
	step = 0.0
	if Engine.is_editor_hint():
		_refresh_editor()
		return
	_binding = HudBinding.new(self)
	_binding.start(source, kind)

# 只在 source 選「數值」時顯示 kind
func _validate_property(property: Dictionary) -> void:
	if property.name == "kind" and source != HudBinding.SOURCE_VALUE:
		property.usage &= ~PROPERTY_USAGE_EDITOR

# 編輯器裡就看得到設定錯誤：名稱空白、放在關卡裡時關卡找不到這個數值
func _get_configuration_warnings() -> PackedStringArray:
	return get_hud_warnings(get_tree().edited_scene_root if is_inside_tree() else null)

# 給 UIRoot 收集用：這個零件在 scene_root 這個場景裡有哪些設定錯誤
func get_hud_warnings(scene_root: Node) -> PackedStringArray:
	return HudBinding.editor_warnings(source, kind, scene_root)

# HudBinding 通知：值或上限變了；沒有上限時用出現過的最大值當滿格；找不到來源時畫空條加「?」
func _on_hud_value(new_value: float, new_max: float, found: bool) -> void:
	_found = found
	_seen_max = maxf(_seen_max, new_value)
	max_value = new_max if new_max > 0.0 else _seen_max
	value = new_value if found else 0.0
	queue_redraw()

# HudBinding 通知：值真的變了，發訊號、閃一下抖一下
func _on_hud_changed(old_value: float, new_value: float) -> void:
	var increased := new_value > old_value
	_binding.play_change(increased, flash_on_change, shake_on_decrease)
	amount_changed.emit(old_value, new_value)
	if increased:
		value_increased.emit()
	else:
		value_decreased.emit()

# 沒放圖時畫預設的條：用 ProgressBar 的底與填滿樣式（UIRoot 的配色會改到這兩個），照 Fill Mode 的方向填
func _draw() -> void:
	if texture_progress != null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(get_theme_stylebox("background", "ProgressBar"), rect)
	var ratio := 0.0 if max_value <= min_value else clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)
	if ratio > 0.0:
		draw_style_box(get_theme_stylebox("fill", "ProgressBar"), _fill_rect(rect, ratio))
	if not _found:
		var font := get_theme_font("font", "Label")
		var font_size := get_theme_font_size("font_size", "Label")
		var text_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2((size.x - text_size.x) / 2.0, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
		draw_string(font, pos.floor(), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("font_color", "Label"))

# 依 Fill Mode 算出填滿的那一塊（左到右、右到左、上到下、下到上；其他模式當成左到右）
func _fill_rect(rect: Rect2, ratio: float) -> Rect2:
	match fill_mode:
		FILL_RIGHT_TO_LEFT:
			var w := rect.size.x * ratio
			return Rect2(rect.size.x - w, 0.0, w, rect.size.y)
		FILL_TOP_TO_BOTTOM:
			return Rect2(0.0, 0.0, rect.size.x, rect.size.y * ratio)
		FILL_BOTTOM_TO_TOP:
			var h := rect.size.y * ratio
			return Rect2(0.0, rect.size.y - h, rect.size.x, h)
		_:
			return Rect2(0.0, 0.0, rect.size.x * ratio, rect.size.y)

# UIRoot 換了配色或字型：重畫預設的條
func _on_ui_root_changed(_root: UIRoot) -> void:
	queue_redraw()

# 編輯器裡用半滿的假資料重畫，並更新黃色驚嘆號
func _refresh_editor() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	max_value = 100.0
	value = 50.0
	queue_redraw()
	update_configuration_warnings()
