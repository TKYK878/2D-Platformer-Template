@tool
extends StaticBody2D

# 不反彈方塊：實心地形，掛了彈性宇宙卡的玩家撞到它不會彈開，會像一般撞牆、落地一樣停下來；
# 撞到其他牆壁、地板照常反彈。可以當牆、當地板、當平台，拖進場景就能用，不用連任何線。

## 寬度，單位是格（1 格 = 16 像素）
@export_range(1, 40) var width_tiles: int = 2:
	set(value):
		width_tiles = value
		_apply_size()

## 高度，單位是格（1 格 = 16 像素）
@export_range(1, 40) var height_tiles: int = 2:
	set(value):
		height_tiles = value
		_apply_size()

const _TILE_SIZE := 16.0

# 加入 no_bounce group（彈性宇宙卡認這個），設定碰撞層，套用大小；底下有皮就換上皮
#（要先套好大小，皮選了重複鋪滿／拉伸蓋滿才對得到；方塊沒有狀態變化，不用留著 SkinLink）
func _ready() -> void:
	add_to_group("no_bounce")
	collision_layer = Layers.TERRAIN
	collision_mask = 0
	_apply_size()
	if not Engine.is_editor_hint():
		SkinLink.new(self, $Visual)

# 依格數算出大小，套用到碰撞形狀與外觀（編輯器裡拉拉桿就會即時變大變小）
func _apply_size() -> void:
	if not has_node("CollisionShape2D") or not has_node("Visual"):
		return  # 場景還在載入、子節點還沒加進來時，等 _ready() 再套用
	var size := Vector2(width_tiles, height_tiles) * _TILE_SIZE
	var shape := RectangleShape2D.new()
	shape.size = size
	$CollisionShape2D.shape = shape
	$Visual.position = -size / 2.0
	$Visual.size = size
