extends Area2D

# 尖刺：感應，玩家碰到時依 penalty 扣血或直接死亡，碰一次算一次（不像岩漿是持續扣血）。
# 拖進場景就能用，不用連任何線。也可以用 activate/deactivate/toggle 開關（例如踩按鈕讓尖刺升起來），
# 關掉時碰到不會怎樣、外觀變暗，也不算危險物（彈珠台、碰觸即死不會對它反應）；開關狀態重生時不重置。

## 處罰方式：扣血、直接死亡
@export_enum("扣血", "即死") var penalty: int = 0

## 扣血量，penalty 是「即死」時不會用到
@export_range(1, 10) var damage: int = 1

## 扣血時把玩家彈開的力道，0 = 不彈開只扣血；penalty 是「即死」時不會用到
@export_range(0.0, 800.0) var knockback: float = 300.0

## 一開始就是開著的（關著的話要靠別的零件的訊號 activate 才會傷人）
@export var start_on: bool = true

const _PENALTY_HEALTH := 0


var _active: bool = true
var _skin: SkinLink = null

## 開啟：開始傷人；開啟當下已經站在上面的玩家也會被刺到
func activate() -> void:
	if _active:
		return
	_set_active(true)
	for body in get_overlapping_bodies():
		_on_body_entered(body)

## 關閉：碰到不會怎樣
func deactivate() -> void:
	_set_active(false)

## 切換
func toggle() -> void:
	if _active:
		deactivate()
	else:
		activate()

# 設定碰撞層／遮罩，只偵測玩家，套用一開始要不要開；底下有皮就換上皮
func _ready() -> void:
	_skin = SkinLink.new(self, $Visual)
	collision_layer = Layers.SENSOR
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)
	_set_active(start_on)

# 切換開關狀態：開著才加入 hazard group（彈珠台、碰觸即死認這個），關掉時變暗（有皮就換皮的樣子）
func _set_active(is_active: bool) -> void:
	_active = is_active
	if _active:
		add_to_group("hazard")
	else:
		remove_from_group("hazard")
	_skin.show_dark(not _active)

# 玩家碰到：依 penalty 打玩家一下（扣血＋把玩家往外、往上彈開）或直接死亡；關著時不會怎樣
func _on_body_entered(body: Node) -> void:
	if not _active or not body.is_in_group("player"):
		return
	if penalty == _PENALTY_HEALTH:
		var player := body as CharacterBody2D
		if player != null and player.has_method("take_hit"):
			var away := (player.global_position - global_position).normalized()
			var direction := (away + player.up_direction * 0.5).normalized()
			player.take_hit(damage, direction * knockback, self)
	else:
		if body.has_method("kill"):
			body.kill()
