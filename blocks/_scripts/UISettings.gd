@tool
extends Node

# 畫面設定：把自己改好的 HUD、暫停選單、過關畫面（從 ui/templates/ 的範本再製出來改的場景）從檔案系統拖進欄位，
# 遊戲開始時就換成自己的。欄位空白就用預設的樣子。
# 拖錯場景（不是範本做出來的、HUD 拖進暫停選單的欄位…）時出現黃色驚嘆號，遊戲中改用預設的照常運作。
# 也可以不用這個節點，直接把自己的 HUD 場景拖進關卡（這樣在編輯器裡看得到位置）；兩種都接的話用直接放進關卡的那個。

## 自己的 HUD：從檔案系統把改好的 HUD 場景拖進來；空白用預設的
@export var hud_scene: PackedScene:
	set(value):
		hud_scene = value
		update_configuration_warnings()
## 自己的暫停選單：從檔案系統把改好的暫停選單場景拖進來；空白用預設的
@export var pause_menu_scene: PackedScene:
	set(value):
		pause_menu_scene = value
		update_configuration_warnings()
## 自己的過關畫面：從檔案系統把改好的過關畫面場景拖進來；空白用預設的
@export var clear_screen_scene: PackedScene:
	set(value):
		clear_screen_scene = value
		update_configuration_warnings()

const _FIELDS := ["hud_scene", "pause_menu_scene", "clear_screen_scene"]
const _KIND_NAMES := ["HUD", "暫停選單", "過關畫面"]

# 加入群組（檢查場景裡有沒有放兩個），等場景裡其他節點都準備好之後再把自己的畫面放進來
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("ui_settings")
	if get_tree().get_nodes_in_group("ui_settings").size() > 1:
		_warn("場景裡有不只一個 UISettings，只會用第一個，「%s」可以刪掉" % name)
		return
	_spawn_all.call_deferred()

# 編輯器裡就看得到：拖進來的場景不能用、跟直接放進關卡的畫面重複、放了不只一個 UISettings
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var scene_root := get_tree().edited_scene_root if is_inside_tree() else null
	for kind in _FIELDS.size():
		var problem := _problem(kind)
		if problem != "":
			warnings.append(problem)
		elif get(_FIELDS[kind]) != null and scene_root != null and _has_direct(scene_root, kind):
			warnings.append("%s：關卡裡已經直接放了一個自訂%s，會用那一個，這個欄位不會用到" % [_FIELDS[kind], _KIND_NAMES[kind]])
		elif kind == UIRoot.KIND_CLEAR_SCREEN and clear_screen_scene != null and scene_root != null 				and not UIRoot.has_clear_screen(scene_root):
			warnings.append("clear_screen_scene：" + UIRoot.NO_CLEAR_SCREEN)
	if scene_root != null and _count_settings(scene_root) > 1:
		warnings.append("場景裡有不只一個 UISettings，只會用第一個")
	return warnings

# 把每一個能用的欄位生出來放進場景；不能用的、跟直接放進關卡的重複的，印中文警告並跳過（改用預設的）
func _spawn_all() -> void:
	for kind in _FIELDS.size():
		var scene: PackedScene = get(_FIELDS[kind])
		if scene == null:
			continue
		var problem := _problem(kind)
		if problem != "":
			_warn(problem + "；先用預設的")
			continue
		if get_tree().get_first_node_in_group("custom_ui_%d" % kind) != null:
			_warn("%s：關卡裡已經直接放了一個自訂%s，用那一個，這個欄位先不用" % [_FIELDS[kind], _KIND_NAMES[kind]])
			continue
		add_child(scene.instantiate())

# 某個欄位拖進來的場景能不能用，能用（或空白）回傳空字串，不能用回傳原因
func _problem(kind: int) -> String:
	var scene: PackedScene = get(_FIELDS[kind])
	if scene == null:
		return ""
	var probe := scene.instantiate()
	var root_kind: int = (probe as UIRoot).kind if probe is UIRoot else -1
	probe.free()
	if root_kind == -1:
		return "%s：拖進來的場景最上層不是 UIRoot，請從 ui/templates/ 的範本再製出來改" % _FIELDS[kind]
	if root_kind != kind:
		return "%s：拖進來的是%s，不是%s，請拖進 %s" % [_FIELDS[kind], _KIND_NAMES[root_kind], _KIND_NAMES[kind], _FIELDS[root_kind]]
	return ""

# 關卡裡有沒有直接放進來（不在 UISettings 底下）的同一種自訂畫面
func _has_direct(node: Node, kind: int) -> bool:
	if node is UIRoot and node.kind == kind:
		return true
	for child in node.get_children():
		if child != self and _has_direct(child, kind):
			return true
	return false

# 場景裡有幾個 UISettings
func _count_settings(node: Node) -> int:
	var count := 1 if node.get_script() == get_script() else 0
	for child in node.get_children():
		count += _count_settings(child)
	return count

# 印中文警告到輸出面板
func _warn(message: String) -> void:
	push_warning("[畫面設定] %s" % message)
	printerr("⚠ [畫面設定] %s" % message)
