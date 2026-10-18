extends Node2D

# 手動驗證用（U241～U243）：實體箱子。地上有推不動的箱子（BoxFixed）、輕箱子、重箱子、一隻敵人、一個靠在右邊牆上的箱子；
# 左邊有一個高台，要推箱子過去踩著才跳得上去。

@onready var _player: CharacterBody2D = $Player
@onready var _light: RigidBody2D = $Room/BoxLight
@onready var _heavy: RigidBody2D = $Room/BoxHeavy
@onready var _wall_box: RigidBody2D = $Room/BoxWall
@onready var _fixed: RigidBody2D = $Room/BoxFixed
@onready var _enemy: CharacterBody2D = $Room/Enemy

# 印出操作說明，先自動檢查一輪，檢查完把東西放回原位
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳")
	print("[測試] ① 跳到箱子上：站得住，不會陷進去或穿過去，箱子也不會被壓扁、壓進地板")
	print("[測試] ② 從側面走過去：推著箱子走，人不會跟箱子疊在一起；重的推得比較慢")
	print("[測試] ③ 推右邊靠牆的箱子：推不動，人也過不去")
	print("[測試] ④ 把輕箱子推到左邊高台下面，踩著箱子跳上高台")
	print("[測試] ⑤ 最左邊的箱子（BoxFixed，can_push 取消勾）：推不動、站得上去")
	print("[測試] ⑥ 敵人走到箱子會轉身；把箱子推向敵人，箱子停在敵人前面，不會疊在一起")
	print("[測試] ⑦ 按 T：輕箱子以每秒 3000 像素射向右邊的牆（推力器選「疊加」連推幾次就會這麼快），不會穿過去")
	await get_tree().physics_frame
	await _auto_check()
	get_tree().call_group("box", "reset")
	_player.teleport(Vector2(-150, 95))

# 自動檢查：站在箱子上、推輕的、推重的、推靠牆的
func _auto_check() -> void:
	_enemy.set_physics_process(false)
	var light_start := _light.global_position
	_player.teleport(light_start + Vector2(0, -40))
	await _frames(40)
	_check("站在箱子上：腳底在箱子頂端、算站在地上", _player.is_on_floor() and _player.global_position.y < light_start.y - 14.0)
	_check("站上去箱子沒有被壓下去", absf(_light.global_position.y - light_start.y) < 1.0)

	var light_x := _light.global_position.x
	_player.teleport(Vector2(light_x - 40, light_start.y - 8))
	await _walk_right(30)
	var light_moved := _light.global_position.x - light_x
	_check("推輕箱子：箱子往右動了（%.0f 像素）" % light_moved, light_moved > 10.0)
	_check("推的時候人沒有走進箱子裡", _player.global_position.x + 8.0 <= _light.global_position.x - 8.0 + 1.0)

	var heavy_x := _heavy.global_position.x
	_player.teleport(Vector2(heavy_x - 40, light_start.y - 8))
	await _walk_right(30)
	var heavy_moved := _heavy.global_position.x - heavy_x
	_check("推重箱子：動得比輕箱子少（%.0f 像素）" % heavy_moved, heavy_moved > 2.0 and heavy_moved < light_moved)

	var wall_x := _wall_box.global_position.x
	_player.teleport(Vector2(wall_x - 40, light_start.y - 8))
	await _walk_right(30)
	_check("推靠牆的箱子：箱子推不動", absf(_wall_box.global_position.x - wall_x) < 1.0)
	_check("推靠牆的箱子：人被箱子擋住", _player.global_position.x + 8.0 <= wall_x - 8.0 + 1.0)

	var fixed_start := _fixed.global_position
	_player.teleport(Vector2(fixed_start.x - 40, fixed_start.y - 8))
	await _walk_right(30)
	_fixed.take_hit(1, Vector2(500, -300), self)
	await _frames(10)
	_check("推不動的箱子：推、打都不會動", _fixed.global_position.distance_to(fixed_start) < 1.0)
	_check("推不動的箱子：人被擋住", _player.global_position.x + 8.0 <= fixed_start.x - 8.0 + 1.0)
	_player.teleport(fixed_start + Vector2(0, -40))
	await _frames(40)
	_check("推不動的箱子：站得上去", _player.is_on_floor() and _player.global_position.y < fixed_start.y - 14.0)

	_player.teleport(Vector2(-150, 95))
	var enemy_x := _enemy.global_position.x
	_place(_heavy, Vector2(enemy_x - 40, light_start.y))
	for i in 30:
		_heavy.linear_velocity.x = 300.0
		await get_tree().physics_frame
	_check("箱子撞到敵人會停下，不會穿過去疊在一起", _heavy.global_position.x <= enemy_x - 16.0 + 1.0)

	await _shoot_at_wall()
	_enemy.set_physics_process(true)
	_check("箱子被推得很快（每秒 3000 像素）也不會穿牆", _light.global_position.x <= 192.0 - 8.0 + 1.0)

# 把輕箱子放到牆前面，以每秒 3000 像素往右射（推力器選「疊加」連推幾次就會這麼快）
func _shoot_at_wall() -> void:
	_place(_light, Vector2(120, 120))
	_light.linear_velocity = Vector2(3000, 0)
	await _frames(20)

# 把箱子瞬間搬到某個位置、速度歸零（物理引擎裡的位置也一起改）
func _place(box: RigidBody2D, at: Vector2) -> void:
	box.linear_velocity = Vector2.ZERO
	PhysicsServer2D.body_set_state(box.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, at))
	box.global_position = at

# 除錯按鍵：T 把輕箱子射向牆
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		print("[測試] 輕箱子射向牆")
		await _shoot_at_wall()
		print("[測試] 輕箱子停在 x = %.0f（牆的左邊是 184）" % _light.global_position.x)

# 按住右鍵走幾個物理幀
func _walk_right(n: int) -> void:
	Input.action_press("move_right")
	await _frames(n)
	Input.action_release("move_right")
	await _frames(5)

# 等幾個物理幀
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
