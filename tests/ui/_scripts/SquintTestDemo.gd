extends Node2D

# 手動驗證用：瞇眼測試 SquintTest。小關卡裡有玩家、金幣、尖刺、終點，按 F1 看它們變糊之後分不分得出來（B 切換黑白）。
# C：把一個學員動作綁到 F2、瞇眼測試改用 F2 → 讓給學員並提醒；D：多放一個瞇眼測試 → 中文警告、自己拿掉

const _SQUINT := preload("res://skins/SquintTest.tscn")

@onready var _squint: CanvasLayer = $SquintTest

# 印出操作說明
func _ready() -> void:
	print("[測試] ① 按 F1：整個畫面變糊、顏色還在，左上角出現「瞇眼測試中（F1 關掉）」（這行字不會糊）；再按 F1 恢復")
	print("[測試] 　 B：切換 style 只模糊／模糊＋黑白（黑白時只剩明暗）")
	print("[測試] ② 開著時照常跑跳、撿金幣、碰尖刺：遊戲不受影響")
	print("[測試] ③ 按 Esc 暫停：選單也被變糊；暫停中按 F1 一樣能開關")
	print("[測試] ④ 編輯器裡選 SquintTest：key 下拉（F1／F2／Tab／G）、style 下拉、strength 拉桿（越大越糊）")
	print("[測試] ⑤ C：把 F2 綁給一個學員動作、瞇眼測試改用 F2 → 輸出面板提醒「F2 已經被…用掉了」，按 F2 不會切換")
	print("[測試] ⑥ D：多放一個瞇眼測試 → 輸出面板中文警告，多的那個自己拿掉")
	print("[測試] ⑦ 匯出的遊戲裡不會有作用（只在編輯器按 F5／F6 時有效）")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_C:
			if not InputMap.has_action("test_student_f2"):
				InputMap.add_action("test_student_f2")
				var e := InputEventKey.new()
				e.physical_keycode = KEY_F2
				InputMap.action_add_event("test_student_f2", e)
			_squint.key = 1
			print("[測試] 瞇眼測試改用 F2（F2 已經綁給 test_student_f2）")
		KEY_D:
			add_child(_SQUINT.instantiate())
		KEY_B:
			_squint.style = 1 - _squint.style
			print("[測試] style：%s" % ["只模糊", "模糊＋黑白"][_squint.style])

# 離開時拿掉測試用的動作
func _exit_tree() -> void:
	if InputMap.has_action("test_student_f2"):
		InputMap.erase_action("test_student_f2")
