extends Node

# 手機按鈕的共用狀態：記住玩家現在是不是在用觸控（手指碰螢幕就算，改按鍵盤、手把就不算），換關也記得。
# 手機按鈕、套件、搖桿的 show_on 選「摸到螢幕才出現」時看這裡決定要不要顯示，狀態變了會發 changed。
# 玩家在選單（TouchSwitch）選的「自動／顯示／隱藏」也記在這裡，存進設定檔（跟音量同一份），下次開遊戲還是一樣。

signal changed

const SHOW_TOUCH_DEVICE := 0
const SHOW_ALWAYS := 1
const SHOW_AUTO := 2
# 玩家的選擇：自動（照各零件的 show_on）、一直顯示、一直隱藏
const MODE_AUTO := 0
const MODE_SHOW := 1
const MODE_HIDE := 2
const _SETTINGS_PATH := "user://settings.cfg"
# 手把搖桿推超過這個程度才算改用手把
const _STICK_PUSH := 0.5

var touch_used: bool = false   # 玩家最後用的是不是觸控
var mode: int = MODE_AUTO      # 玩家在選單選的，改的話用 set_mode()

var _fake_keys: Dictionary = {}   # 手機按鈕送出、還沒處理到的假按鍵（按鍵 -> 幾個），收到時不算按鍵盤

# 讀回玩家上次的選擇；暫停時也要收得到輸入
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	config.load(_SETTINGS_PATH)
	mode = clampi(int(config.get_value("touch", "mode", MODE_AUTO)), MODE_AUTO, MODE_HIDE)

# 改玩家的選擇（自動／顯示／隱藏）並存檔，手機按鈕開關用這個
func set_mode(value: int) -> void:
	value = clampi(value, MODE_AUTO, MODE_HIDE)
	if mode == value:
		return
	mode = value
	var config := ConfigFile.new()
	config.load(_SETTINGS_PATH)
	config.set_value("touch", "mode", mode)
	config.save(_SETTINGS_PATH)
	changed.emit()

# 依玩家的選擇和零件的 show_on 決定現在要不要顯示，手機按鈕、套件、搖桿用這個
func should_show(show_on: int) -> bool:
	if mode == MODE_SHOW:
		return true
	if mode == MODE_HIDE:
		return false
	match show_on:
		SHOW_ALWAYS:
			return true
		SHOW_AUTO:
			return touch_used
	return DisplayServer.is_touchscreen_available()

# 手機按鈕送出假按鍵前先說一聲，收到這個按鍵事件時不會當成玩家改按鍵盤
func expect_fake_key(key: Key) -> void:
	_fake_keys[key] = _fake_keys.get(key, 0) + 1

# 手指碰螢幕就算在用觸控；按鍵盤（手機按鈕送的假按鍵不算）、手把就不算
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_set_touch_used(true)
	elif event is InputEventKey:
		var key: Key = (event as InputEventKey).physical_keycode
		if _fake_keys.has(key):
			_fake_keys[key] -= 1
			if _fake_keys[key] <= 0:
				_fake_keys.erase(key)
		elif event.pressed:
			_set_touch_used(false)
	elif event is InputEventJoypadButton and event.pressed:
		_set_touch_used(false)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > _STICK_PUSH:
		_set_touch_used(false)

# 改「是不是在用觸控」，有變才發 changed
func _set_touch_used(value: bool) -> void:
	if touch_used == value:
		return
	touch_used = value
	changed.emit()
