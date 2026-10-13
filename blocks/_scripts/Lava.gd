extends Node2D

# 岩漿：實心，站在上面會每秒扣血；instant_kill 開啟時站上去直接死亡。
# 拖進場景就能用，不用連任何線。也可以用 activate/deactivate/toggle 開關（例如踩按鈕讓岩漿冷卻），
# 關掉時變成普通地板、外觀變暗，也不算危險物、不算岩漿（地板是岩漿卡不認）；開關狀態重生時不重置。

## 每秒扣血量，instant_kill 關閉時才有作用
@export_range(1.0, 50.0) var damage_per_second: float = 10.0

## 站上去直接死亡，不用慢慢扣血
@export var instant_kill: bool = false

## 一開始就是開著的（關著的話是普通地板，要靠別的零件的訊號 activate 才會燙）
@export var start_on: bool = true

const _TICK_INTERVAL := 1.0

@onready var _shape: CollisionShape2D = $Body/CollisionShape2D
@onready var _detector: Area2D = $Detector

var _overlapping_players: Array[Node] = []
var _tick_elapsed: float = 0.0
var _active: bool = true
var _skin: SkinLink = null

## 開啟：開始燙人；即死模式下，開啟當下已經站在上面的玩家直接死亡
func activate() -> void:
	if _active:
		return
	_set_active(true)
	if instant_kill:
		for body in _overlapping_players.duplicate():
			if is_instance_valid(body) and body.has_method("kill"):
				body.kill()

## 關閉：變成普通地板
func deactivate() -> void:
	_set_active(false)

## 切換
func toggle() -> void:
	if _active:
		deactivate()
	else:
		activate()

# 設定碰撞層／遮罩，套用一開始要不要開；底下有皮就換上皮
func _ready() -> void:
	_skin = SkinLink.new(self, $Visual)
	_detector.collision_layer = 0
	_detector.collision_mask = Layers.PLAYER
	_detector.body_entered.connect(_on_detector_entered)
	_detector.body_exited.connect(_on_detector_exited)
	_set_active(start_on)

# 切換開關狀態：開著才加入 hazard／lava group（彈珠台、地板是岩漿認這個），關掉時變暗（有皮就換皮的樣子）、扣血計時重來
func _set_active(is_active: bool) -> void:
	_active = is_active
	_tick_elapsed = 0.0
	for group in ["hazard", "lava"]:
		if _active:
			add_to_group(group)
		else:
			remove_from_group(group)
	_skin.show_dark(not _active)

# 玩家碰到：記進名單（關著時也記，開啟當下才知道誰站在上面）；開著的即死模式直接殺死，否則每秒扣血
func _on_detector_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_overlapping_players.append(body)
	if _active and instant_kill and body.has_method("kill"):
		body.kill()

# 玩家離開，移出扣血名單
func _on_detector_exited(body: Node) -> void:
	_overlapping_players.erase(body)

# 每秒對站在上面的玩家扣一次血；關著時不扣
func _physics_process(delta: float) -> void:
	if not _active or instant_kill or _overlapping_players.is_empty():
		_tick_elapsed = 0.0
		return
	_tick_elapsed += delta
	if _tick_elapsed < _TICK_INTERVAL:
		return
	_tick_elapsed -= _TICK_INTERVAL
	for body in _overlapping_players:
		if is_instance_valid(body) and body.has_method("take_damage"):
			body.take_damage(damage_per_second)
