extends CharacterBody2D

# 唯一的物理腳本，學員禁區。
# 不要在這裡寫任何具名機制卡的邏輯 —— 機制卡透過 MoveContext 影響這裡的計算。

signal jumped
signal landed(impact_force: float)   # impact_force = 落地瞬間的 velocity.y 絕對值
signal hurt
signal died
signal direction_changed(dir: int)   # -1 左, 1 右
signal wall_hit
signal started_moving
signal stopped_moving

@export_group("移動參數")
## 水平移動速度，數值愈大角色跑得愈快。
@export_range(50.0, 500.0) var move_speed: float = 200.0
## 跳躍瞬間的初始速度，數值愈大跳得愈高。
@export_range(100.0, 800.0) var jump_force: float = 400.0
## 重力加速度，數值愈大角色下墜（或重力翻轉後上升）愈快。
@export_range(200.0, 2000.0) var gravity: float = 980.0
## 地面摩擦係數：0 = 像冰面一樣滑不停，1 = 放開方向鍵立刻煞停。
@export_range(0.0, 1.0) var ground_friction: float = 0.8
## 速度上限（像素／秒）：所有東西推出來的速度加起來都不會超過這個值，太快會穿牆。
## 一格是 16 像素；速度到 960 差不多每幀走一整格
@export_range(400.0, 2000.0) var max_speed: float = 1200.0

@export_group("按鍵手感")
## 晚一點按也能跳（又叫「土狼時間」）：走出平台邊緣之後，還有一小段時間按跳躍也跳得起來
@export var late_jump_enabled: bool = true
## 走出平台邊緣之後，還有幾秒可以跳
@export_range(0.02, 0.3) var late_jump_time: float = 0.1
## 早一點按也能跳（又叫「預輸入」）：快落地前就按跳躍，落地的瞬間自動跳起來
@export var early_jump_enabled: bool = true
## 落地前幾秒內按的跳躍，落地時還算數
@export_range(0.02, 0.3) var early_jump_time: float = 0.1
## 短按小跳、長按大跳：跳起來之後很快放開跳躍鍵，就只跳一點點高
@export var short_jump_enabled: bool = true
## 提早放開時往上的速度砍掉多少：0.1 = 只少一點點，0.9 = 幾乎馬上往下掉
@export_range(0.1, 0.9) var short_jump_strength: float = 0.5
## 頂頭修正：往上跳時頭只差幾個像素撞到天花板的邊角，就自動往旁邊推開讓你跳上去
@export var corner_fix_enabled: bool = true
## 差幾個像素以內會幫你推開（一格是 16 像素）
@export_range(1, 8) var corner_fix_size: int = 4
## 起跑加速：從停下到全速要一小段時間，比較有重量感（預設關，打開後角色會比較「滑」）
@export var smooth_start_enabled: bool = false
## 從停下到全速要幾秒
@export_range(0.02, 0.5) var speed_up_time: float = 0.1

var visual: Node2D = null
var size_factor: float = 1.0

var _mechanics: Array[Node] = []
var _last_direction: int = 0
var _was_moving: bool = false
var _was_on_wall: bool = false
var _is_dead: bool = false
var _damage_scale: float = 1.0
var _knockback_scale: float = 1.0
var _base_collision_size: Vector2 = Vector2.ZERO
var _cached_jump_scale: float = 1.0
var _cached_input_locked: bool = false
var _impulse_grace_left: float = 0.0
var _frozen: bool = false
var _juice_layer = null
var _late_jump_left: float = 0.0    # 離開地面後還剩幾秒可以跳（土狼時間）
var _early_jump_left: float = 0.0   # 空中按的跳躍還要記幾秒（預輸入）
var _short_jump_armed: bool = false # 這一跳是按著跳躍鍵跳的，提早放開要砍掉往上的速度
var _replaying_jump: bool = false   # 正在重播預輸入的跳躍鍵（這時跳起來也算「按著跳躍鍵跳的」）

const _JuiceLayer := preload("res://player/JuiceLayer.gd")

# 自己的跳躍用最低優先權掛在 InputRouter，讓蓄力青蛙跳這類卡可以用更高優先權攔截跳躍鍵，
# 攔截成功時這裡的跳躍完全不會被呼叫（見 InputRouter 的優先權機制）
const _JUMP_PRIORITY := -1000
# add_impulse() 之後這段時間內不套用地面摩擦力，讓衝量至少有機會真正發揮效果
const _IMPULSE_GRACE_DURATION := 0.15

# 啟動時找視覺節點，記住碰撞形狀原始尺寸，註冊自己的跳躍，並掃描 Mechanics／Juice／Abilities
# 底下現有的組件逐一註冊
func _ready() -> void:
	add_to_group("player")
	_find_visual()
	_remember_base_collision_size()
	_create_juice_layer()
	InputRouter.bind(self, "jump", InputRouter.PRESSED, _on_jump_pressed, _JUMP_PRIORITY)
	if has_node("Mechanics"):
		_register_children($Mechanics, true)
	if has_node("Juice"):
		_register_children($Juice, false)
	if has_node("Abilities"):
		_register_children($Abilities, false)

# 預設跳躍：地面上按下跳躍鍵就跳，除非被更高優先權的機制卡攔截掉（例如蓄力青蛙跳）
func _on_jump_pressed() -> bool:
	if _is_dead or _cached_input_locked:
		return false
	if not can_ground_jump():
		# 跳不起來：記下來，在 early_jump_time 秒內落地就自動跳（預輸入）
		if early_jump_enabled:
			_early_jump_left = early_jump_time
		return false
	_early_jump_left = 0.0
	force_jump(_cached_jump_scale)
	return true

# 記住 CollisionShape2D 原始尺寸，之後 set_size_factor() 要拿來算縮放後的尺寸；
# 順手把 shape 資源複製一份自己用，避免改到場景檔裡其他地方共用的同一份資源
func _remember_base_collision_size() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or not (col.shape is RectangleShape2D):
		return
	col.shape = col.shape.duplicate()
	_base_collision_size = (col.shape as RectangleShape2D).size

# 建立表現層：算出腳底在 Visual 座標裡的位置，讓 Juice 的擠壓、傾斜以腳底為中心
func _create_juice_layer() -> void:
	if visual == null:
		return
	var foot_y := 0.0
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col and _base_collision_size != Vector2.ZERO:
		foot_y = col.position.y + _base_collision_size.y * 0.5
	foot_y -= visual.position.y
	if not is_zero_approx(visual.scale.y):
		foot_y /= absf(visual.scale.y)
	_juice_layer = _JuiceLayer.new(visual, foot_y)

# 尋找視覺節點：先找 player_visual 群組，找不到就退而找 Visual 子節點，都沒有就發警告
func _find_visual() -> void:
	for n in get_tree().get_nodes_in_group("player_visual"):
		if is_ancestor_of(n):
			visual = n
			break
	if visual == null and has_node("Visual"):
		visual = $Visual as Node2D
	if visual == null:
		push_warning("[Player] 找不到視覺節點，請在關卡場景裡幫 Player 加一個叫 Visual 的子節點（或加入 player_visual 群組）")
		printerr("⚠ [Player] player.visual 是 null，跟視覺相關的 Juice 組件不會生效")

# 把籃子裡現有的子節點逐一註冊，並監聽之後新增的子節點
func _register_children(container: Node, track_apply: bool) -> void:
	for child in container.get_children():
		_try_setup(child, track_apply)
	container.child_entered_tree.connect(func(n): _try_setup(n, track_apply))

# 幫單一子節點呼叫 setup()，沒有 setup() 就發警告表示它掛錯位置
func _try_setup(child: Node, track_apply: bool) -> void:
	if child.has_method("setup"):
		child.setup(self)
		if track_apply and child.has_method("apply"):
			_mechanics.append(child)
	else:
		push_warning("[Player] %s 沒有 setup()，可能不是合法的組件" % child.name)

# 每個物理幀的主流程：收集機制卡建議、套用移動與重力、處理跳躍與位移
func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	var ctx := MoveContext.new()
	ctx.delta = delta
	for m in _mechanics:
		if is_instance_valid(m) and m.enabled:
			m.apply(ctx)
	if _frozen:
		ctx.movement_frozen = true
		ctx.input_locked = true
	_damage_scale = ctx.damage_scale
	_knockback_scale = ctx.knockback_scale
	_cached_jump_scale = ctx.jump_scale
	_cached_input_locked = ctx.input_locked

	var pre_on_floor := is_on_floor()
	var pre_fall_speed: float = velocity.dot(-up_direction)

	_apply_horizontal(ctx, delta)
	_apply_vertical(ctx, delta)
	_update_short_jump()
	velocity = velocity.limit_length(max_speed)
	_fix_corner(delta)

	move_and_slide()

	_emit_landing(pre_on_floor, pre_fall_speed)
	_emit_wall_hit()
	_update_jump_assist(delta)

# 按鍵手感：站在地上時補滿土狼時間、離開地面後倒數；空中按過跳躍、在時間內落地就重播一次跳躍鍵
func _update_jump_assist(delta: float) -> void:
	if is_on_floor():
		_late_jump_left = late_jump_time
	else:
		_late_jump_left = maxf(_late_jump_left - delta, 0.0)
	if _early_jump_left <= 0.0:
		return
	_early_jump_left -= delta
	if is_on_floor():
		_early_jump_left = 0.0
		# 透過 InputRouter 重播，讓蓄力青蛙跳這類卡照樣先收到；已經放開跳躍鍵就當作點一下
		_replaying_jump = true
		InputRouter.replay_press(&"jump", not Input.is_action_pressed("jump"))
		_replaying_jump = false

# 短按小跳：按著跳躍鍵跳起來、還在往上的時候放開，往上的速度砍掉 short_jump_strength；開始往下掉或落地就不再管
func _update_short_jump() -> void:
	if not _short_jump_armed:
		return
	var rising: float = velocity.dot(up_direction)
	if rising <= 0.0:
		_short_jump_armed = false
		return
	if not Input.is_action_pressed("jump"):
		_short_jump_armed = false
		velocity -= up_direction * rising * short_jump_strength

# 頂頭修正：往上飛、這一幀頭會撞到天花板時，看看往左或往右推幾個像素能不能閃過邊角，能就推過去
func _fix_corner(delta: float) -> void:
	if not corner_fix_enabled:
		return
	var rising: float = velocity.dot(up_direction)
	if rising <= 0.0:
		return
	var motion: Vector2 = up_direction * rising * delta
	var hit := KinematicCollision2D.new()
	if not test_move(global_transform, motion, hit) or hit.get_normal().dot(up_direction) > -0.7:
		return
	var side: Vector2 = up_direction.orthogonal()
	for i in range(1, corner_fix_size + 1):
		for dir in [1.0, -1.0]:
			var shift: Vector2 = side * dir * i
			if test_move(global_transform, shift):
				continue
			if not test_move(global_transform.translated(shift), motion):
				global_position += shift
				return

# 依輸入或機制卡指定的方向計算水平速度
func _apply_horizontal(ctx: MoveContext, delta: float) -> void:
	if _impulse_grace_left > 0.0:
		_impulse_grace_left -= delta

	# movement_frozen 蓋過 auto_run_dir：規則卡要求「整個人不能動」時，不能被還在場上
	# 的主限制卡的強制方向蓋回去，所以這裡要比 auto_run_dir 更早判斷、直接短路
	if ctx.movement_frozen:
		velocity.x = 0.0
		if _was_moving:
			_was_moving = false
			stopped_moving.emit()
		return

	var input_dir := 0.0
	if ctx.auto_run_dir != 0:
		input_dir = float(ctx.auto_run_dir)
	elif not ctx.input_locked:
		input_dir = Input.get_axis("move_left", "move_right")

	if input_dir != 0.0:
		var target: float = input_dir * move_speed * ctx.speed_scale
		# 起跑加速：還沒到全速（或正在轉向）就慢慢加上去；已經比全速快（被衝刺、彈射推出去）照舊直接變成全速
		if smooth_start_enabled and (signf(velocity.x) != signf(target) or absf(velocity.x) < absf(target)):
			var accel: float = move_speed * ctx.speed_scale / maxf(speed_up_time, 0.01)
			velocity.x = move_toward(velocity.x, target, accel * delta)
		else:
			velocity.x = target
		_update_facing(input_dir)
		if not _was_moving:
			_was_moving = true
			started_moving.emit()
	elif (not ctx.input_locked or is_on_floor()) and _impulse_grace_left <= 0.0:
		# input_locked 時，只有站在地面上才套用摩擦力（落地會自然停下）；在空中的話完全不碰
		# 水平速度，讓 add_impulse() 加上去的衝量像自由飛行一樣純粹累加。另外剛加完衝量的
		# 短時間內（_impulse_grace_left）也不套用摩擦力，不然衝量加上去同一幀就被咬一口，
		# 之後每幀繼續咬，很快就被吃光，感覺不出效果（風扇、彈性宇宙、彈弓、後座力移動都會用到）
		var decel: float = move_speed * lerpf(2.0, 20.0, ground_friction) * ctx.friction_scale * delta
		velocity.x = move_toward(velocity.x, 0.0, decel)
		if _was_moving and is_zero_approx(velocity.x):
			_was_moving = false
			stopped_moving.emit()

# 把重力套用到垂直速度上
func _apply_vertical(ctx: MoveContext, delta: float) -> void:
	if ctx.movement_frozen:
		velocity.y = 0.0
		return
	velocity += -up_direction * gravity * ctx.gravity_scale * delta

# 偵測角色朝向是否改變，改變就發出訊號
func _update_facing(input_dir: float) -> void:
	var dir := int(sign(input_dir))
	if dir != 0 and dir != _last_direction:
		_last_direction = dir
		direction_changed.emit(dir)

# 偵測這一幀是不是剛落地，是的話發出落地訊號
func _emit_landing(pre_on_floor: bool, pre_fall_speed: float) -> void:
	if is_on_floor() and not pre_on_floor and pre_fall_speed > 0.0:
		landed.emit(pre_fall_speed)
		Events.player_landed.emit(pre_fall_speed)

# 偵測這一幀是不是剛撞牆，是的話發出撞牆訊號
func _emit_wall_hit() -> void:
	if is_on_wall() and not _was_on_wall:
		wall_hit.emit()
	_was_on_wall = is_on_wall()

# ---- 提供給機制卡的公開 API（機制卡不得直接寫 velocity） ----

# 翻轉重力方向，重力翻轉卡用這個
func flip_gravity() -> void:
	up_direction = -up_direction

# 施加一次性衝量，擊退、彈跳這類卡用這個
func add_impulse(v: Vector2) -> void:
	velocity += v
	_impulse_grace_left = _IMPULSE_GRACE_DURATION

# 縮放角色大小，變大變小卡用這個。不縮放整個物理節點（CharacterBody2D 的 scale
# 對碰撞判定不可靠），只縮放視覺節點，碰撞形狀直接改尺寸；
# 視覺節點原本的左右、上下翻面（自動奔跑、重力翻轉）保留不動
func set_size_factor(f: float) -> void:
	size_factor = f
	if visual:
		var flip := Vector2(-1.0 if visual.scale.x < 0.0 else 1.0, -1.0 if visual.scale.y < 0.0 else 1.0)
		visual.scale = flip * f
	if _base_collision_size == Vector2.ZERO:
		return
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		(col.shape as RectangleShape2D).size = _base_collision_size * f

# 讓角色受到傷害，內部委派給 Stats 扣血量；血量歸零時 Stats 會自動呼叫 kill()
func take_damage(amount: float = 1.0) -> void:
	if _is_dead:
		return
	Stats.add(Stats.HEALTH_KIND, -roundi(amount * _damage_scale))
	hurt.emit()
	Events.player_hurt.emit()

# 被攻擊打到（碰到敵人、尖刺、敵人子彈這類），扣血交給 take_damage()（也就是 Stats 的血量），
# 再加上擊退（會乘上機制卡調的擊退倍率）；
# 跟敵人、可破壞方塊用同一個受擊介面，攻擊方不用分辨打到的是誰
func take_hit(damage: int, knockback: Vector2, source: Node) -> void:
	if _is_dead:
		return
	Events.hit.emit(self, source)
	take_damage(damage)
	if not _is_dead:
		add_impulse(knockback * _knockback_scale)

# 宣告玩家死亡，實際要發生什麼事（重生、結算畫面…）由聽到 player_died 訊號的人決定
func kill() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector2.ZERO
	died.emit()
	Events.player_died.emit()

# 把玩家復活到指定位置，並重置所有狀態（由重生處理者呼叫）
func revive(at_position: Vector2) -> void:
	global_position = at_position
	velocity = Vector2.ZERO
	up_direction = Vector2.UP
	set_size_factor(1.0)
	Stats.refill(Stats.HEALTH_KIND)
	_is_dead = false
	_was_moving = false
	_was_on_wall = false
	_last_direction = 0
	_impulse_grace_left = 0.0
	_frozen = false
	_late_jump_left = 0.0
	_early_jump_left = 0.0
	_short_jump_armed = false
	for m in _mechanics:
		if is_instance_valid(m) and m.has_method("on_respawn"):
			m.on_respawn()
	Events.player_respawned.emit(self)

# 回傳玩家現在是不是死亡狀態（死掉之後、還沒被復活之前）
func is_dead() -> bool:
	return _is_dead

# 強制角色跳一次，倍率可以調跳多高，跳躍相關卡用這個
func force_jump(power_scale: float = 1.0) -> void:
	_late_jump_left = 0.0
	# 這一幀才剛放開也算（點得很快時，按下和放開可能落在同一幀）
	_short_jump_armed = short_jump_enabled and (_replaying_jump or Input.is_action_pressed("jump") or Input.is_action_just_released("jump"))
	velocity -= velocity.project(up_direction)
	velocity += up_direction * jump_force * power_scale
	jumped.emit()
	Events.player_jumped.emit()

# ---- 提供給 Juice 組件的表現層 API（作用在 Visual 的子節點上，不碰 Visual 本身，跟機制卡疊加） ----

# 讓角色外觀暫時壓扁或拉長，(1, 1) 是原本的樣子，擠壓拉伸這類 Juice 用這個
func set_juice_squash(source: Node, amount: Vector2) -> void:
	if _juice_layer:
		_juice_layer.set_squash(source, amount)

# 讓角色外觀暫時疊上一層顏色，亮度超過 1 會變亮（閃白），閃色這類 Juice 用這個
func set_juice_tint(source: Node, color: Color) -> void:
	if _juice_layer:
		_juice_layer.set_tint(source, color)

# 讓角色外觀暫時傾斜（弧度），傾斜這類 Juice 用這個
func set_juice_tilt(source: Node, angle: float) -> void:
	if _juice_layer:
		_juice_layer.set_tilt(source, angle)

# 撤掉這個組件對外觀的所有影響，Juice 移除或重生時用這個
func clear_juice(source: Node) -> void:
	if _juice_layer:
		_juice_layer.clear(source)

# 回傳角色腳底的位置（重力翻轉後是貼著天花板那一側，會跟著體型變），粒子這類 Juice 用這個
func get_feet_position() -> Vector2:
	var half_height := _base_collision_size.y * 0.5 * size_factor
	return global_position - up_direction * half_height

# ---- 給學員用訊號連線的動作（都不帶參數，在「節點」面板把卡片或零件的訊號連到 Player 就能用） ----

# 動能歸零一次：當下的速度全部清掉，之後照常受重力、照常能移動
func stop_motion() -> void:
	velocity = Vector2.ZERO
	_impulse_grace_left = 0.0

# 停在原地：不受重力、不能移動、不能跳，直到呼叫 unfreeze() 或死亡重生為止
func freeze() -> void:
	_frozen = true
	velocity = Vector2.ZERO

# 解除 freeze()，恢復正常移動
func unfreeze() -> void:
	_frozen = false

# 回傳角色現在是不是站在地面上
func is_on_ground() -> bool:
	return is_on_floor()

# 回傳現在按跳躍能不能從地面起跳：站在地上，或剛走出平台邊緣還在「晚一點按也能跳」的時間內（往上飛的時候不算）。
# 二段跳、蹬牆跳這類卡用這個判斷「現在算不算在地上」，才不會把土狼時間裡的跳躍當成空中跳
func can_ground_jump() -> bool:
	if is_on_floor():
		return true
	return late_jump_enabled and _late_jump_left > 0.0 and velocity.dot(up_direction) <= 0.0

# 回傳玩家目前輸入的水平方向，範圍 -1 到 1
func get_move_input() -> float:
	return Input.get_axis("move_left", "move_right")
