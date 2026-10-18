extends Node

# 手動驗證用（U224）：標題畫面的 UIRoot 設了整個畫面的按鈕音效（按下金幣、選到嗶），
# 底下幾顆 MenuAction 自己選了不一樣的音效，還有一顆普通的 Godot 按鈕。
# 開場先自動按一輪，檢查每顆按鈕播的是不是對的音效；之後請自己用滑鼠、鍵盤試。

const _BUTTONS := "Layout/Left/Buttons/"

# 印出操作說明，等選單安靜期過了，自動按一輪按鈕檢查播出來的音效
func _ready() -> void:
	PauseMenu.title_scene_override = get_tree().current_scene.scene_file_path
	print("[測試] ===== 按鈕音效測試 =====")
	print("[測試] ① 開場：第一顆按鈕被自動選起來，但不會響「嗶」；輸出面板有一行黃色警告：「自訂沒放音檔」的 custom_press_sound 是空的")
	print("[測試] ② 滑鼠移到「開始遊戲」「普通按鈕」「自己選：雷射」上 → 嗶；移到「按下無聲、選到跳躍」上 → 跳躍聲")
	print("[測試] ③ 按「普通按鈕」→ 金幣；「自己選：雷射」→ 雷射；「按下無聲、選到跳躍」→ 沒聲音；「自訂沒放音檔」→ 嗶")
	print("[測試] ④ 用鍵盤上下鍵切換按鈕 → 每換一顆響一次選到的音效；用滑鼠點按鈕時不會多響一聲「嗶」")
	print("[測試] ⑤ 按「開始遊戲」→ 金幣聲會完整播完，不會因為換場景被切掉；關卡裡按 Esc，預設暫停選單沒設音效，按鈕沒聲音")
	print("[測試] ⑥ 點最上層節點：Inspector 有「按鈕音效」群組；press_sound 選「自訂」才出現 custom_press_sound；點「自訂沒放音檔」那顆有黃色驚嘆號")
	await get_tree().create_timer(UIRoot.SELECT_QUIET_MS / 1000.0 + 0.1).timeout
	var scene := get_tree().current_scene
	_check_press(scene, "Plain", preload("res://sfx/coin.wav"), "普通按鈕用畫面的按下音效（金幣）")
	_check_press(scene, "OwnLaser", preload("res://sfx/laser.wav"), "MenuAction 自己選的雷射蓋過畫面的金幣")
	_check_press(scene, "OwnQuiet", null, "MenuAction 自己選「無」：按下沒有聲音")
	_check_press(scene, "OwnCustomEmpty", preload("res://sfx/beep.wav"), "選「自訂」沒放音檔：改播嗶")

# 假裝按一下某顆按鈕，檢查場景樹最上層新播出來的音效對不對（expected 是 null 表示不該有聲音）
func _check_press(scene: Node, button_name: String, expected: AudioStream, label: String) -> void:
	var before := get_tree().root.get_child_count()
	scene.get_node(_BUTTONS + button_name).pressed.emit()
	var played: Array = []
	for i in range(before, get_tree().root.get_child_count()):
		var player := get_tree().root.get_child(i) as AudioStreamPlayer
		if player != null:
			played.append(player.stream)
	if expected == null:
		_check(label, played.is_empty())
	else:
		_check(label, played.size() == 1 and played[0] == expected)

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
