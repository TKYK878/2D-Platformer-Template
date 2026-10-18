@tool
extends Control

# 手機按鈕套件：拖一個進關卡就有左、右、跳、暫停四顆手機按鈕擺好，不用連任何線。
# 想改某顆的位置、大小：對套件按右鍵 → 勾「可編輯的子節點」，再選那顆調。
# 想多一顆攻擊鍵：另外拖一顆 TouchButton 進關卡，「代表」選鍵盤按鍵。
# 遊戲開始時如果不在 CanvasLayer 底下（例如直接拖進關卡），會自己移進一個，固定在畫面上、不跟著鏡頭跑。

## 什麼時候顯示：只在手機、平板這類觸控裝置；一直顯示（在電腦上可以用滑鼠點來測）；
## 或摸到螢幕才出現（手指碰到螢幕就出現、改按鍵盤又藏起來，有觸控螢幕的筆電用鍵盤玩也不會擋畫面）
@export_enum("只在觸控裝置", "一直顯示", "摸到螢幕才出現") var show_on: int = 0
## 四顆按鈕看起來多透明，越小越透明（會蓋過每顆按鈕自己的 opacity）
@export_range(0.1, 1.0) var opacity: float = 0.5:
	set(value):
		opacity = value
		_apply_opacity()

const _BUTTON_SCRIPT := preload("res://ui/_scripts/TouchButton.gd")
const _LAYER := 5

var _hidden_by_student: bool = false   # 學員自己把「可見」取消勾

# 套用透明度；遊戲中檢查要不要顯示、移進 CanvasLayer
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_opacity()
	if Engine.is_editor_hint():
		return
	_hidden_by_student = not visible
	TouchSettings.changed.connect(_refresh_shown)
	_refresh_shown()
	_BUTTON_SCRIPT.print_hidden_reason(show_on, name)
	if not (get_parent() is CanvasLayer or get_parent() is Control):
		_move_to_layer.call_deferred()

# 照 show_on 和玩家現在用什麼裝置，決定整組要不要顯示（學員自己把「可見」取消勾的就一直藏著）
func _refresh_shown() -> void:
	visible = not _hidden_by_student and TouchSettings.should_show(show_on)

# 把套件的透明度套到底下每一顆手機按鈕
func _apply_opacity() -> void:
	for child in get_children():
		if child.get_script() == _BUTTON_SCRIPT:
			child.opacity = opacity

# 移進一個新的 CanvasLayer，之後固定在畫面上、不跟著鏡頭跑
func _move_to_layer() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "%sLayer" % name
	layer.layer = _LAYER
	parent.add_child(layer)
	reparent(layer, false)
