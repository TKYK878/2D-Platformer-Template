@tool
extends Button

# 選單按鈕：從下拉選單選這顆按鈕要做什麼，按下去就執行，不用連任何線。
# 按鈕上的字用原生的 Text 改；換動作時如果字還是預設的，會自動換成新動作的名字。
# 「繼續遊戲」放在單獨開的設定畫面上時改成回標題。
# 「整關重來」在關卡裡沒有 RespawnHandler 時自動藏起來，「離開遊戲」在網頁版自動藏起來，
# 「回標題」在主場景不是標題畫面（或現在就在標題畫面）時自動藏起來。
# 「開始遊戲」在下拉選單選要去哪一關，按下去換到那個場景（標題畫面用）。

## 按下去要做什麼
@export_enum("繼續遊戲", "整關重來", "離開遊戲", "開始遊戲", "回標題") var action: int = ACTION_RESUME:
	set(value):
		if text == "" or text == _NAMES[action]:
			text = _NAMES[value]
		action = value
		notify_property_list_changed()
		update_configuration_warnings()
## 按下去要去哪一關（動作選「開始遊戲」才出現）：下拉選單列出 _my/ 和 levels/_starts/ 裡的關卡，
## 另外 _my/ui/ 裡的 UI 畫面（例如設定畫面）也可以選
@export var level: String = "":
	set(value):
		level = value
		if Engine.is_editor_hint():
			level_uid = _uid_of(_level_path(value))
		update_configuration_warnings()

# 選關卡時順便記下檔案的 UID：學員之後把關卡改名、搬資料夾，還找得到
@export_storage var level_uid: String = ""

const ACTION_RESUME := 0
const ACTION_RESTART := 1
const ACTION_QUIT := 2
const ACTION_START := 3
const ACTION_TITLE := 4

const _NAMES := ["繼續遊戲", "整關重來", "離開遊戲", "開始遊戲", "回標題"]
# 「開始遊戲」的下拉選單從這些資料夾找關卡（會往下掃子資料夾，所以 _my/ui 不用另外列）
const _LEVEL_DIRS := ["res://_my", "res://levels/_starts"]
# 這些資料夾裡的 UI 畫面（最上層是 UIRoot）也放進下拉選單，例如設定畫面
const _UI_SCENE_DIRS := ["res://_my/ui"]
const _SCAN_GAP_MS := 2000

# 測試場景用：假裝在網頁版上，檢查「離開遊戲」會不會藏起來
static var pretend_web: bool = false

static var _scan_cache: PackedStringArray = []
static var _scan_at_ms: int = -_SCAN_GAP_MS

# 按下去就執行選好的動作；暫停中也要按得到
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	pressed.connect(_on_pressed)
	refresh_menu_action()

# 依現在的狀況決定要不要出現：沒有 RespawnHandler 藏起「整關重來」，網頁版藏起「離開遊戲」，
# 沒有標題畫面可回藏起「回標題」。暫停選單打開時會呼叫
func refresh_menu_action() -> void:
	if action == ACTION_RESTART:
		visible = PauseMenu.can_restart()
	elif action == ACTION_QUIT:
		visible = not (pretend_web or OS.has_feature("web"))
	elif action == ACTION_TITLE:
		visible = PauseMenu.can_go_to_title()

# 執行選好的動作
func _on_pressed() -> void:
	match action:
		ACTION_RESUME:
			# 單獨開的設定畫面沒有遊戲可以繼續，改成回標題
			if PauseMenu.is_menu_scene():
				PauseMenu.back_from_menu_scene()
			else:
				PauseMenu.close()
		ACTION_RESTART:
			PauseMenu.restart_level()
		ACTION_QUIT:
			PauseMenu.quit_game()
		ACTION_START:
			_start_level()
		ACTION_TITLE:
			PauseMenu.go_to_title()

# 換到選好的關卡；沒選、檔案不見了就印中文警告，不換
func _start_level() -> void:
	var path := get_level_path()
	if path == "":
		var problem := _level_problem()
		push_warning("[%s] %s" % [name, problem])
		printerr("⚠ [%s] %s" % [name, problem])
		return
	if path != _level_path(level):
		print("[%s] 「%s」改名或搬家了，現在在 %s；選這顆按鈕把 level 重新選一次就不會再看到這行" % [name, level, path])
	PauseMenu.change_scene(path)

# 「開始遊戲」要去的關卡完整路徑；檔案改名或搬家時用記下的 UID 找；找不到回傳空字串
func get_level_path() -> String:
	if level == "":
		return ""
	var path := _level_path(level)
	if ResourceLoader.exists(path):
		return path
	if level_uid != "":
		var id := ResourceUID.text_to_id(level_uid)
		if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return ""

# 「開始遊戲」的 level 欄位：只在這個動作下顯示，選項是掃到的關卡（存的是去掉 res:// 的路徑）
func _validate_property(property: Dictionary) -> void:
	if property.name != "level":
		return
	if action != ACTION_START:
		property.usage = PROPERTY_USAGE_NO_EDITOR
		return
	var options := find_levels()
	if level != "" and level not in options:
		options.insert(0, level)
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(options)

# 編輯器裡就看得到：「開始遊戲」還沒選關卡、選的關卡不見了
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var problem := _level_problem()
	if problem != "":
		warnings.append(problem)
	return warnings

# 放進關卡的選單（看不到裡面的按鈕）時，警告由 UIRoot 收集起來顯示在最上層
func get_hud_warnings(_scene_root: Node) -> PackedStringArray:
	return _get_configuration_warnings()

# 「開始遊戲」的設定有什麼問題，沒問題回傳空字串
func _level_problem() -> String:
	if action != ACTION_START:
		return ""
	if level == "":
		return "還沒選要開始哪一關：選這顆按鈕，在 level 下拉選單選一個關卡"
	if get_level_path() == "":
		return "找不到關卡「%s」，可能被刪掉了：在 level 下拉選單重新選一個" % level
	return ""

# 掃 _my/ 和 levels/_starts/ 底下的場景檔，排除 UI 畫面（最上層是 UIRoot 的：標題、HUD、選單），
# 但 _my/ui/ 裡的 UI 畫面保留；兩秒內重複問就用上次的結果（Inspector 會一直問）
static func find_levels() -> PackedStringArray:
	var now := Time.get_ticks_msec()
	if now - _scan_at_ms < _SCAN_GAP_MS:
		return _scan_cache.duplicate()
	_scan_at_ms = now
	var found := PackedStringArray()
	for dir in _LEVEL_DIRS:
		_scan_dir(dir, found)
	found.sort()
	_scan_cache = found
	return found.duplicate()

# 往下掃一個資料夾，把關卡場景（去掉 res://）加進 found；同一個檔案只加一次
static func _scan_dir(path: String, found: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_scan_dir(path.path_join(sub), found)
	for file in dir.get_files():
		if file.get_extension() == "tscn":
			var full := path.path_join(file)
			if _allows_ui_scene(full) or not _is_ui_scene(full):
				var short := full.trim_prefix("res://")
				if short not in found:
					found.append(short)

# 這個場景在允許選 UI 畫面的資料夾（_UI_SCENE_DIRS）裡嗎
static func _allows_ui_scene(path: String) -> bool:
	for dir in _UI_SCENE_DIRS:
		if path.begins_with(dir.trim_suffix("/") + "/"):
			return true
	return false

# 場景檔最上層是不是 UIRoot（直接讀場景檔的文字，不把整個關卡載進來）
static func _is_ui_scene(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var ui_id := ""
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with("[ext_resource") and line.contains("ui/_scripts/UIRoot.gd"):
			ui_id = line.get_slice(" id=\"", 1).get_slice("\"", 0)
		elif line.begins_with("[node"):
			if ui_id == "":
				return false
			while not file.eof_reached():
				var prop := file.get_line()
				if prop.begins_with("["):
					return false
				if prop == "script = ExtResource(\"%s\")" % ui_id:
					return true
			return false
	return false

# level 欄位存的路徑補回 res://
static func _level_path(value: String) -> String:
	return "" if value == "" else "res://" + value

# 某個檔案的 UID 文字，拿不到回傳空字串
static func _uid_of(path: String) -> String:
	if path == "" or not ResourceLoader.exists(path):
		return ""
	var id := ResourceLoader.get_resource_uid(path)
	return ResourceUID.id_to_text(id) if id != ResourceUID.INVALID_ID else ""
