@tool
extends Label

# 顯示一個數值的數字：選要顯示哪一個（金幣、血量、遊玩時間、體力…），值變了自己更新，不用連線。
# 字型、顏色、大小、對齊都用 Label 原本的屬性改；放在 UIRoot 底下時跟著整套的字型與配色。
# 編輯器裡用假資料顯示，方便擺位置。

## 數值變多時發出（例如金幣 +1），可以連到 Juice 的 play() 播音效
signal value_increased
## 數值變少時發出（例如扣血）
signal value_decreased
## 數值變化時發出，帶著變化前、變化後的值
signal amount_changed(old_value: float, new_value: float)

## 要顯示哪一個數值：選「數值」再打名稱（例如金幣），或直接選內建的（遊玩時間、死亡次數、體力…）
@export_enum("數值", "遊玩時間", "死亡次數", "體力", "存活倒數", "脫殼次數", "時間軸") var source: int = 0:
	set(value):
		source = value
		notify_property_list_changed()
		_refresh_editor()
## 數值的名稱，例如「金幣」「血量」（頭尾空白、全形字會自動整理；打錯字時會提醒）
@export var kind: String = "金幣":
	set(value):
		kind = value
		_refresh_editor()
## 怎麼顯示：數字（12）、數字／上限（3/5）、分:秒（1:05，適合時間）、只有名字（當標題用，例如血條前面的「血量」）
@export_enum("數字", "數字/上限", "分:秒", "只有名字") var format: int = 0:
	set(value):
		format = value
		_refresh_editor()
## 數字前面加上名字，例如「金幣：12」
@export var show_name: bool = true:
	set(value):
		show_name = value
		_refresh_editor()
## 數值變化時閃一下（變多閃白、變少閃紅）
@export var flash_on_change: bool = false
## 數值變少時左右抖一下
@export var shake_on_decrease: bool = false

const _FORMAT_NUMBER := 0
const _FORMAT_OF_MAX := 1
const _FORMAT_CLOCK := 2
const _FORMAT_NAME_ONLY := 3

var _binding: HudBinding = null

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

# HudBinding 通知：值或上限變了，重新排字；found 為 false 表示找不到來源，顯示「?」
func _on_hud_value(value: float, max_value: float, found: bool) -> void:
	text = _compose(_binding.format_number(value) if found else "?", value, max_value, found)

# HudBinding 通知：值真的變了，發訊號、閃一下抖一下
func _on_hud_changed(old_value: float, new_value: float) -> void:
	var increased := new_value > old_value
	_binding.play_change(increased, flash_on_change, shake_on_decrease)
	amount_changed.emit(old_value, new_value)
	if increased:
		value_increased.emit()
	else:
		value_decreased.emit()

# 依格式組出要顯示的文字
func _compose(number_text: String, value: float, max_value: float, found: bool) -> String:
	if format == _FORMAT_NAME_ONLY:
		return _display_name()
	var body := number_text
	if found and format == _FORMAT_OF_MAX and max_value > 0.0:
		body = "%s/%s" % [number_text, _binding.format_number(max_value) if _binding else str(roundi(max_value))]
	elif found and format == _FORMAT_CLOCK:
		var total := maxi(int(value), 0)
		body = "%d:%02d" % [floori(total / 60.0), total % 60]
	if not show_name:
		return body
	return "%s：%s" % [_display_name(), body]

# 名字：數值用 ValueSettings 的 display_name（遊戲中才讀得到），內建來源用來源名稱
func _display_name() -> String:
	var source_name := HudBinding.source_name_of(source, kind)
	if not Engine.is_editor_hint() and source == HudBinding.SOURCE_VALUE:
		return Stats.get_display_name(source_name)
	return source_name

# 編輯器裡用假資料重畫，並更新黃色驚嘆號
func _refresh_editor() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	text = _compose("12", 65.0, 20.0, true)
	update_configuration_warnings()
