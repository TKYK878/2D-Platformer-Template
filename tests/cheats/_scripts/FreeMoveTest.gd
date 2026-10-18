extends Node2D

# 手動驗證用（U233）：Player 的自由移動 API。F 開關飛行，G 開關「飛行時穿牆」。
# 中間有一道牆，牆後面有金幣；右邊還有第二個房間（沒有地板），飛過去鏡頭會切過去。

@onready var _player: CharacterBody2D = $Player

var _fly: bool = false
var _pass_walls: bool = false

# 印出操作說明，先自動檢查一輪 API
func _ready() -> void:
	Stats.value_changed.connect(func(kind: String, _old: int, new_value: int):
		print("[測試] %s 變成 %d" % [kind, new_value]))
	_auto_check()
	print("[測試] 方向鍵或 WASD 移動、空白跳；F 開關飛行、G 開關飛行時穿牆")
	print("[測試] ① 按 F：不會往下掉，上下左右鍵往哪按就往哪飛；按空白不會跳；放開方向鍵就停在空中")
	print("[測試] ② 飛去撞中間的牆：撞得到，過不去")
	print("[測試] ③ 按 G 再飛過去：穿過牆，撿得到牆後的金幣（輸出面板印金幣變成 1）")
	print("[測試] ④ 往右飛出房間：鏡頭切到右邊的房間（輸出面板印「玩家進入 Room2」）；穿過地板往下飛也可以")
	print("[測試] ⑤ 回到地板上空按 F 關掉：掉下來站在地上，照常跳")

# 自動檢查：穿牆時碰撞遮罩清空、關掉後還原；開飛行的組件被刪掉時效果跟著消失
func _auto_check() -> void:
	var mask := _player.collision_mask
	_player.set_free_move(self, true)
	_check("只開飛行不穿牆：碰撞遮罩不變", _player.collision_mask == mask and _player.is_free_moving())
	_player.set_free_move(self, true, true)
	_check("開穿牆：碰撞遮罩清空", _player.collision_mask == 0)
	_player.set_free_move(self, false)
	_check("關掉：碰撞遮罩還原、不是在飛", _player.collision_mask == mask and not _player.is_free_moving())
	var temp := Node.new()
	_player.set_free_move(temp, true, true)
	temp.free()
	_check("開飛行的組件被刪掉：飛行停止、碰撞遮罩還原", not _player.is_free_moving() and _player.collision_mask == mask)

# 除錯按鍵：F 飛行、G 穿牆
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F:
			_fly = not _fly
			_apply()
		KEY_G:
			_pass_walls = not _pass_walls
			_apply()

# 把目前的開關套到 Player 上並印出來
func _apply() -> void:
	_player.set_free_move(self, _fly, _pass_walls)
	print("[測試] 飛行：%s　穿牆：%s" % ["開" if _fly else "關", "開" if _pass_walls else "關"])

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
