@tool
extends HBoxContainer

# 音量拉桿：從下拉選單選要調哪一條音量，拉了就生效，不用連任何線。
# 跟預設暫停選單的拉桿同一套存檔（user://settings.cfg），下次開遊戲還是一樣；調音效時會播一下試聽音效。
# 右邊會顯示百分比（不想要就取消勾選 show_percent）。拉桿和百分比排成一列，
# 放進選單的底框時整個寬度都算進去，百分比不會跑到框外面。

## 要調哪一條音量
@export_enum("主音量", "音效", "音樂") var bus: int = 0:
	set(value):
		bus = value
		_load_volume()
## 要不要在拉桿右邊顯示百分比
@export var show_percent: bool = true:
	set(value):
		show_percent = value
		_update_percent()

const _BUS_NAMES := ["Master", "SFX", "BGM"]
const _SLIDER_SIZE := Vector2(120, 12)
const _PREVIEW_VALUE := 0.8

var _slider: HSlider = null
var _percent: Label = null
var _loading: bool = false

# 建拉桿和百分比文字；遊戲中讀回現在的音量，拉動時改音量；暫停中也要拉得動
func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.05
	_slider.custom_minimum_size = _SLIDER_SIZE
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_slider, false, Node.INTERNAL_MODE_FRONT)
	_percent = Label.new()
	_percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_percent, false, Node.INTERNAL_MODE_BACK)
	if not Engine.is_editor_hint():
		process_mode = Node.PROCESS_MODE_ALWAYS
	_load_volume()
	_slider.value_changed.connect(_on_value_changed)

# 字型或字的大小換了：百分比的寬度重算
func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_update_percent()

# 讀回這條音量現在的值（編輯器裡用預覽值）
func _load_volume() -> void:
	if _slider == null:
		return
	_loading = true
	_slider.value = _PREVIEW_VALUE if Engine.is_editor_hint() else PauseMenu.get_volume(_BUS_NAMES[bus])
	_loading = false
	_update_percent()

# 拉桿拉動：改音量並存檔，更新百分比
func _on_value_changed(new_value: float) -> void:
	if not _loading and not Engine.is_editor_hint():
		PauseMenu.set_volume(_BUS_NAMES[bus], new_value)
	_update_percent()

# 更新百分比的字；寬度固定留「100%」的寬，拉動時版面不會跳
func _update_percent() -> void:
	if _percent == null:
		return
	_percent.visible = show_percent
	_percent.text = "%d%%" % roundi(_slider.value * 100.0)
	var font := _percent.get_theme_font("font")
	var font_size := _percent.get_theme_font_size("font_size")
	if font != null:
		_percent.custom_minimum_size.x = ceilf(font.get_string_size("100%", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
