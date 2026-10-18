extends CanvasLayer

# 畫面上方的「作弊中」小字：整個關卡共用一個，作弊組件第一次要顯示時自己建出來。
# 每隔一小段時間問一次所有作弊組件現在要顯示什麼（get_label_text()），都沒有就藏起來。

const _GROUP := "cheat_label"
const _SOURCE_GROUP := "cheat_label_source"
const _REFRESH_SECONDS := 0.2

var _label: Label = null
var _timer: float = 0.0

# 場景裡還沒有「作弊中」小字就建一個（放進目前的關卡，換關時跟著消失）
static func ensure(tree: SceneTree) -> void:
	if tree.get_first_node_in_group(_GROUP) != null or tree.current_scene == null:
		return
	var layer := CanvasLayer.new()
	layer.set_script(load("res://cheats/_scripts/CheatLabel.gd"))
	tree.current_scene.add_child.call_deferred(layer)

# 建出置中的小字，暫停中也會更新
func _ready() -> void:
	add_to_group(_GROUP)
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.offset_top = 4.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_refresh()

# 每隔一小段時間更新一次
func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _REFRESH_SECONDS:
		_timer = 0.0
		_refresh()

# 問所有作弊組件要顯示的字，一個一行
func _refresh() -> void:
	var lines := PackedStringArray()
	for source in get_tree().get_nodes_in_group(_SOURCE_GROUP):
		var text: String = source.get_label_text()
		if text != "":
			lines.append(text)
	_label.text = "\n".join(lines)
	_label.visible = not lines.is_empty()
