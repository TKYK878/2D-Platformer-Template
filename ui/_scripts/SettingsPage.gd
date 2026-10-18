@tool
extends Control

# 設定頁：拖進標題畫面（或自己的暫停選單），平常藏著，按「打開設定」的 MenuAction 才出現，不用連任何線。
# 底下放好了三條音量、手機按鈕開關和「返回」鍵，想加別的（例如作弊的選單勾選框）就拖進 Center/Panel/List 底下。
# 編輯器裡也是藏著的，要改裡面的東西：點場景樹上 SettingsPage 旁邊的眼睛打開，改完再關起來（不關也沒關係，遊戲開始時會自己藏起來）。
# 開著的時候按 Esc 也會返回。

const _SCRIPT_PATH := "res://ui/_scripts/SettingsPage.gd"
const _MENU_ACTION_PATH := "res://ui/_scripts/MenuAction.gd"
# 編輯器裡每隔幾秒重新檢查一次有沒有「返回」鍵，學員拖進來之後黃色驚嘆號會跟著消失
const _WARNING_REFRESH_SECONDS := 1.0

var _opener: Control = null
var _warning_timer: float = 0.0

# 遊戲開始時一律先藏起來；暫停中也要按得到；所在的畫面被藏起來時（例如暫停選單關掉）自己也關掉
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("settings_page")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	visibility_changed.connect(_on_visibility_changed)
	if not _has_back_button():
		print("[設定頁] %s 裡沒有「返回」鍵，玩家只能按 Esc 回去。從 ui/ 拖一個 MenuAction 進來，action 選「返回」" % name)

# 打開設定頁，選取跳到第一個能選的東西（拉桿、按鈕）；opener 是按下「打開設定」的那顆按鈕，關掉時選取回到它
func open(opener: Control = null) -> void:
	_opener = opener
	visible = true
	_focus_first(self)

# 關掉設定頁，選取回到原本按「打開設定」的按鈕
func close() -> void:
	if not visible:
		return
	visible = false
	if is_instance_valid(_opener) and _opener.is_visible_in_tree():
		_opener.grab_focus()

# 回傳設定頁現在是不是開著
func is_open() -> bool:
	return is_visible_in_tree()

# 開著的時候按 Esc：關掉設定頁就好，不要讓暫停選單收到（不然會連選單一起關掉）
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

# 所在的畫面被藏起來了（例如暫停選單關掉）：設定頁也關掉，下次打開選單時不會還停在設定頁
func _on_visibility_changed() -> void:
	if visible and not is_visible_in_tree():
		visible = false

# 往下找第一個看得到、能選的東西（拉桿、按鈕、勾選框）先選起來，鍵盤、手把可以直接操作；
# 音量拉桿的 HSlider 是零件自己建的內部節點，所以連內部節點一起找
func _focus_first(node: Node) -> bool:
	for child in node.get_children(true):
		if child is Control and (child as Control).focus_mode == Control.FOCUS_ALL and (child as Control).is_visible_in_tree():
			(child as Control).grab_focus()
			return true
		if _focus_first(child):
			return true
	return false

# 底下有沒有 action 選「返回」的 MenuAction
func _has_back_button() -> bool:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var node_script: Script = node.get_script()
		if node != self and node_script != null and node_script.resource_path == _MENU_ACTION_PATH and node.action == node.ACTION_BACK:
			return true
		stack.append_array(node.get_children())
	return false

# 編輯器的黃色驚嘆號：沒有「返回」鍵
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not _has_back_button():
		warnings.append("設定頁裡沒有「返回」鍵，玩家只能按 Esc 回去：從 ui/ 拖一個 MenuAction 進 Center/Panel/List，action 選「返回」")
	return warnings

# 放進關卡的選單（看不到裡面的東西）時，警告由 UIRoot 收集起來顯示在最上層
func get_hud_warnings(_scene_root: Node) -> PackedStringArray:
	return _get_configuration_warnings()

# 編輯器裡每隔一段時間重新檢查黃色驚嘆號
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_warning_timer += delta
	if _warning_timer >= _WARNING_REFRESH_SECONDS:
		_warning_timer = 0.0
		update_configuration_warnings()

# 找出某個場景裡所有的設定頁（編輯器裡用腳本找，遊戲中也能用），MenuAction 檢查「打開設定」找不找得到用
static func find_in(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	if root == null:
		return found
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var node_script: Script = node.get_script()
		if node_script != null and node_script.resource_path == _SCRIPT_PATH:
			found.append(node)
		stack.append_array(node.get_children())
	return found
