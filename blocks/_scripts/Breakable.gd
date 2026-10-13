@tool
extends StaticBody2D

# 可破壞方塊：實心，被打或被高速撞擊會扣耐久，歸零時碎裂。碎裂後依 respawn_time
# 決定要不要重生（0 表示不重生）。拖進場景就能用，不用連任何線。
#
# 根節點直接是碰撞體本身（不像 Door/CrumbleFloor 包一層 Body 子節點）：因為這裡要實作
# Hittable，近戰／遠程攻擊的判定區用 body_entered 抓到的一定是實際碰撞的那個節點，
# 如果碰撞形狀包在子節點裡，take_hit() 掛在根節點上會抓不到。

## 耐久次數，被打幾下才會壞
@export_range(1, 10) var durability: int = 3

## 碎裂後幾秒重生，0 表示不會重生
@export_range(0.0, 10.0) var respawn_time: float = 3.0

## 高速撞擊也能直接打破（越跑越快、彈弓、後座力、彈跳台擊飛、掉落的箱子這類情境適用）
@export var break_by_impact: bool = true

## 撞擊速度門檻，物體移動速度超過這個值撞上才會被打破
@export_range(100.0, 1000.0) var impact_speed: float = 400.0

## 完全碎裂時發出，給學員自己接特效／音效用
signal broken

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _detector: Area2D = $Detector

var _durability_left: int = 0
var _is_broken: bool = false
var _generation: int = 0  # 每次 reset() 加一，讓 reset 之前排好的重生計時器失效
var _skin: SkinLink = null

# 被攻擊打到，扣耐久，歸零時碎裂
func take_hit(damage: int, _knockback: Vector2, source: Node) -> void:
	Events.hit.emit(self, source)
	if _is_broken:
		return
	_apply_damage(maxi(damage, 1))

# 設定碰撞層／遮罩，監聽高速撞擊，套用一開始的耐久；底下有皮就換上皮
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_skin = SkinLink.new(self, $Visual)
	add_to_group("signal_source")
	_durability_left = durability
	collision_layer = Layers.TERRAIN
	collision_mask = 0
	_detector.collision_layer = 0
	_detector.collision_mask = Layers.PLAYER | Layers.BOX
	_detector.body_entered.connect(_on_detector_entered)
	_update_visual()

# 高速撞擊判定：進入偵測區當下的速度超過門檻就直接打破
func _on_detector_entered(body: Node) -> void:
	if not break_by_impact or _is_broken:
		return
	var velocity = body.get("velocity")
	if velocity is Vector2 and velocity.length() >= impact_speed:
		_break()

# 扣耐久，歸零時碎裂
func _apply_damage(amount: int) -> void:
	_durability_left -= amount
	if _durability_left <= 0:
		_break()
	else:
		_update_visual()

# 真正碎裂：關閉碰撞、隱藏外觀、發出訊號，依 respawn_time 決定要不要重生
func _break() -> void:
	if _is_broken:
		return
	_is_broken = true
	_shape.set_deferred("disabled", true)
	_skin.set_visible(false)
	broken.emit()
	if respawn_time > 0.0:
		var generation := _generation
		get_tree().create_timer(respawn_time).timeout.connect(func():
			if generation == _generation:
				_respawn()
		)

# 把自己恢復到關卡開始時的狀態：耐久補滿、碎掉的長回來（重生處理者呼叫）
func reset() -> void:
	_generation += 1
	_respawn()

# 重生：恢復耐久、碰撞與外觀
func _respawn() -> void:
	_is_broken = false
	_durability_left = durability
	_shape.set_deferred("disabled", false)
	_skin.set_visible(true)
	_update_visual()

# 依剩餘耐久調整外觀透明度（有皮就作用在皮上），讓學員看得出快壞了
func _update_visual() -> void:
	var ratio := float(_durability_left) / float(maxi(durability, 1))
	_skin.set_alpha(clampf(lerpf(0.35, 1.0, ratio), 0.35, 1.0))

# 編輯畫面持續請求重畫，讓虛線跟著訊號連接的變化即時更新
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

# 編輯畫面用：幫這個零件自己發出的每個訊號的每條連接畫一條虛線到目標節點
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	SignalLines.draw(self, broken)
