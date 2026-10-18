@tool
extends Button

# 選單按鈕：從下拉選單選這顆按鈕要做什麼，按下去就執行，不用連任何線。
# 按鈕上的字用原生的 Text 改；換動作時如果字還是預設的，會自動換成新動作的名字。
# 「繼續遊戲」放在單獨開的設定畫面上時改成回標題。
# 「整關重來」在關卡裡沒有 RespawnHandler 時自動藏起來，「離開遊戲」在網頁版自動藏起來，
# 「回標題」在主場景不是標題畫面（或現在就在標題畫面）時自動藏起來。
# 「開始遊戲」在下拉選單選要去哪一關，按下去換到那個場景（標題畫面用）。
# 「打開設定」打開同一個畫面裡的設定頁（ui/SettingsPage），「返回」關掉自己所在的設定頁。

## 按下去要做什麼
@export_enum("繼續遊戲", "整關重來", "離開遊戲", "開始遊戲", "回標題", "打開設定", "返回") var action: int = ACTION_RESUME:
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

## 按下去之後畫面變黑再亮回來的總秒數（變黑一半、亮回來一半），全黑的時候才換場景／整關重來；0 就直接換
## （動作選「整關重來」「開始遊戲」「回標題」才出現）
@export_range(0.0, 2.0, 0.05) var fade_duration: float = 0.5

@export_group("音效")
## 按下這顆按鈕播什麼音效：「跟畫面一樣」用最上層 UIRoot 的按鈕音效；想跟別顆不一樣再選
@export_enum("跟畫面一樣", "無", "嗶", "金幣", "撿東西", "跳躍", "落地", "雷射", "自訂") var press_sound: int = SOUND_FOLLOW:
	set(value):
		press_sound = value
		notify_property_list_changed()
		update_configuration_warnings()
## 自己的按下音效：從檔案系統把 .wav／.ogg／.mp3 拖進來
@export var custom_press_sound: AudioStream:
	set(value):
		custom_press_sound = value
		update_configuration_warnings()
## 選到這顆按鈕時（滑鼠移上去、用鍵盤或手把切換）播什麼音效：「跟畫面一樣」用最上層 UIRoot 的
@export_enum("跟畫面一樣", "無", "嗶", "金幣", "撿東西", "跳躍", "落地", "雷射", "自訂") var select_sound: int = SOUND_FOLLOW:
	set(value):
		select_sound = value
		notify_property_list_changed()
		update_configuration_warnings()
## 自己的選到音效：從檔案系統把 .wav／.ogg／.mp3 拖進來
@export var custom_select_sound: AudioStream:
	set(value):
		custom_select_sound = value
		update_configuration_warnings()

const ACTION_RESUME := 0
const ACTION_RESTART := 1
const ACTION_QUIT := 2
const ACTION_START := 3
const ACTION_TITLE := 4
const ACTION_SETTINGS := 5
const ACTION_BACK := 6

const _NAMES := ["繼續遊戲", "整關重來", "離開遊戲", "開始遊戲", "回標題", "設定", "返回"]
const _SettingsPage := preload("res://ui/_scripts/SettingsPage.gd")
# 「開始遊戲」的下拉選單從這些資料夾找關卡（會往下掃子資料夾，所以 _my/ui 不用另外列）
const _LEVEL_DIRS := ["res://_my", "res://levels/_starts"]
# 這些資料夾裡的 UI 畫面（最上層是 UIRoot）也放進下拉選單，例如設定畫面
const _UI_SCENE_DIRS := ["res://_my/ui"]
const _SCAN_GAP_MS := 2000

# 音效下拉：0 是跟畫面一樣，其他的減 1 就是 UIRoot 按鈕音效的選項
const SOUND_FOLLOW := 0
const SOUND_CUSTOM := 8
# 按鈕自己選的音效用這個音量
const _SOUND_VOLUME := 0.8

# 這個時間（毫秒）以前選到不播音效：選單剛出現時會自動選第一顆按鈕
var _select_quiet_until := 0

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
	for problem in _sound_problems():
		push_warning("[%s] %s" % [name, problem])
		printerr("⚠ [%s] %s" % [name, problem])
	pressed.connect(_on_pressed_sound)
	mouse_entered.connect(_on_selected_sound.bind(true))
	focus_entered.connect(_on_selected_sound.bind(false))
	visibility_changed.connect(_on_visibility_changed_for_sounds)
	_select_quiet_until = Time.get_ticks_msec() + UIRoot.SELECT_QUIET_MS

# 這顆按鈕有沒有自己選音效（press 為 true 問按下、false 問選到）；有的話 UIRoot 就不幫它播
func has_own_sound(press: bool) -> bool:
	return (press_sound if press else select_sound) != SOUND_FOLLOW

# 按下時：自己選了音效就播自己的
func _on_pressed_sound() -> void:
	if press_sound != SOUND_FOLLOW:
		UIRoot.play_ui_sound(self, UIRoot.ui_sound(press_sound - 1, custom_press_sound), _SOUND_VOLUME)

# 選到時：自己選了音效就播自己的（點下去順便選到、選單剛出現自動選的不播）
func _on_selected_sound(by_mouse: bool) -> void:
	if select_sound == SOUND_FOLLOW or not UIRoot.is_select_sound_wanted(self, by_mouse, _select_quiet_until):
		return
	UIRoot.play_ui_sound(self, UIRoot.ui_sound(select_sound - 1, custom_select_sound), _SOUND_VOLUME)

# 選單出現時會自動選第一顆按鈕，這一下不播選到的音效
func _on_visibility_changed_for_sounds() -> void:
	if is_visible_in_tree():
		_select_quiet_until = Time.get_ticks_msec() + UIRoot.SELECT_QUIET_MS

# 音效的設定問題：選了「自訂」卻沒放音檔
func _sound_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	if press_sound == SOUND_CUSTOM and custom_press_sound == null:
		problems.append("press_sound 選了「自訂」，但 custom_press_sound 是空的，請把音檔從檔案系統拖進來；沒放之前先播嗶")
	if select_sound == SOUND_CUSTOM and custom_select_sound == null:
		problems.append("select_sound 選了「自訂」，但 custom_select_sound 是空的，請把音檔從檔案系統拖進來；沒放之前先播嗶")
	return problems

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
			PauseMenu.restart_level(fade_duration)
		ACTION_QUIT:
			PauseMenu.quit_game()
		ACTION_START:
			_start_level()
		ACTION_TITLE:
			PauseMenu.go_to_title(fade_duration)
		ACTION_SETTINGS:
			_open_settings()
		ACTION_BACK:
			_close_settings()

# 打開同一個畫面裡的設定頁；找不到就印中文警告
func _open_settings() -> void:
	var page := _find_settings_page()
	if page == null:
		var problem := _settings_problem()
		push_warning("[%s] %s" % [name, problem])
		printerr("⚠ [%s] %s" % [name, problem])
		return
	page.open(self)

# 關掉自己所在的設定頁；不在設定頁裡就印中文警告
func _close_settings() -> void:
	var page := _own_settings_page(get_tree().get_nodes_in_group("settings_page"))
	if page == null:
		var problem := _settings_problem()
		push_warning("[%s] %s" % [name, problem])
		printerr("⚠ [%s] %s" % [name, problem])
		return
	page.close()

# 「打開設定」要開的設定頁：跟這顆按鈕在同一個場景檔裡的那個（標題畫面、自己的暫停選單），沒有的話場景裡只有一個就用它
func _find_settings_page() -> Node:
	var pages := get_tree().get_nodes_in_group("settings_page")
	for page in pages:
		if page.owner == owner and owner != null:
			return page
	return pages[0] if pages.size() == 1 else null

# 自己被放在哪個設定頁裡面（從設定頁往下看，不往上爬），不在任何設定頁裡回傳 null
func _own_settings_page(pages: Array) -> Node:
	for page in pages:
		if page.is_ancestor_of(self):
			return page
	return null

# 「打開設定」「返回」的設定有什麼問題（編輯器裡掃正在編輯的場景，遊戲中看場景裡所有的設定頁），沒問題回傳空字串
func _settings_problem() -> String:
	if action != ACTION_SETTINGS and action != ACTION_BACK:
		return ""
	var pages: Array = []
	if Engine.is_editor_hint():
		pages = _SettingsPage.find_in(get_tree().edited_scene_root)
	else:
		pages = get_tree().get_nodes_in_group("settings_page")
	if action == ACTION_SETTINGS and pages.is_empty():
		return "畫面裡沒有設定頁，按了不會有反應：從 ui/ 拖一個 SettingsPage 進這個畫面（放最上層底下）"
	if action == ACTION_BACK and _own_settings_page(pages) == null:
		return "「返回」要放在設定頁（SettingsPage）裡面才有用：把這顆按鈕拖進 SettingsPage 的 Center/Panel/List 底下"
	return ""

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
	PauseMenu.change_scene(path, fade_duration)

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

# 「開始遊戲」的 level 欄位：只在這個動作下顯示，選項是掃到的關卡（存的是去掉 res:// 的路徑）；
# 自訂音效的欄位只在選「自訂」時顯示
func _validate_property(property: Dictionary) -> void:
	if property.name == "custom_press_sound" and press_sound != SOUND_CUSTOM:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "custom_select_sound" and select_sound != SOUND_CUSTOM:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "fade_duration" and action not in [ACTION_RESTART, ACTION_START, ACTION_TITLE]:
		property.usage = PROPERTY_USAGE_NO_EDITOR
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
	if is_inside_tree():
		var settings_problem := _settings_problem()
		if settings_problem != "":
			warnings.append(settings_problem)
	warnings.append_array(_sound_problems())
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
