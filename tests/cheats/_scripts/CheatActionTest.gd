extends Node2D

# 手動驗證用（U238）：作弊的一次性功能。場景裡有兩個房間（Room、Room2），數字鍵觸發「只當接口」的 Cheat：
# 1 金幣 +10、2 血量補滿、3 下一個房間、4 上一個房間、5 在這裡設重生點、6 直接過關。
# 暫停選單裡有一個只勾一次性功能的 Cheat（分數 +5），選單上會是按鈕不是勾選框。
# Cheat_Typo 的自訂數值打成「星行」（ValueSettings 用的是「星星」），開場會印「是不是想打『星星』」。

@onready var _player: CharacterBody2D = $Player
@onready var _cheats: Array[Node] = [$Cheat_Coins, $Cheat_Heal, $Cheat_Next, $Cheat_Prev, $Cheat_Save, $Cheat_Clear]

# 印出操作說明，先自動檢查一輪
func _ready() -> void:
	Stats.value_changed.connect(func(kind: String, _old: int, new_value: int):
		print("[測試] %s 變成 %d" % [kind, new_value]))
	print("[測試] 方向鍵移動、空白跳、H 受傷、K 自殺；數字鍵 1～6 觸發作弊；Esc 暫停選單")
	print("[測試] ① 開場輸出面板有 Cheat_Typo 的警告：「星行」是不是想打「星星」；編輯器裡 Cheat_Typo 有黃色驚嘆號")
	print("[測試] ② 按 1：金幣 +10（每按一次都加）；按 H 兩下再按 2：血量補滿")
	print("[測試] ③ 按 3：瞬間到右邊房間的房間起點，鏡頭跟過去；按 4 回來；在最左邊再按 4 印「已經是第一個房間了」")
	print("[測試] ④ 跳到半空中按 5、再按 K：重生在按 5 的位置")
	print("[測試] ⑤ 按 Esc：選單最下面有「作弊：分數 +5」按鈕，每按一次分數 +5")
	print("[測試] ⑥ 按 6：跳出過關畫面")
	await get_tree().process_frame
	_auto_check()

# 自動檢查：每個一次性功能做完的結果
func _auto_check() -> void:
	var coins := Stats.get_value("金幣")
	_cheats[0].turn_on()
	_cheats[0].turn_on()
	_check("金幣 +10 按兩次：多了 20", Stats.get_value("金幣") == coins + 20)
	_check("只有一次性功能：不會一直「開著」", not _cheats[0].is_on())
	_player.take_damage(2)
	_cheats[1].turn_on()
	_check("血量補滿", Stats.get_value(Stats.HEALTH_KIND) == Stats.get_max_value(Stats.HEALTH_KIND))
	var start := _player.global_position
	_cheats[2].turn_on()
	_check("下一個房間：到了 Room2 的房間起點", _player.global_position == $Room2.get_spawn_point())
	await get_tree().physics_frame
	await get_tree().physics_frame
	_cheats[3].turn_on()
	_check("上一個房間：回到 Room 的房間起點", _player.global_position == $Room.get_spawn_point())
	_player.teleport(start)
	_cheats[4].turn_on()
	_check("在這裡設重生點：重生位置是玩家現在的位置", RespawnMemory.get_respawn_point() == _player.global_position)

# 除錯按鍵：1～6 觸發作弊、H 受傷、K 自殺
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.physical_keycode
	if key >= KEY_1 and key <= KEY_6:
		_cheats[key - KEY_1].turn_on()
	elif key == KEY_H:
		print("[測試] 模擬受傷")
		_player.take_damage(1)
	elif key == KEY_K:
		print("[測試] 自殺")
		_player.kill()

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
