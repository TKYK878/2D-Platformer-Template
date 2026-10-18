extends RigidBody2D

# 箱子：會動，是實體（擋得住玩家、站得上去），玩家從側面走過去就會推著走（Player 呼叫 push()），卡在牆角就推不動；
# 被攻擊時只會被擊退，不會受傷、沒有耐久。
# 拖進場景就能用，不用連任何線。

## 推得動：取消勾的話變成固定在原地的實心方塊，站得上去、推不動（攻擊、推力器、彈射台、磁鐵也推不動），但還是算箱子（可以踩按鈕）
@export var can_push: bool = true

## 重量：輕的比較好推、重的比較不好推（推不動的箱子用不到）
@export_enum("輕", "重") var weight: int = 0

## 會不會擋子彈：關掉的話子彈（玩家的、敵人的都一樣）會直接穿過去
@export var block_bullets: bool = true

const _LIGHT_MASS := 1.0
const _HEAVY_MASS := 4.0
# 被玩家推的時候，箱子的速度是玩家走路速度的幾倍（重的推得比較慢）
const _LIGHT_PUSH := 0.8
const _HEAVY_PUSH := 0.4
# 速度上限（像素／秒）：一格是 16 像素，960 差不多每幀走一格，再快就可能一幀跳過整面牆（穿牆）
const _MAX_SPEED := 960.0

var _start_position: Vector2 = Vector2.ZERO

# 依重量套用質量，鎖住旋轉讓箱子不會被撞得團團轉，加入 box group 讓其他系統辨識；底下有皮就換上皮；
# 開連續碰撞偵測；跟玩家、地形、別的箱子、敵人都會互相擋住
#（箱子沒有狀態變化，不用留著 SkinLink）
func _ready() -> void:
	add_to_group("box")
	SkinLink.new(self, $Visual)
	mass = _LIGHT_MASS if weight == 0 else _HEAVY_MASS
	lock_rotation = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	collision_layer = Layers.BOX
	collision_mask = Layers.PLAYER | Layers.TERRAIN | Layers.BOX | Layers.ENEMY
	if not can_push:
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true
	_start_position = global_position

# 把自己恢復到關卡開始時的狀態：回到原位、停止移動（重生處理者呼叫）
func reset() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, _start_position))
	global_position = _start_position

# 每個物理幀把速度限制在上限以內，被推力器、彈射台推得再快也不會穿牆
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.linear_velocity = state.linear_velocity.limit_length(_MAX_SPEED)

# 被玩家推：往 dir（-1 左、1 右）的方向動，speed 是玩家這一幀要走的速度，輕的跟得上、重的比較慢
func push(dir: int, speed: float) -> void:
	if not can_push:
		return
	sleeping = false
	linear_velocity.x = dir * speed * (_LIGHT_PUSH if weight == 0 else _HEAVY_PUSH)

# 被攻擊打到：只受擊退，不扣血、沒有耐久
func take_hit(_damage: int, knockback: Vector2, source: Node) -> void:
	Events.hit.emit(self, source)
	apply_central_impulse(knockback)
