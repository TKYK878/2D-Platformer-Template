extends Node2D

# 手動驗證用（U237）：作弊的更多開關類功能。場景裡有五個「只當接口」的 Cheat，用數字鍵開關：
# 1 無限跳、2 慢動作（0.5 倍）、3 快轉（2 倍）、4 敵人凍結、5 鏡頭拉遠（2 倍大）。
# 地上有一隻會走的敵人、一隻會開槍的敵人；R 觸發一次頓幀，看結束後速度有沒有回到作弊設定的速度。

@onready var _player: CharacterBody2D = $Player
@onready var _cheats: Array[Node] = [$Cheat_Jump, $Cheat_Slow, $Cheat_Fast, $Cheat_Freeze, $Cheat_Zoom]

# 印出操作說明，先自動檢查一輪
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳；數字鍵 1～5 開關作弊；R 頓幀一下")
	print("[測試] ① 按 1（無限跳）：空中一直按空白一直往上跳")
	print("[測試] ② 按 2（慢動作）：整個遊戲變慢；按 R 頓幀後還是慢的（不會變回正常速度）；再按 2 恢復")
	print("[測試] ③ 2、3 一起開：0.5 × 2 = 正常速度，畫面上方兩行「作弊中」都在")
	print("[測試] ④ 按 4（敵人凍結）：兩隻敵人停住、不再開槍，走過去不會受傷；再按 4 繼續動")
	print("[測試] ⑤ 按 5（鏡頭拉遠）：畫面看到兩倍大，看得到隔壁房間；再按 5 恢復")
	await get_tree().process_frame
	_auto_check()

# 自動檢查：每個功能打開、關掉時的效果
func _auto_check() -> void:
	var enemy := $Room/Enemy
	_cheats[0].turn_on()
	_check("無限跳：空中也算可以起跳", _player.can_ground_jump())
	_cheats[0].turn_off()
	_cheats[1].turn_on()
	_check("慢動作：Engine.time_scale 變成 0.5", is_equal_approx(Engine.time_scale, 0.5))
	_cheats[2].turn_on()
	_check("慢動作＋快轉：乘起來是 1", is_equal_approx(Engine.time_scale, 1.0))
	_cheats[1].turn_off()
	_cheats[2].turn_off()
	_check("都關掉：回到 1", is_equal_approx(Engine.time_scale, 1.0))
	_cheats[3].turn_on()
	_check("敵人凍結：敵人停掉", enemy.process_mode == Node.PROCESS_MODE_DISABLED)
	_cheats[3].turn_off()
	_check("關掉：敵人恢復", enemy.process_mode == Node.PROCESS_MODE_INHERIT)
	var camera := get_viewport().get_camera_2d()
	var base_zoom := camera.zoom
	_cheats[4].turn_on()
	await get_tree().process_frame
	_check("鏡頭拉遠：縮放變一半", camera.zoom.is_equal_approx(base_zoom / 2.0))
	_cheats[4].turn_off()
	await get_tree().process_frame
	_check("關掉：鏡頭恢復", camera.zoom.is_equal_approx(base_zoom))

# 除錯按鍵：1～5 開關作弊、R 頓幀
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.physical_keycode
	if key >= KEY_1 and key <= KEY_5:
		_cheats[key - KEY_1].toggle()
	elif key == KEY_R:
		print("[測試] 頓幀")
		Events.hitstop_requested.emit(0.2)

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
