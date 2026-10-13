extends StaticBody2D

# 單向平台：可以從下方穿過，只能從上方站立（用 Godot 內建的 one_way_collision）。
# 拖進場景就能用，不用連任何線。

## 平台寬度，單位是格（1 格 = 16 像素）
@export_range(1, 20) var width_tiles: int = 4

const _TILE_SIZE := 16.0
const _THICKNESS := 8.0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: ColorRect = $Visual

# 依格數算出平台寬度，套用到碰撞形狀（開啟單向碰撞）與外觀；底下有皮就換上皮
#（要先套好寬度，皮選了重複鋪滿／拉伸蓋滿才對得到；平台沒有狀態變化，不用留著 SkinLink）
func _ready() -> void:
	var width := width_tiles * _TILE_SIZE
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, _THICKNESS)
	_shape.shape = shape
	_shape.one_way_collision = true
	_visual.position = Vector2(-width / 2.0, -_THICKNESS / 2.0)
	_visual.size = Vector2(width, _THICKNESS)
	SkinLink.new(self, _visual)
