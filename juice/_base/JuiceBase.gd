@tool
extends Node2D
class_name JuiceBase

# Juice 組件的共用基底。子類別也要加 @tool，Inspector 才會依觸發時機隱藏／顯示欄位。
# 一次型組件覆寫 _on_play()；持續型組件讓 _is_continuous() 回傳 true（timing 會被藏起來）。
# 重生時要歸零的狀態寫在 _on_reset()；外觀一律透過 player.set_juice_squash() 這類表現層 API。

## 關閉時這個 Juice 組件不會生效，但仍會顯示在場景裡。
@export var enabled: bool = true
## 什麼時候要播放這個效果。選「不自動觸發」的話，可以把卡片或零件的訊號連到這個組件的 play()。
@export_enum("跳躍時", "落地時", "受傷時", "死亡時", "撞牆時", "開始移動時", "轉向時", "重生時",
	"打中東西時", "打倒敵人時", "撿到東西時", "過關時", "不自動觸發")
var timing: int = TIMING_LANDED:
	set(value):
		timing = value
		notify_property_list_changed()
## 勾選時效果強度跟著落地力道變化：輕輕落地效果小、從高處摔下效果大。
@export var follow_impact: bool = true

const TIMING_JUMPED := 0
const TIMING_LANDED := 1
const TIMING_HURT := 2
const TIMING_DIED := 3
const TIMING_WALL_HIT := 4
const TIMING_STARTED_MOVING := 5
const TIMING_TURNED := 6
const TIMING_RESPAWNED := 7
const TIMING_HIT := 8
const TIMING_ENEMY_DIED := 9
const TIMING_ITEM_COLLECTED := 10
const TIMING_LEVEL_CLEARED := 11
const TIMING_MANUAL := 12

# 同一個組件這段時間內只播一次（毫秒），避免每幀落地這類情況塞爆畫面
const _REPEAT_GUARD_MS := 50
# 落地力道等於這個值時效果強度是 1（大約是一般跳躍落地的速度）
const _IMPACT_REFERENCE := 400.0
const _MIN_IMPACT_POWER := 0.25
const _MAX_IMPACT_POWER := 2.0

var player: Node = null

# 這次觸發發生的位置：玩家事件是玩家位置，打中東西／打倒敵人／撿到東西是事件發生的位置
var _trigger_position: Vector2 = Vector2.ZERO
# 這次觸發的強度倍率：一般是 1；「落地時」勾選 follow_impact 時跟著落地力道變化
var _trigger_power: float = 1.0

var _last_play_ms: int = -_REPEAT_GUARD_MS
var _last_dir: int = 0
var _connections: Array = []   # [訊號, Callable] 成對記下，重新 setup 或移除時拔掉

# Player 呼叫，註冊自己、依觸發時機接好事件，並執行子類別初始化
func setup(p: Node) -> void:
	_disconnect_all()
	player = p
	_last_dir = 0
	_listen(Events.player_respawned, _on_player_respawned)
	_listen(JuiceSwitch.toggled, _on_juice_switch_toggled)
	if _is_continuous():
		visible = JuiceSwitch.is_on()
	else:
		_connect_timing()
	_on_setup()
	print("[%s] 已啟用" % name)

# 播放一次效果，可以把任何卡片或零件的訊號連到這裡（訊號帶的參數會被忽略）
func play(..._args: Array) -> void:
	if player == null or not is_instance_valid(player):
		return
	_trigger(player.global_position, 1.0)

# 清掉這個效果：停掉正在播的、撤掉它對角色外觀的影響，之後照常觸發（訊號帶的參數會被忽略）
func clear(..._args: Array) -> void:
	_on_reset()
	if is_instance_valid(player):
		player.clear_juice(self)

# 打開這個 Juice（跟 Inspector 勾 enabled 一樣），訊號帶的參數會被忽略
func turn_on(..._args: Array) -> void:
	enabled = true
	if _is_continuous():
		visible = JuiceSwitch.is_on()

# 關掉這個 Juice（跟 Inspector 取消勾 enabled 一樣），順便清掉它的效果；之後要 turn_on 才會再作用
func turn_off(..._args: Array) -> void:
	enabled = false
	clear()
	if _is_continuous():
		visible = false

# Juice 組件在這裡做初始化，例如設定初始狀態
func _on_setup() -> void:
	pass

# 一次型 Juice 組件在這裡播放效果，_trigger_position、_trigger_power 已經準備好
func _on_play() -> void:
	pass

# 玩家重生時呼叫，Juice 組件在這裡停掉進行中的效果、把自己的狀態歸零
func _on_reset() -> void:
	pass

# 持續型 Juice 組件（拖進來就一直作用，例如殘影）覆寫成回傳 true
func _is_continuous() -> bool:
	return false

# 回傳現在能不能作用（組件自己開著、Juice 總開關也開著），持續型組件每幀作用前用這個檢查
func _is_juice_on() -> bool:
	return enabled and JuiceSwitch.is_on()

# 依「觸發時機」接上對應的玩家或世界事件
func _connect_timing() -> void:
	match timing:
		TIMING_JUMPED: _listen(player.jumped, func(): _trigger_at_player())
		TIMING_LANDED: _listen(player.landed, _on_player_landed)
		TIMING_HURT: _listen(player.hurt, func(): _trigger_at_player())
		TIMING_DIED: _listen(player.died, func(): _trigger_at_player())
		TIMING_WALL_HIT: _listen(player.wall_hit, func(): _trigger_at_player())
		TIMING_STARTED_MOVING: _listen(player.started_moving, func(): _trigger_at_player())
		TIMING_TURNED: _listen(player.direction_changed, _on_player_direction_changed)
		TIMING_RESPAWNED: _listen(Events.player_respawned, func(_p): _trigger_at_player())
		TIMING_HIT: _listen(Events.hit, _on_hit)
		TIMING_ENEMY_DIED: _listen(Events.enemy_died, func(pos: Vector2): _trigger(pos, 1.0))
		TIMING_ITEM_COLLECTED: _listen(Events.item_collected, func(pos: Vector2): _trigger(pos, 1.0))
		TIMING_LEVEL_CLEARED: _listen(Events.level_cleared, func(): _trigger_at_player())

# 在玩家位置觸發一次
func _trigger_at_player() -> void:
	_trigger(player.global_position, 1.0)

# 落地時觸發，勾選 follow_impact 的話強度跟著落地力道走
func _on_player_landed(impact_force: float) -> void:
	var power := 1.0
	if follow_impact:
		power = clampf(impact_force / _IMPACT_REFERENCE, _MIN_IMPACT_POWER, _MAX_IMPACT_POWER)
	_trigger(player.global_position, power)

# 轉向時觸發；剛開始移動（之前還沒有方向）不算轉向
func _on_player_direction_changed(dir: int) -> void:
	var was := _last_dir
	_last_dir = dir
	if was != 0 and was != dir:
		_trigger_at_player()

# 打中東西時觸發：被打的是玩家自己就不算（那是「受傷時」），位置是被打的東西
func _on_hit(target: Node, _source: Node) -> void:
	if target == player:
		return
	var pos: Vector2 = target.global_position if target is Node2D else player.global_position
	_trigger(pos, 1.0)

# 檢查開關（組件自己的、總開關）與連發保護，記下觸發位置與強度，交給子類別播放
func _trigger(pos: Vector2, power: float) -> void:
	if not _is_juice_on():
		return
	var now := Time.get_ticks_msec()
	if now - _last_play_ms < _REPEAT_GUARD_MS:
		return
	_last_play_ms = now
	_trigger_position = pos
	_trigger_power = power
	_on_play()

# 玩家重生：子類別歸零，撤掉這個組件對角色外觀的所有影響
func _on_player_respawned(_p: Node) -> void:
	_last_dir = 0
	_on_reset()
	if is_instance_valid(player):
		player.clear_juice(self)

# Juice 總開關切換：關掉時停掉進行中的效果、撤掉對外觀的影響；持續型跟著隱藏／顯示
func _on_juice_switch_toggled(on: bool) -> void:
	if not on:
		_on_reset()
		if is_instance_valid(player):
			player.clear_juice(self)
	if _is_continuous():
		visible = on

# 接上一個訊號並記下來，之後可以一次拔掉
func _listen(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_connections.append([sig, callable])

# 拔掉之前接上的所有訊號
func _disconnect_all() -> void:
	for c in _connections:
		var sig: Signal = c[0]
		if not sig.is_null() and sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_connections.clear()

# 只在「落地時」顯示 follow_impact；持續型組件把 timing 跟 follow_impact 都藏起來
func _validate_property(property: Dictionary) -> void:
	var should_hide := false
	if property.name == "timing":
		should_hide = _is_continuous()
	elif property.name == "follow_impact":
		should_hide = _is_continuous() or timing != TIMING_LANDED
	if should_hide:
		property.usage &= ~PROPERTY_USAGE_EDITOR

# 檢查有沒有被正確掛在 Juice 底下，沒有就發警告
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# 沒有被 setup 就是掛錯位置了，要看得見
	await get_tree().process_frame
	if player == null:
		push_warning("[%s] 沒有掛在 Player 的 Juice 底下，不會生效" % name)
		printerr("⚠ [%s] 請把這個節點拖進 Player → Juice 底下" % name)

# 拔掉組件時拔掉事件、撤掉對角色外觀的影響，讓外觀立刻還原
func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_disconnect_all()
	if is_instance_valid(player):
		player.clear_juice(self)
	player = null
