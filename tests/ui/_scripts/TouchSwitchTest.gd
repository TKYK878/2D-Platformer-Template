extends Node2D

# 手機按鈕開關（U231）：暫停選單範本直接放進關卡、開「可編輯的子節點」，List 底下放了：
# SwitchCheck（勾選框）、SwitchList（下拉選單）、OwnApi（不顯示，只當接口），
# 加上學員自己做的按鈕「切換手機按鈕」（pressed 連到 OwnApi 的 toggle_controls）、勾選框「隱藏手機按鈕」（toggled 連到 OwnApi 的 set_off）。
# 關卡裡的手機按鈕套件選「只在觸控裝置」，電腦上平常看不到。開場自動檢查完會把設定改回「自動」。

const _BUTTON_SCENE := preload("res://ui/TouchButton.tscn")

@onready var _kit: Control = $TouchControls

# 跑自動檢查，再印出手動操作說明
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run_checks()
	print("[測試] ── 手動測試 ──")
	print("[測試] ① 按 Esc：暫停選單裡有「手機按鈕」勾選框、「手機按鈕」下拉選單、「切換手機按鈕」按鈕、「隱藏手機按鈕」勾選框")
	print("[測試] ② 勾「手機按鈕」：關掉選單後左下 ◀ ▶、右下跳、右上暫停鈕出現；下拉選單同時變成「顯示」")
	print("[測試] ③ 下拉選「隱藏」：按鈕藏起來，勾選框跟著取消勾；選「自動」：電腦上看不到（套件選只在觸控裝置）")
	print("[測試] ④ 按「切換手機按鈕」：看得到就藏、看不到就出現；勾「隱藏手機按鈕」：藏起來，取消勾：出現")
	print("[測試] ⑤ 選「顯示」後關掉遊戲再開：按鈕還在（記在設定檔）；測完記得改回「自動」")
	print("[測試] ⑥ 選 SwitchCheck 改 style：編輯器裡馬上換成下拉選單或消失")

# 輪流用勾選框、下拉選單、自己的按鈕和勾選框切換，檢查手機按鈕跟著變、設定有存檔
func _run_checks() -> void:
	print("[測試] ── 自動檢查 ──")
	var switch_check: Node = find_child("SwitchCheck", true, false)
	var switch_list: Node = find_child("SwitchList", true, false)
	var own_toggle := find_child("OwnToggle", true, false) as Button
	var own_hide := find_child("OwnHideCheck", true, false) as CheckButton
	var check: CheckButton = switch_check.get("_check")
	var list: OptionButton = switch_list.get("_list")
	TouchSettings.set_mode(TouchSettings.MODE_AUTO)
	_check("勾選框樣式有勾選框、下拉樣式有下拉選單", check != null and list != null and switch_check.get("_list") == null)
	_check("「自動」：電腦上看不到套件", not _kit.visible or DisplayServer.is_touchscreen_available())

	list.select(1)
	list.item_selected.emit(1)
	_check("下拉選「顯示」：套件出現", _kit.visible)
	_check("勾選框跟著勾起來", check.button_pressed)
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	_check("設定存進設定檔（touch/mode = 1）", int(config.get_value("touch", "mode", -1)) == TouchSettings.MODE_SHOW)
	var fresh := _BUTTON_SCENE.instantiate()
	add_child(fresh)
	_check("選了「顯示」後新出現的手機按鈕（像換到下一關）：「只在觸控裝置」也照樣顯示", fresh.visible)
	fresh.queue_free()

	check.button_pressed = false
	_check("取消勾勾選框：套件藏起來", not _kit.visible)
	_check("下拉選單跟著變成「隱藏」", list.selected == TouchSettings.MODE_HIDE)

	own_toggle.pressed.emit()
	_check("按自己的「切換手機按鈕」：出現", _kit.visible)
	own_toggle.pressed.emit()
	_check("再按一次：藏起來", not _kit.visible)

	own_hide.button_pressed = false
	own_hide.button_pressed = true
	_check("勾自己的「隱藏手機按鈕」（set_off）：藏著", not _kit.visible)
	own_hide.button_pressed = false
	_check("取消勾：出現", _kit.visible)

	switch_list.auto_controls()
	_check("auto_controls：回到自動，下拉選單顯示「自動」", list.selected == TouchSettings.MODE_AUTO and TouchSettings.mode == TouchSettings.MODE_AUTO)
	_check("回到自動：電腦上看不到套件", not _kit.visible or DisplayServer.is_touchscreen_available())

# 印出一條檢查結果
func _check(label: String, ok: bool) -> void:
	if ok:
		print("[測試] ✓ %s" % label)
	else:
		printerr("[測試] ✗ %s" % label)
