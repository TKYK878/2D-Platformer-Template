extends Node

# 暫停選單：每一關都有，學員不用擺任何東西。按 Esc 或 P 暫停／繼續。
# 畫面用 ui/templates/PauseMenuTemplate.tscn 範本；關卡裡有學員自己的暫停選單（UISettings 欄位或直接放進關卡）就改顯示那一個。
# 標題畫面的「開始遊戲」、選單的「回標題」要換場景也由這裡處理（換之前把數值、重生記憶這些上一關的東西歸零）。
# 這裡管什麼時候打開、關掉，還有三條匯流排的音量（記在 user:// 的設定檔，下次開遊戲還是一樣）；
# 畫面上的按鈕（MenuAction）、拉桿（VolumeSlider）呼叫這裡的公開函式。

const _TEMPLATE := preload("res://ui/templates/PauseMenuTemplate.tscn")
const _SETTINGS_PATH := "user://settings.cfg"
# [匯流排名稱, 預設音量]
const _BUSES := [["Master", 0.8], ["SFX", 1.0], ["BGM", 0.8]]
const _KEYS := [KEY_ESCAPE, KEY_P]
# 拉音效拉桿時播的試聽音效；拖著拉時最快隔這麼久才播一次（毫秒），免得疊成一團
const _PREVIEW_SOUND := preload("res://sfx/pickup.wav")
const _PREVIEW_GAP_MS := 120

var _default_root: Control = null    # 預設的範本畫面（第一次打開時才生）
var _shown: Control = null           # 現在顯示中的畫面
var _volumes: Dictionary = {}        # 匯流排名稱 -> 線性音量 0～1
var _open: bool = false
var _warned_p: bool = false
var _preview: AudioStreamPlayer = null
var _last_preview_ms: int = -_PREVIEW_GAP_MS
var _changing_scene: bool = false
var _title_cache: Dictionary = {}    # 場景路徑 -> 是不是標題畫面

# 測試場景用：「回標題」改回這個場景，不用改專案的主場景；空白就是主場景
var title_scene_override: String = ""

# 讀回上次的音量並套用；暫停時也要收得到按鍵
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_volumes()
	for bus in _BUSES:
		_apply_volume(bus[0])
	_preview = AudioStreamPlayer.new()
	_preview.stream = _PREVIEW_SOUND
	_preview.bus = &"SFX"
	add_child(_preview)

# 按 Esc 或 P：開著就關、關著就開
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = (event as InputEventKey).physical_keycode
	if key not in _KEYS:
		return
	if key == KEY_P and _is_p_taken():
		return
	get_viewport().set_input_as_handled()
	if _open:
		close()
	else:
		open()

# 打開暫停選單；過關畫面這類別人造成的暫停中就不開，免得關掉時把別人的暫停一起解除
func open() -> void:
	if _open or get_tree().paused or is_title_scene():
		return
	_open = true
	if not can_restart():
		print("[暫停選單] 關卡裡沒有 RespawnHandler，選單裡不會有「整關重來」。想要的話把 blocks/RespawnHandler.tscn 拖進關卡")
	_shown = _pick_screen()
	_refresh_buttons(_shown)
	_shown.visible = true
	get_tree().paused = true
	var first := _first_button(_shown)
	if first != null:
		first.grab_focus()

# 關掉暫停選單，繼續遊戲
func close() -> void:
	if not _open:
		return
	_open = false
	if is_instance_valid(_shown):
		_shown.visible = false
	_shown = null
	get_tree().paused = false

# 回傳暫停選單現在是不是開著
func is_open() -> bool:
	return _open

# 關卡裡能不能整關重來（有 RespawnHandler 才行），「整關重來」按鈕用這個決定要不要出現
func can_restart() -> bool:
	return _find_respawn_handler() != null

# 整關重來：關掉選單，終點恢復成還沒踩過，請重生處理者整關重來
func restart_level() -> void:
	var handler := _find_respawn_handler()
	close()
	if handler == null:
		print("[暫停選單] 關卡裡沒有 RespawnHandler，沒辦法整關重來。想要的話把 blocks/RespawnHandler.tscn 拖進關卡")
		return
	get_tree().call_group("goal", "reset")
	handler.restart_level_now()

# 離開遊戲（網頁版關不掉，什麼都不做）
func quit_game() -> void:
	if OS.has_feature("web"):
		return
	get_tree().quit()

# ---- 換場景（只有標題畫面的「開始遊戲」、選單的「回標題」用；重生、整關重來不換場景）

# 換到另一個場景：關掉選單、解除暫停，舊場景拿掉之後把數值、顯示來源、重生記憶、預設 HUD 歸零，再放進新場景。
# 換得了回傳 true；路徑空白、檔案不見了回傳 false 並印中文警告
func change_scene(path: String) -> bool:
	if _changing_scene:
		return false
	if path == "" or not ResourceLoader.exists(path):
		_warn_scene("找不到要去的場景「%s」，檔案可能被刪掉或改名了" % path)
		return false
	_changing_scene = true
	close()
	get_tree().paused = false
	Engine.time_scale = 1.0
	_swap_scene.call_deferred(path)
	return true

# 回到標題畫面（主場景）
func go_to_title() -> bool:
	return change_scene(get_title_scene())

# 標題畫面是哪個場景：專案的主場景（測試場景可以用 title_scene_override 換掉）
func get_title_scene() -> String:
	if title_scene_override != "":
		return title_scene_override
	return str(ProjectSettings.get_setting("application/run/main_scene", ""))

# 「回標題」用不用得到：主場景是標題畫面，而且現在不在標題畫面上。選單按鈕用這個決定要不要出現
func can_go_to_title() -> bool:
	var path := get_title_scene()
	return path != "" and not is_title_scene() and is_title_scene_file(path)

# 現在的場景是不是標題畫面（最上層是「標題畫面」的 UIRoot）
func is_title_scene() -> bool:
	var scene := get_tree().current_scene
	return scene is UIRoot and (scene as UIRoot).kind == UIRoot.KIND_TITLE

# 某個場景檔的最上層是不是「標題畫面」的 UIRoot（只看場景檔，不生出來；查過的記住）
func is_title_scene_file(path: String) -> bool:
	if _title_cache.has(path):
		return _title_cache[path]
	var result := false
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			result = UIRoot.scene_root_kind(packed) == UIRoot.KIND_TITLE
	_title_cache[path] = result
	return result

# 真的換場景：先拿掉舊場景（舊場景的東西不會再改到數值），歸零之後再放進新場景（新場景的 ValueSettings 才套得上）
func _swap_scene(path: String) -> void:
	get_tree().unload_current_scene()
	Stats.reset_for_new_scene()
	HudData.reset_for_new_scene()
	RespawnMemory.clear()
	StatsHud.reset_for_new_scene()
	var error := get_tree().change_scene_to_file(path)
	_changing_scene = false
	if error != OK:
		_warn_scene("換到「%s」失敗（錯誤代碼 %d）" % [path, error])
		return
	print("[換場景] 換到 %s" % path)

# 換場景出問題時印中文警告
func _warn_scene(message: String) -> void:
	push_warning("[換場景] %s" % message)
	printerr("⚠ [換場景] %s" % message)

# P 已經被學員或組件拿去當別的按鍵（例如按鍵觸發器、按鍵設定）時讓給它，只用 Esc 暫停，第一次提醒一下
func _is_p_taken() -> bool:
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and ((e as InputEventKey).physical_keycode == KEY_P or (e as InputEventKey).keycode == KEY_P):
				if not _warned_p:
					_warned_p = true
					print("[暫停選單] P 已經被別的東西用掉了（%s），暫停請按 Esc" % action)
				return true
	return false

# 找出場景裡可以整關重來的重生處理者
func _find_respawn_handler() -> Node:
	var handler := get_tree().get_first_node_in_group("respawn_handler")
	if handler != null and handler.has_method("restart_level_now"):
		return handler
	return null

# ---- 音量

# 讀某條匯流排現在的音量（0～1），bus 是 "Master"／"SFX"／"BGM"；音量拉桿用這個
func get_volume(bus_name: String) -> float:
	return _volumes.get(bus_name, 1.0)

# 設定某條匯流排的音量（0～1，拉到 0 靜音）並存進設定檔；調音效時播一下試聽音效。音量拉桿用這個
func set_volume(bus_name: String, value: float) -> void:
	if not _volumes.has(bus_name):
		return
	_volumes[bus_name] = clampf(value, 0.0, 1.0)
	_apply_volume(bus_name)
	_save_volumes()
	if bus_name == "SFX":
		_play_preview()

# 播一下試聽音效，讓學員聽得到音效現在多大聲
func _play_preview() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_preview_ms < _PREVIEW_GAP_MS:
		return
	_last_preview_ms = now
	_preview.play()

# 把記下的音量套用到匯流排，拉到 0 就直接靜音
func _apply_volume(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_warning("[暫停選單] 找不到「%s」匯流排，這條的音量沒辦法調；請確認 default_bus_layout.tres 還在" % bus_name)
		printerr("⚠ [暫停選單] 找不到「%s」匯流排，這條的音量沒辦法調" % bus_name)
		return
	var value: float = _volumes[bus_name]
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))

# 從設定檔讀回上次的音量，沒有就用預設值
func _load_volumes() -> void:
	var config := ConfigFile.new()
	config.load(_SETTINGS_PATH)
	for bus in _BUSES:
		_volumes[bus[0]] = clampf(float(config.get_value("audio", bus[0], bus[1])), 0.0, 1.0)

# 把目前的音量存進設定檔
func _save_volumes() -> void:
	var config := ConfigFile.new()
	config.load(_SETTINGS_PATH)
	for bus_name in _volumes:
		config.set_value("audio", bus_name, _volumes[bus_name])
	config.save(_SETTINGS_PATH)

# ---- 畫面

# 這次要顯示哪個畫面：關卡裡有學員的暫停選單就用它，沒有就用預設範本（第一次才生）
func _pick_screen() -> Control:
	var custom := get_tree().get_first_node_in_group("custom_ui_%d" % UIRoot.KIND_PAUSE_MENU)
	if custom is Control and not custom.is_queued_for_deletion():
		return custom
	if _default_root == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_default_root = _TEMPLATE.instantiate()
		_default_root.set_meta(HudBinding.DEFAULT_META, true)
		layer.add_child(_default_root)
	return _default_root

# 通知畫面上的按鈕重新決定要不要出現（例如沒有 RespawnHandler 就藏起「整關重來」）
func _refresh_buttons(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("refresh_menu_action"):
			child.refresh_menu_action()
		_refresh_buttons(child)

# 畫面上第一個看得到、可以按的按鈕，打開時先選它，鍵盤才能直接操作
func _first_button(node: Node) -> BaseButton:
	for child in node.get_children():
		if child is BaseButton and (child as Control).is_visible_in_tree() and (child as Control).focus_mode == Control.FOCUS_ALL:
			return child
		var found := _first_button(child)
		if found != null:
			return found
	return null
