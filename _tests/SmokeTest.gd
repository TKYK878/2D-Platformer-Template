extends Node

# 自動化煙霧測試。規格見 documents/00_foundation.md 第 7 節。
# 掃 mechanics/ 與 juice/ 資料夾，不需要手動維護清單。

const PLAYER_SCENE := preload("res://player/Player.tscn")

var _player: CharacterBody2D
var _mechanics_container: Node2D
var _juice_container: Node2D
var _failed := false

func _ready() -> void:
	_setup_player()
	await _run_all_steps()

func _fail(msg: String) -> void:
	_failed = true
	printerr("✗ 煙霧測試失敗：%s" % msg)

func _setup_player() -> void:
	var ground := StaticBody2D.new()
	var ground_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000, 32)
	ground_shape.shape = shape
	ground.add_child(ground_shape)
	ground.position = Vector2(0, 200)
	add_child(ground)

	_player = PLAYER_SCENE.instantiate()

	var visual := Node2D.new()
	visual.name = "Visual"
	visual.add_to_group("player_visual")
	_player.add_child(visual)
	# 角色圖：Juice 的擠壓、閃色、傾斜、殘影、死亡爆散都作用在 Visual 的圖片子節點上
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = preload("res://art/white_block.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 16, 32)
	visual.add_child(sprite)

	_mechanics_container = Node2D.new()
	_mechanics_container.name = "Mechanics"
	_player.add_child(_mechanics_container)

	_juice_container = Node2D.new()
	_juice_container.name = "Juice"
	_player.add_child(_juice_container)

	add_child(_player)

func _run_all_steps() -> void:
	await get_tree().process_frame

	var mechanic_scenes := _only_mechanic_cards(_scan_scenes("res://mechanics"))
	var juice_scenes := _only_juice(_scan_scenes("res://juice"))

	# 1. 逐一實例化每一張機制卡
	for path in mechanic_scenes:
		await _test_single(path, _mechanics_container)
	await _clear_container(_mechanics_container)
	await _assert_can_move("單一機制卡")

	# 2. 隨機組合 3 個機制卡同時掛載
	if mechanic_scenes.size() > 0:
		await _test_combo(mechanic_scenes, _mechanics_container, 3)
		await _clear_container(_mechanics_container)
		await _assert_can_move("機制卡組合")

	# 3. 逐一實例化每個 Juice 組件
	for path in juice_scenes:
		await _test_single(path, _juice_container)
	await _clear_container(_juice_container)
	await _assert_can_move("單一 Juice")

	# 4. 同時掛 6 個 Juice 組件
	if juice_scenes.size() > 0:
		await _test_combo(juice_scenes, _juice_container, 6)
		await _clear_container(_juice_container)
		await _assert_can_move("Juice 組合")

	# 4b. 同時掛 6 個 Juice（含咕嚕眼、殘影），每一種觸發事件都發一次，跑 60 幀
	await _test_juice_all_events(juice_scenes)
	await _assert_can_move("Juice 全部事件")

	# 4c. Juice 跟忽大忽小、重力翻轉、自動奔跑一起掛，連續死亡重生，外觀要還原
	await _test_juice_kill_revive(juice_scenes)
	await _assert_can_move("Juice 死亡重生")

	# 4d. Juice 總開關切換 10 次
	await _test_juice_switch(juice_scenes)
	await _assert_can_move("Juice 總開關")

	# 5. 觸發頓幀 10 次
	await _test_hitstop()
	await _assert_can_move("頓幀測試")

	# 6. 連續 kill / revive 10 次，每次重生後狀態都要歸零
	await _test_kill_revive()
	await _assert_can_move("死亡重生測試")

	# 7. 兩隻掛了敵人射擊的敵人朝玩家連射，玩家死掉就復活，中途打倒一隻
	await _test_enemy_shooter()
	await _assert_can_move("敵人射擊測試")

	# 8. 按鍵手感全開（含起跑加速），跟二段跳、蹬牆跳、蓄力青蛙跳、黏黏身體一起掛，亂按跳躍、左右跑
	await _test_input_feel()
	await _assert_can_move("按鍵手感測試")

	if _failed:
		print("SMOKE TEST FAILED")
		get_tree().quit(1)
	else:
		print("SMOKE TEST PASSED")
		get_tree().quit(0)

func _scan_scenes(root_path: String) -> Array[String]:
	var result: Array[String] = []
	_scan_dir(root_path, result)
	return result

func _scan_dir(path: String, result: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full_path := path.path_join(entry)
			if dir.current_is_dir():
				_scan_dir(full_path, result)
			elif entry.ends_with(".tscn"):
				result.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()

# 只留下根節點是 Juice 組件的場景（juice/particles/ 底下的粒子範例不是組件）
func _only_juice(paths: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for path in paths:
		var scene: PackedScene = load(path)
		var inst: Node = scene.instantiate()
		if inst is JuiceBase:
			result.append(path)
		inst.free()
	return result

# 只留下根節點是機制卡的場景（mechanics/ 底下也放了殼、殼的特性這類不是卡的零件）
func _only_mechanic_cards(paths: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for path in paths:
		var scene: PackedScene = load(path)
		var inst: Node = scene.instantiate()
		if inst is MechanicBase:
			result.append(path)
		inst.free()
	return result

func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _test_single(path: String, container: Node) -> void:
	var scene: PackedScene = load(path)
	var inst: Node = scene.instantiate()
	container.add_child(inst)
	await _wait_frames(60)
	if not is_instance_valid(_player):
		_fail("測試 %s 時 Player 消失了" % path)
	inst.queue_free()
	await get_tree().process_frame

func _test_combo(paths: Array[String], container: Node, count: int) -> void:
	var shuffled := paths.duplicate()
	shuffled.shuffle()
	var picked: Array = shuffled.slice(0, mini(count, shuffled.size()))
	var instances: Array[Node] = []
	for path in picked:
		var scene: PackedScene = load(path)
		var inst: Node = scene.instantiate()
		container.add_child(inst)
		instances.append(inst)
	await _wait_frames(60)
	if not is_instance_valid(_player):
		_fail("組合測試（%s）時 Player 消失了" % container.name)
	for inst in instances:
		inst.queue_free()
	await get_tree().process_frame

func _test_hitstop() -> void:
	for i in 10:
		Events.hitstop_requested.emit(0.05)
		await _wait_frames(3)
	await get_tree().create_timer(0.5, true, false, true).timeout
	if not is_equal_approx(Engine.time_scale, 1.0):
		_fail("頓幀結束後 Engine.time_scale 應為 1.0，實際為 %s" % Engine.time_scale)
		Engine.time_scale = 1.0

# 掛上重力翻轉、忽大忽小、越跑越快，每一輪先把狀態弄亂（翻轉、變大、扣血）再死亡、復活，
# 檢查重生後重力、角色圖方向、體型、血量、死亡狀態都回到正確的值
func _test_kill_revive() -> void:
	var flip: Node = load("res://mechanics/Mechanic_GravityFlip.tscn").instantiate()
	var size: Node = load("res://mechanics/Mechanic_SizeShift.tscn").instantiate()
	var ramp: Node = load("res://mechanics/Mechanic_SpeedRamp.tscn").instantiate()
	for card in [flip, size, ramp]:
		_mechanics_container.add_child(card)
	await _wait_frames(5)
	var respawned_count := [0]
	var on_respawned := func(_p): respawned_count[0] += 1
	Events.player_respawned.connect(on_respawned)
	var spawn := Vector2(0, 150)
	var visual: Node2D = _player.visual
	for i in 10:
		flip._try_flip()
		size._toggle()
		_player.take_damage(1.0)
		await _wait_frames(3)
		_player.kill()
		if not _player.is_dead():
			_fail("第 %d 輪 kill() 之後 is_dead() 應該是 true" % (i + 1))
		await _wait_frames(2)
		_player.revive(spawn)
		var round_name := "第 %d 輪重生後" % (i + 1)
		if _player.is_dead():
			_fail("%s is_dead() 應該是 false" % round_name)
		if not _player.global_position.is_equal_approx(spawn):
			_fail("%s 位置應該是 %s，實際是 %s" % [round_name, spawn, _player.global_position])
		if _player.up_direction != Vector2.UP:
			_fail("%s 重力方向沒有復位" % round_name)
		if visual != null and visual.scale.y < 0.0:
			_fail("%s 角色圖還是上下顛倒" % round_name)
		if not is_equal_approx(_player.size_factor, size.small_scale):
			_fail("%s 體型應該是 %s，實際是 %s" % [round_name, size.small_scale, _player.size_factor])
		if Stats.get_value(Stats.HEALTH_KIND) != Stats.get_max_value(Stats.HEALTH_KIND):
			_fail("%s 血量沒有補滿" % round_name)
		await _wait_frames(3)
	if respawned_count[0] != 10:
		_fail("player_respawned 應該發出 10 次，實際 %d 次" % respawned_count[0])
	Events.player_respawned.disconnect(on_respawned)
	await _clear_container(_mechanics_container)
	_player.set_size_factor(1.0)

# 放兩隻掛了 EnemyShooter 的敵人（一隻射前停一下、一隻不停）用最短間隔朝玩家射，
# 玩家死掉就原地復活，中途打倒一隻，最後全部移除，確認整段不會崩潰、Player 還在
func _test_enemy_shooter() -> void:
	var enemies: Array[Node2D] = []
	for x in [-120.0, 120.0]:
		var enemy: Node2D = load("res://blocks/Enemy.tscn").instantiate()
		var shooter: Node2D = load("res://blocks/EnemyShooter.tscn").instantiate()
		shooter.cooldown = 0.3
		shooter.detect_range_tiles = 0
		shooter.stop_to_shoot = x > 0.0
		enemy.add_child(shooter)
		enemy.position = Vector2(x, 170)
		add_child(enemy)
		enemies.append(enemy)
	var shots := [0]
	for enemy in enemies:
		enemy.get_node("EnemyShooter").shot.connect(func(): shots[0] += 1)
	for i in 6:
		await _wait_frames(30)
		if _player.is_dead():
			_player.revive(Vector2.ZERO)
		if i == 3:
			enemies[0].take_hit(99, Vector2.ZERO, self)
	if shots[0] == 0:
		_fail("敵人射擊測試：3 秒內一發子彈都沒射出")
	if not is_instance_valid(_player):
		_fail("敵人射擊測試時 Player 消失了")
	for enemy in enemies:
		enemy.queue_free()
	await get_tree().process_frame
	if _player.is_dead():
		_player.revive(Vector2.ZERO)

# 記下 Visual 底下每個子節點現在的外觀（位置、縮放、旋轉、顏色）
func _snapshot_visual() -> Dictionary:
	var result := {}
	for child in _player.visual.get_children():
		if child is Node2D:
			result[child] = [child.position, child.scale, child.rotation, child.modulate]
	return result

# 比對 Visual 子節點的外觀跟之前記下的一不一樣，不一樣就算失敗；
# only_recorded = true 時只比對記下來的那些（Juice 自己加進 Visual 的節點不算）
func _check_visual_restored(before: Dictionary, stage: String, only_recorded: bool) -> void:
	for child in _player.visual.get_children():
		if not before.has(child):
			if not only_recorded and child is Node2D and not child.is_queued_for_deletion():
				_fail("%s：Visual 底下多了 %s 沒有被拿掉" % [stage, child.name])
			continue
		var o: Array = before[child]
		if not child.position.is_equal_approx(o[0]) or not child.scale.is_equal_approx(o[1]) 				or not is_equal_approx(child.rotation, o[2]) or not child.modulate.is_equal_approx(o[3]):
			_fail("%s：%s 的外觀沒有還原（位置 %s 縮放 %s 旋轉 %s 顏色 %s）" % [stage, child.name, child.position, child.scale, child.rotation, child.modulate])

# 掛上指定的 Juice（一定包含咕嚕眼與殘影，其餘隨機補到 count 個），回傳掛上去的節點
func _add_juice_set(paths: Array[String], count: int) -> Array[Node]:
	var must := ["res://juice/Juice_GooglyEyes.tscn", "res://juice/Juice_Trail.tscn"]
	var picked: Array = must.duplicate()
	var rest := paths.filter(func(p): return p not in must)
	rest.shuffle()
	picked.append_array(rest.slice(0, maxi(count - must.size(), 0)))
	var instances: Array[Node] = []
	for path in picked:
		var inst: Node = load(path).instantiate()
		_juice_container.add_child(inst)
		instances.append(inst)
	return instances

# 把 Juice 能聽的每一種觸發事件都發一次（玩家事件、世界事件、數值變化），最後發重生把死亡的效果收掉
func _emit_every_juice_event() -> void:
	_player.jumped.emit()
	_player.landed.emit(600.0)
	_player.hurt.emit()
	_player.wall_hit.emit()
	_player.started_moving.emit()
	_player.direction_changed.emit(1)
	_player.direction_changed.emit(-1)
	Events.hit.emit(_juice_container, self)
	Events.enemy_died.emit(_player.global_position + Vector2(40, 0))
	Events.item_collected.emit(_player.global_position + Vector2(-40, 0))
	Stats.add("金幣", 1)
	Events.level_cleared.emit()
	_player.died.emit()
	await _wait_frames(5)
	Events.player_respawned.emit(_player)

# 6 個 Juice（含咕嚕眼、殘影）同時掛，每一種事件發一次（每種之間隔一點時間，避開 0.05 秒連發保護），跑 60 幀
func _test_juice_all_events(paths: Array[String]) -> void:
	if paths.is_empty():
		return
	var before := _snapshot_visual()
	_add_juice_set(paths, 6)
	await _wait_frames(5)
	_player.velocity = Vector2(500, 0)
	await _emit_every_juice_event()
	await _wait_frames(60)
	if not is_instance_valid(_player):
		_fail("Juice 全部事件測試時 Player 消失了")
	await _clear_container(_juice_container)
	await _wait_frames(2)
	_check_visual_restored(before, "Juice 全部事件測試拔掉所有 Juice 後", false)

# 全部 Juice 跟忽大忽小、重力翻轉、自動奔跑一起掛，每一輪先觸發擠壓、閃色這類效果再死亡、復活，
# 重生當下 Visual 子節點的縮放／顏色／旋轉要回到原本的樣子；最後拔掉所有 Juice，外觀完全還原
func _test_juice_kill_revive(paths: Array[String]) -> void:
	if paths.is_empty():
		return
	var before := _snapshot_visual()
	var flip: Node = load("res://mechanics/Mechanic_GravityFlip.tscn").instantiate()
	var size: Node = load("res://mechanics/Mechanic_SizeShift.tscn").instantiate()
	var run: Node = load("res://mechanics/Mechanic_AutoRun.tscn").instantiate()
	for card in [flip, size, run]:
		_mechanics_container.add_child(card)
	for path in paths:
		_juice_container.add_child(load(path).instantiate())
	await _wait_frames(5)
	for i in 10:
		flip._try_flip()
		size._toggle()
		_player.landed.emit(600.0)
		_player.hurt.emit()
		await _wait_frames(3)
		_player.kill()
		await _wait_frames(2)
		_player.revive(Vector2(0, 150))
		_check_visual_restored(before, "Juice 死亡重生第 %d 輪重生後" % (i + 1), true)
		await _wait_frames(3)
	await _clear_container(_mechanics_container)
	await _clear_container(_juice_container)
	_player.set_size_factor(1.0)
	await _wait_frames(2)
	_check_visual_restored(before, "拔掉所有 Juice 後", false)

# 掛著全部 Juice，總開關切換 10 次（中間發事件、輪流呼叫 clear／turn_off／turn_on），最後打開、拔掉，不崩潰、外觀還原
func _test_juice_switch(paths: Array[String]) -> void:
	if paths.is_empty():
		return
	var before := _snapshot_visual()
	for path in paths:
		_juice_container.add_child(load(path).instantiate())
	await _wait_frames(5)
	for i in 10:
		JuiceSwitch.set_on(not JuiceSwitch.is_on())
		_player.landed.emit(600.0)
		_player.hurt.emit()
		await _wait_frames(4)
		# 同時用訊號函式清掉／關掉／打開每個 Juice
		for j in _juice_container.get_children():
			match i % 3:
				0: j.clear()
				1: j.turn_off()
				2: j.turn_on()
	JuiceSwitch.set_on(true)
	for j in _juice_container.get_children():
		j.turn_on()
	if not is_instance_valid(_player):
		_fail("Juice 總開關測試時 Player 消失了")
	await _clear_container(_juice_container)
	await _wait_frames(2)
	_check_visual_restored(before, "Juice 總開關測試拔掉所有 Juice 後", false)

# 按鍵手感全部打開，跟所有會攔截跳躍鍵的卡一起掛，連續點跳、按住跳、左右跑、中途死亡重生，不崩潰、還能移動
func _test_input_feel() -> void:
	_player.smooth_start_enabled = true
	var cards := ["res://mechanics/_extra/Extra_DoubleJump.tscn", "res://mechanics/_extra/Extra_WallJump.tscn",
		"res://mechanics/Mechanic_ChargeJump.tscn", "res://mechanics/Mechanic_StickyBody.tscn"]
	for path in cards:
		_mechanics_container.add_child(load(path).instantiate())
	await _wait_frames(5)
	for i in 12:
		Input.action_press("move_right" if i % 4 < 2 else "move_left")
		Input.action_press("jump")
		await _wait_frames(2 + i % 5)
		Input.action_release("jump")
		await _wait_frames(6)
		Input.action_release("move_right")
		Input.action_release("move_left")
		if i == 6:
			_player.kill()
			await _wait_frames(2)
			_player.revive(Vector2(0, 150))
	if not is_instance_valid(_player):
		_fail("按鍵手感測試時 Player 消失了")
	await _clear_container(_mechanics_container)
	_player.smooth_start_enabled = false
	_player.set_size_factor(1.0)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
	await get_tree().process_frame

func _assert_can_move(stage_name: String) -> void:
	_player.position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	var start_x: float = _player.position.x
	Input.action_press("move_right")
	await _wait_frames(30)
	Input.action_release("move_right")
	if is_equal_approx(_player.position.x, start_x):
		_fail("「%s」階段後，拔除組件時 Player 無法移動" % stage_name)
