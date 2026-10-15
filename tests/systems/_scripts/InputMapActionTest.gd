extends Node2D

# 手動驗證用（U201）：卡片、能力、按鍵觸發器的「按鍵種類」選 Input Map 動作，聽專案設定 Input Map 裡的動作；
# 動作沒選、名稱找不到時印中文警告。測試用的動作在這個場景開場時加進 InputMap，離開時拿掉，不會改到專案設定

# 測試用的動作：名稱 -> [鍵盤按鍵, 手把按鈕]
const _TEST_ACTIONS := {
	"test_attack": [KEY_T, JOY_BUTTON_X],
	"test_shoot": [KEY_Y, JOY_BUTTON_Y],
	"test_flip": [KEY_U, JOY_BUTTON_B],
}

var _jump_pad_event: InputEventJoypadButton = null

# 搶在卡片、能力的 _ready() 向 InputRouter 註冊之前，先把測試用的動作加進 InputMap；跳躍順便加手把 A 鍵
func _enter_tree() -> void:
	for action in _TEST_ACTIONS:
		InputMap.add_action(action)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = _TEST_ACTIONS[action][0]
		InputMap.action_add_event(action, key_event)
		var pad_event := InputEventJoypadButton.new()
		pad_event.button_index = _TEST_ACTIONS[action][1]
		InputMap.action_add_event(action, pad_event)
	_jump_pad_event = InputEventJoypadButton.new()
	_jump_pad_event.button_index = JOY_BUTTON_A
	InputMap.action_add_event("jump", _jump_pad_event)

# 印出操作步驟與預期結果
func _ready() -> void:
	print("[測試] 準備完成（有手把的話括號裡的手把按鈕也要能用）：")
	print("  1. 輸出面板應該看到兩則中文警告：衝刺「還沒選是哪一個動作」、按鍵觸發器 KeyTrigger_Typo 找不到「test_atack」，並建議「test_attack」
     （另外有一則近戰跟 KeyTrigger_Action 都用 T 的衝突提醒，是預期內的）")
	print("  2. 按 T（手把 X）：近戰揮一下，印「近戰」跟「按鍵觸發器」兩行")
	print("  3. 按 Y（手把 Y）：遠程開一槍，印「遠程」那行")
	print("  4. 按 U（手把 B）：重力翻轉，印「重力翻轉」那行")
	print("  5. 按空白鍵（手把 A）：跳躍；按 Shift 衝刺不會動（衝刺選了 Input Map 動作但沒選動作）")
	print("  6. 選 Player/Mechanics/Mechanic_GravityFlip：Inspector「按鍵種類」選 Input Map 動作時才看得到 action 下拉，換成鍵盤按鍵就藏起來")

# 離開場景時拿掉測試用的動作與跳躍的手把鍵，不影響之後開的場景
func _exit_tree() -> void:
	for action in _TEST_ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	if InputMap.has_action("jump"):
		InputMap.action_erase_event("jump", _jump_pad_event)

# 近戰透過 test_attack 揮出去
func _on_melee_attacked() -> void:
	print("[測試] 近戰收到 test_attack（正確）")

# 遠程透過 test_shoot 開槍
func _on_ranged_attacked() -> void:
	print("[測試] 遠程收到 test_shoot（正確）")

# 重力翻轉透過 test_flip 翻轉
func _on_flipped() -> void:
	print("[測試] 重力翻轉收到 test_flip（正確）")

# 按鍵觸發器選了 test_attack，跟近戰同一顆鍵也照樣收得到
func _on_trigger_action() -> void:
	print("[測試] 按鍵觸發器收到 test_attack（正確，只聽不搶）")

# 打錯名稱的按鍵觸發器不該觸發
func _on_trigger_typo() -> void:
	print("[測試] 打錯名稱的按鍵觸發器被觸發了（錯誤：應該不綁定）")
