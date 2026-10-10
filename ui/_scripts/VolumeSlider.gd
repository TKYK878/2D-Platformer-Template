@tool
extends HSlider

# 音量拉桿：從下拉選單選要調哪一條音量，拉了就生效，不用連任何線。
# 跟預設暫停選單的拉桿同一套存檔（user://settings.cfg），下次開遊戲還是一樣；調音效時會播一下試聽音效。
# 右邊會顯示百分比（不想要就取消勾選 show_percent）。

## 要調哪一條音量
@export_enum("主音量", "音效", "音樂") var bus: int = 0:
	set(value):
		bus = value
		_update_percent()
## 要不要在拉桿右邊顯示百分比
@export var show_percent: bool = true:
	set(value):
		show_percent = value
		_update_percent()

const _BUS_NAMES := ["Master", "SFX", "BGM"]
const _PERCENT_GAP := 4.0

var _percent: Label = null
var _loading: bool = false

# 建百分比文字；遊戲中讀回現在的音量，拉動時改音量；暫停中也要拉得動
func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	_percent = Label.new()
	_percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_percent, false, Node.INTERNAL_MODE_BACK)
	resized.connect(_place_percent)
	_place_percent()
	if not Engine.is_editor_hint():
		process_mode = Node.PROCESS_MODE_ALWAYS
		_loading = true
		value = PauseMenu.get_volume(_BUS_NAMES[bus])
		_loading = false
		value_changed.connect(_on_value_changed)
	value_changed.connect(_update_percent.unbind(1))
	_update_percent()

# 拉桿拉動：改音量並存檔
func _on_value_changed(new_value: float) -> void:
	if not _loading:
		PauseMenu.set_volume(_BUS_NAMES[bus], new_value)

# 百分比文字放在拉桿右邊、上下置中
func _place_percent() -> void:
	if _percent == null:
		return
	_percent.reset_size()
	_percent.position = Vector2(size.x + _PERCENT_GAP, floorf((size.y - _percent.size.y) / 2.0))

# 更新百分比的字
func _update_percent() -> void:
	if _percent == null:
		return
	_percent.visible = show_percent
	_percent.text = "%d%%" % roundi(value * 100.0)
	_place_percent()
