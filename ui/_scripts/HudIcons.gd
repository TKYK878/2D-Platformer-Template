@tool
extends HBoxContainer

# 用一顆一顆的圖示顯示數值（愛心、鑰匙）：還有的畫「滿」的圖，扣掉的畫「空」的圖，值變了自己更新，不用連線。
# 把自己的圖拖進 full_icon／empty_icon；沒放圖時畫成小方塊，顏色跟著 UIRoot 的配色。
# 圖示之間的距離用 Theme Overrides → Constants → Separation 調。編輯器裡用假資料（3 滿 2 空）顯示。

## 數值變多時發出（例如補血），可以連到 Juice 的 play() 播音效
signal value_increased
## 數值變少時發出（例如扣血）
signal value_decreased
## 數值變化時發出，帶著變化前、變化後的值
signal amount_changed(old_value: float, new_value: float)

## 要顯示哪一個數值：選「數值」再打名稱（例如血量），或直接選內建的（死亡次數、脫殼次數…）
@export_enum("數值", "遊玩時間", "死亡次數", "體力", "存活倒數", "脫殼次數", "時間軸") var source: int = 0:
	set(value):
		source = value
		notify_property_list_changed()
		_refresh_editor()
## 數值的名稱，例如「血量」「鑰匙」（頭尾空白、全形字會自動整理；打錯字時會提醒）
@export var kind: String = "血量":
	set(value):
		kind = value
		_refresh_editor()
## 「還有」的圖示：從檔案系統把圖片拖進來，空白就畫小方塊
@export var full_icon: Texture2D:
	set(value):
		full_icon = value
		_rebuild_all()
## 「扣掉」的圖示：空白的話，有上限的數值畫暗色小方塊，或不畫（看 show_empty）
@export var empty_icon: Texture2D:
	set(value):
		empty_icon = value
		_rebuild_all()
## 要不要畫「扣掉」的圖示（例如 3 滿 2 空）；不勾的話只畫還有的
@export var show_empty: bool = true:
	set(value):
		show_empty = value
		_refresh_editor()
## 最多畫幾個圖示，數值比這個大時只畫這麼多
@export_range(1, 20) var max_icons: int = 10:
	set(value):
		max_icons = value
		_refresh_editor()
## 數值變化時閃一下（變多閃白、變少閃紅）
@export var flash_on_change: bool = false
## 數值變少時左右抖一下
@export var shake_on_decrease: bool = false

# 沒放圖時小方塊的大小與顏色（配色是「預設」時用這兩個顏色）
const _BOX_SIZE := Vector2(10, 10)
const _DEFAULT_FULL := Color(0.9, 0.25, 0.3)
const _DEFAULT_EMPTY := Color(0.25, 0.25, 0.28)

var _binding: HudBinding = null
var _full_count: int = 0
var _empty_count: int = 0
var _found: bool = true
var _full_color: Color = _DEFAULT_FULL
var _empty_color: Color = _DEFAULT_EMPTY

# 編輯器裡畫假資料；遊戲中接上顯示來源
func _ready() -> void:
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

# HudBinding 通知：值或上限變了，算出要畫幾個滿的、幾個空的
func _on_hud_value(value: float, max_value: float, found: bool) -> void:
	_show(floori(value), roundi(max_value), found)

# HudBinding 通知：值真的變了，發訊號、閃一下抖一下
func _on_hud_changed(old_value: float, new_value: float) -> void:
	var increased := new_value > old_value
	_binding.play_change(increased, flash_on_change, shake_on_decrease)
	amount_changed.emit(old_value, new_value)
	if increased:
		value_increased.emit()
	else:
		value_decreased.emit()

# UIRoot 換了配色：小方塊改用配色的顏色重畫
func _on_ui_root_changed(root: UIRoot) -> void:
	_full_color = root.get_palette_color("accent", _DEFAULT_FULL)
	_empty_color = root.get_palette_color("back", _DEFAULT_EMPTY)
	_rebuild_all()

# 依值與上限決定滿的、空的各幾個（總共不超過 max_icons），有變才重建
func _show(value: int, max_value: int, found: bool) -> void:
	var full := clampi(value, 0, max_icons)
	var empty := 0
	if show_empty and max_value > 0:
		empty = clampi(max_value, 0, max_icons) - full
	empty = maxi(empty, 0)
	if full == _full_count and empty == _empty_count and found == _found:
		return
	_full_count = full
	_empty_count = empty
	_found = found
	_rebuild_all()

# 清掉舊的圖示，照目前的數量重新排；找不到來源時只放一個「?」
func _rebuild_all() -> void:
	if not is_inside_tree():
		return
	for child in get_children(true):
		if child.get_meta("hud_icon", false):
			remove_child(child)
			child.queue_free()
	if not _found:
		var label := Label.new()
		label.text = "?"
		_add_icon(label)
		return
	for i in _full_count:
		_add_icon(_make_icon(full_icon, _full_color))
	for i in _empty_count:
		_add_icon(_make_icon(empty_icon, _empty_color))

# 做一個圖示：有圖就用圖（原本大小），沒圖就是一個小方塊
func _make_icon(texture: Texture2D, color: Color) -> Control:
	if texture != null:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		return rect
	var box := ColorRect.new()
	box.custom_minimum_size = _BOX_SIZE
	box.color = color
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return box

# 把圖示加成內部子節點：不會存進場景檔，也不會出現在場景樹上
func _add_icon(icon: Control) -> void:
	icon.set_meta("hud_icon", true)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon, false, Node.INTERNAL_MODE_BACK)

# 編輯器裡用假資料（3 滿 2 空）重畫，並更新黃色驚嘆號
func _refresh_editor() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_full_count = -1
	_show(3, 5, true)
	update_configuration_warnings()
