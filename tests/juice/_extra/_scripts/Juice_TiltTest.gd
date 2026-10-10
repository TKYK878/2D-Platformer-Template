extends Node2D

# 手動驗證用：傾斜（持續型，備品）。
# Juice_Tilt：預設值（最多 12 度、0.12 秒、空中也傾斜）。
# 另外掛了重力翻轉（Q）、自動奔跑（一開始關著，A 開關）、擠壓拉伸（落地時）。

@onready var _player: CharacterBody2D = $Player
@onready var _tilt: Node = $Player/Juice/Juice_Tilt
@onready var _auto_run: Node = $Player/Mechanics/Mechanic_AutoRun

# 印出操作說明
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳、Q 翻轉重力、A 自動奔跑開關、G 切換空中要不要傾斜、K 死亡、0 Juice 總開關")
	print("[測試] ① 往右跑：身體以腳底為中心往右傾（頭往右），往左跑頭往左；放開方向鍵慢慢回正")
	print("[測試] ② 落地壓扁時一樣以腳底為中心，腳不會離開地面")
	print("[測試] ③ Q 翻轉重力（頭朝下）：跑起來頭一樣往前進的方向倒")
	print("[測試] ④ A 開自動奔跑：撞牆轉向時傾斜方向跟著換")
	print("[測試] ⑤ G 關掉空中傾斜：跳起來就回正，落地後跑步才傾")
	print("[測試] ⑥ 跑步中按 K 死亡、按 0 關掉 Juice：重生後／關掉後角色是正的")

# 除錯按鍵：A 自動奔跑、G 空中傾斜、K 死亡
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_A:
			_auto_run.enabled = not _auto_run.enabled
			print("[測試] 自動奔跑：%s" % ("開" if _auto_run.enabled else "關"))
		KEY_G:
			_tilt.in_air = not _tilt.in_air
			print("[測試] 空中傾斜：%s" % ("開" if _tilt.in_air else "關"))
		KEY_K:
			print("[測試] 模擬死亡")
			_player.kill()
