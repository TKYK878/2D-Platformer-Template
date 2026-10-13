extends RigidBody2D

# 箱子：會動，玩家撞上去可以推著走；被攻擊時只會被擊退，不會受傷、沒有耐久。
# 拖進場景就能用，不用連任何線。

## 重量：輕的比較好推、重的比較不好推
@export_enum("輕", "重") var weight: int = 0

## 會不會擋子彈：關掉的話子彈（玩家的、敵人的都一樣）會直接穿過去
@export var block_bullets: bool = true

const _LIGHT_MASS := 1.0
const _HEAVY_MASS := 4.0

var _start_position: Vector2 = Vector2.ZERO

# 依重量套用質量，鎖住旋轉讓箱子不會被撞得團團轉，加入 box group 讓其他系統辨識；底下有皮就換上皮
#（箱子沒有狀態變化，不用留著 SkinLink）
func _ready() -> void:
	add_to_group("box")
	SkinLink.new(self, $Visual)
	mass = _LIGHT_MASS if weight == 0 else _HEAVY_MASS
	lock_rotation = true
	collision_layer = Layers.BOX
	collision_mask = Layers.PLAYER | Layers.TERRAIN | Layers.BOX
	_start_position = global_position

# 把自己恢復到關卡開始時的狀態：回到原位、停止移動（重生處理者呼叫）
func reset() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, _start_position))
	global_position = _start_position

# 被攻擊打到：只受擊退，不扣血、沒有耐久
func take_hit(_damage: int, knockback: Vector2, source: Node) -> void:
	Events.hit.emit(self, source)
	apply_central_impulse(knockback)
