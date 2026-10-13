@tool
extends CanvasLayer

# 瞇眼測試（開發用的工具）：拖進關卡，遊玩中按 F1 把整個畫面變糊（像瞇著眼睛看），再按一次恢復。
# 用來檢查玩家、危險物、目標是不是一眼分得出來：變糊之後還分得出來，大塊的形狀和對比就夠。
# style 選「模糊＋黑白」會再拿掉顏色，只看明暗（顏色很像的東西靠明暗也要分得出來）。
# 只蓋在畫面上，不影響遊戲；暫停中也能用。只在編輯器裡按 F5／F6 時有效，匯出的遊戲裡會自己拿掉。

## 按哪個鍵開關
@export_enum("F1", "F2", "Tab", "G") var key: int = 0:
	set(value):
		key = value
		_warned_taken = false
		_update_hint()
## 怎麼看：只模糊（像瞇眼睛）、模糊＋黑白（只看明暗，不看顏色）
@export_enum("只模糊", "模糊＋黑白") var style: int = 0:
	set(value):
		style = value
		if _overlay != null:
			(_overlay.material as ShaderMaterial).set_shader_parameter("gray", value == 1)
## 模糊多少：越大越糊
@export_range(1.0, 4.0, 0.5) var strength: float = 2.0:
	set(value):
		strength = value
		if _overlay != null:
			(_overlay.material as ShaderMaterial).set_shader_parameter("blur", value)

const _KEYS := [KEY_F1, KEY_F2, KEY_TAB, KEY_G]
const _KEY_NAMES := ["F1", "F2", "Tab", "G"]
const _SHADER := preload("res://skins/_scripts/SquintTest.gdshader")

var _overlay: ColorRect = null
var _hint: Label = null
var _on := false
var _warned_taken := false

# 建全畫面的灰階模糊層和提示字（平常藏起來）；匯出的遊戲裡、或已經有一個的話自己拿掉
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not OS.has_feature("editor"):
		queue_free()
		return
	var first := get_tree().get_first_node_in_group("squint_test")
	if first != null:
		var message := "關卡裡已經有一個瞇眼測試「%s」，「%s」用不到，先拿掉" % [first.name, name]
		push_warning("[瞇眼測試] %s" % message)
		printerr("⚠ [瞇眼測試] %s" % message)
		queue_free()
		return
	add_to_group("squint_test")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _SHADER
	material.set_shader_parameter("blur", strength)
	material.set_shader_parameter("gray", style == 1)
	_overlay.material = material
	_overlay.visible = false
	add_child(_overlay)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.position = Vector2(4, 4)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.visible = false
	add_child(_hint)
	_update_hint()
	print("[瞇眼測試] 已啟用：遊玩中按 %s 開關" % _KEY_NAMES[key])

# 按下選好的鍵：開關；這個鍵已經被別的東西用掉時讓給它
func _unhandled_input(event: InputEvent) -> void:
	if _overlay == null or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if (event as InputEventKey).physical_keycode != _KEYS[key]:
		return
	if _is_key_taken():
		return
	get_viewport().set_input_as_handled()
	set_on(not _on)

# 打開或關掉瞇眼測試
func set_on(on: bool) -> void:
	if _overlay == null:
		return
	_on = on
	_overlay.visible = on
	_hint.visible = on

# 現在是不是開著
func is_on() -> bool:
	return _on

# 提示字跟著選的鍵換
func _update_hint() -> void:
	if _hint != null:
		_hint.text = "瞇眼測試中（%s 關掉）" % _KEY_NAMES[key]

# 選的鍵是不是已經被學員或組件拿去用了（Godot 內建的 ui_ 動作不算）；第一次發現時提醒
func _is_key_taken() -> bool:
	var code: Key = _KEYS[key]
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and ((e as InputEventKey).physical_keycode == code or (e as InputEventKey).keycode == code):
				if not _warned_taken:
					_warned_taken = true
					push_warning("[瞇眼測試] %s 已經被別的東西用掉了（%s），瞇眼測試不搶" % [_KEY_NAMES[key], action])
					printerr("⚠ [瞇眼測試] %s 已經被別的東西用掉了（%s），瞇眼測試不搶：在 SquintTest 的 key 換一個鍵" % [_KEY_NAMES[key], action])
				return true
	return false
