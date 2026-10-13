extends Node2D

# 開關方塊：地形，顏色決定加入 switch_red 或 switch_blue group，讓「開關世界」規則卡
# 統一控制同色方塊的開關。預設是實心，規則卡呼叫 set_active() 切換；玩家正站在方塊
# 範圍內時，開啟會延後到玩家離開再套用，避免把玩家卡進地形裡。

## 顏色：紅色組或藍色組，「開關世界」規則卡分開控制這兩組
@export_enum("紅", "藍") var color: int = 0

const _COLOR_RED := 0
const _RED := Color(0.85, 0.25, 0.25, 1)
const _BLUE := Color(0.25, 0.45, 0.9, 1)

@onready var _shape: CollisionShape2D = $Body/CollisionShape2D
@onready var _detector: Area2D = $Detector

var _active: bool = true
var _player_overlapping: bool = false
var _pending_activate: bool = false
var _skin: SkinLink = null

# 開關世界卡用這個切換方塊是不是實心；玩家正站在裡面時，開啟會延後到玩家離開再套用
func set_active(active: bool) -> void:
	if active and _player_overlapping:
		_pending_activate = true
		return
	_pending_activate = false
	_active = active
	_apply_state()

# 依顏色加入對應的 group、換外觀顏色，設定碰撞層／遮罩，套用一開始的實心狀態；底下有皮就換上皮
func _ready() -> void:
	add_to_group("switch_red" if color == _COLOR_RED else "switch_blue")
	var visual: ColorRect = $Visual
	visual.color = _RED if color == _COLOR_RED else _BLUE
	_skin = SkinLink.new(self, visual)
	_detector.collision_layer = 0
	_detector.collision_mask = Layers.PLAYER
	_detector.body_entered.connect(_on_detector_entered)
	_detector.body_exited.connect(_on_detector_exited)
	_apply_state()

# 玩家進到方塊範圍內，記住這件事，避免之後把玩家卡住
func _on_detector_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_overlapping = true

# 玩家離開方塊範圍：如果先前有一個被延後的開啟請求，這時候才真的套用
func _on_detector_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_overlapping = false
	if _pending_activate:
		_pending_activate = false
		_active = true
		_apply_state()

# 把目前的開關狀態套用到碰撞與外觀上（關掉時藏起來，有皮就換皮的樣子）
func _apply_state() -> void:
	_shape.set_deferred("disabled", not _active)
	_skin.show_hidden(not _active)
