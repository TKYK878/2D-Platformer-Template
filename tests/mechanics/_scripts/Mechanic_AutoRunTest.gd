extends Node2D

# 手動驗證用：Mechanic_AutoRun 角色自動往一邊跑，撞牆轉向，跳躍鍵仍然有效。
# K 死掉並在起點重生；1／2／3 呼叫 run_left()／run_right()／turn_around()。

@onready var _player: Node = $Player
@onready var _card: Node = $Player/Mechanics/Mechanic_AutoRun

var _start_position: Vector2

# 記下起點，印出操作說明
func _ready() -> void:
	_start_position = _player.global_position
	Events.mechanic_event.connect(_on_mechanic_event)
	print("[測試] 角色被兩面牆夾住，應該自動左右來回跑，不用按方向鍵")
	print("[測試] 撞到牆的瞬間應該印出一次 wall_turned，角色朝向（貼圖左右翻轉）應該同步改變")
	print("[測試] 按空白鍵跳躍應該正常有效，不受這張卡影響")
	print("[測試] 等角色撞上右牆的那一刻按 K：在起點重生後一定往右跑（start_direction），不會一重生就轉向")
	print("[測試] 按 1 往左、2 往右、3 反方向：角色立刻改方向、貼圖跟著翻；這三個不會印 wall_turned")

# 除錯按鍵：K 死掉後在起點重生、1／2／3 改方向
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_K:
			_player.kill()
			await get_tree().create_timer(0.3).timeout
			_player.revive(_start_position)
			print("[測試] 在起點重生")
		KEY_1:
			_card.run_left()
		KEY_2:
			_card.run_right()
		KEY_3:
			_card.turn_around()

# 印出機制卡事件
func _on_mechanic_event(card: String, event: String) -> void:
	print("[測試] Events.mechanic_event：%s / %s" % [card, event])
