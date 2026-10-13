@tool
extends Node2D

# 敵人射擊：拖到關卡裡某個 Enemy 的底下，那個敵人就會定時開槍。
# 敵人主動找到這個節點並呼叫 setup()，不用連任何線；敵人被打倒時停火，重生復位時計時重來。
# 子彈用 Bullet.spawn()（敵方陣營），從這個節點的位置射出，想改槍口位置就移動這個節點。
# 也可以用 activate/deactivate/toggle 開關（例如踩按鈕讓敵人開始開槍）；開關狀態重生時不重置。

@export_group("射擊")
## 往哪裡射
@export_enum("朝玩家", "朝面向方向", "固定往左", "固定往右", "固定往上", "固定往下") var aim_type: int = 0:
	set(value):
		aim_type = value
		queue_redraw()
## 每隔幾秒射一發
@export_range(0.3, 5.0) var cooldown: float = 1.5
## 玩家在幾格以內才會開槍，0 代表不管多遠都開槍（1 格 = 16 像素）
@export_range(0, 30) var detect_range_tiles: int = 10:
	set(value):
		detect_range_tiles = value
		queue_redraw()
## 開槍前先停下來一下，讓玩家看得出牠要開槍了
@export var stop_to_shoot: bool = true
## 一開始就會開槍（關著的話要靠別的零件的訊號 activate 才會開始射）
@export var start_on: bool = true

@export_group("子彈")
## 子彈速度
@export_range(100.0, 900.0) var bullet_speed: float = 250.0
## 子彈要不要受重力影響（像拋物線一樣往下墜）
@export var use_gravity: bool = false
## 子彈打中玩家扣幾滴血
@export_range(1, 10) var damage: int = 1
## 子彈的圖：從檔案系統把圖片拖進來（畫成朝右飛，飛行時會跟著方向轉）；空白就用原本的色塊
@export var bullet_texture: Texture2D
## 子彈會不會打壞可破壞方塊、按下「被攻擊觸發」的按鈕、推動箱子（關掉的話只會打玩家，撞到東西就消失）
@export var hit_objects: bool = false

## 開槍的那一刻發出，給學員自己接特效／音效用
signal shot

const _TILE_SIZE := 16.0
const _WINDUP_DURATION := 0.3
const _BULLET_LIFETIME := 3.0
const _ENEMY_SCRIPT_PATH := "res://blocks/_scripts/Enemy.gd"
const _FIXED_DIRECTIONS := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
const _RANGE_COLOR := Color(1.0, 0.3, 0.3, 0.35)
const _ARROW_COLOR := Color(1.0, 0.3, 0.3, 0.9)

var enemy: Node2D = null
var _cooldown_left: float = 0.0
var _windup_left: float = 0.0
var _active: bool = true

## 開始射擊（從頭倒數冷卻，不會一開就馬上射）
func activate() -> void:
	if _active:
		return
	_active = true
	_cooldown_left = cooldown

## 停火，正在準備開的那一槍也取消
func deactivate() -> void:
	_active = false
	_windup_left = 0.0

## 切換
func toggle() -> void:
	if _active:
		deactivate()
	else:
		activate()

# 敵人呼叫，把自己交給這個組件
func setup(e: Node2D) -> void:
	enemy = e
	_cooldown_left = cooldown
	print("[%s] 已啟用" % name)

# 敵人復位時呼叫（重生處理者 → Enemy.reset()），計時重來；開關狀態不動
func on_reset() -> void:
	_cooldown_left = cooldown
	_windup_left = 0.0

# 加入 signal_source；等一幀檢查有沒有被敵人接手，沒有就是放錯位置
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("signal_source")
	_active = start_on
	await get_tree().process_frame
	if enemy == null:
		push_warning("[%s] 沒有放在 Enemy 底下，不會開槍" % name)
		printerr("⚠ [%s] 請把這個節點拖到關卡裡某個 Enemy（笨敵人）的底下" % name)

# 被拖到別的地方時重新檢查黃色驚嘆號
func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED:
		update_configuration_warnings()

# 編輯器裡的黃色驚嘆號：沒放在 Enemy 底下
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	var parent_script: Script = parent.get_script() if parent else null
	if parent_script == null or parent_script.resource_path != _ENEMY_SCRIPT_PATH:
		warnings.append("敵人射擊要放在笨敵人（Enemy）底下才會生效：在場景樹把它拖到某個 Enemy 上放開。")
	return warnings

# 每個物理幀：倒數冷卻，玩家在範圍內就開槍；開了 stop_to_shoot 時先讓敵人停一下再射
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if not _active or enemy == null or not is_instance_valid(enemy) or enemy.is_defeated():
		return
	if _windup_left > 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_fire()
		return
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	if _cooldown_left > 0.0 or not _player_in_range():
		return
	_cooldown_left = cooldown
	if stop_to_shoot:
		enemy.hold_still(_WINDUP_DURATION)
		_windup_left = _WINDUP_DURATION
	else:
		_fire()

# 玩家活著、而且在偵測範圍內（detect_range_tiles 是 0 就不限距離）
func _player_in_range() -> bool:
	var player := Aim.find_player(self)
	if player == null or (player.has_method("is_dead") and player.is_dead()):
		return false
	if detect_range_tiles <= 0:
		return true
	return global_position.distance_to(player.global_position) <= detect_range_tiles * _TILE_SIZE

# 朝 aim_type 指定的方向射出一顆敵方子彈
func _fire() -> void:
	if not _player_in_range() or enemy.is_defeated():
		return
	var bullet := Bullet.spawn(self, _shoot_direction(), bullet_speed, Bullet.TEAM_ENEMY)
	bullet.shooter = enemy
	bullet.gravity_enabled = use_gravity
	bullet.damage = damage
	bullet.hit_objects = hit_objects
	bullet.lifetime_left = _BULLET_LIFETIME
	bullet.set_texture(bullet_texture)
	shot.emit()

# 依 aim_type 算出子彈方向
func _shoot_direction() -> Vector2:
	var facing := Aim.facing(enemy.get_facing())
	match aim_type:
		0:
			return Aim.toward_player(self, facing)
		1:
			return facing
	return _FIXED_DIRECTIONS[aim_type - 2]

# 編輯畫面用：畫偵測範圍的圓、固定方向的箭頭，以及 shot 訊號的連線
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if detect_range_tiles > 0:
		draw_arc(Vector2.ZERO, detect_range_tiles * _TILE_SIZE, 0.0, TAU, 64, _RANGE_COLOR, 1.0)
	if aim_type >= 2:
		var dir: Vector2 = _FIXED_DIRECTIONS[aim_type - 2]
		draw_line(Vector2.ZERO, dir * 20.0, _ARROW_COLOR, 2.0)
		draw_line(dir * 20.0, dir * 14.0 + dir.orthogonal() * 4.0, _ARROW_COLOR, 2.0)
		draw_line(dir * 20.0, dir * 14.0 - dir.orthogonal() * 4.0, _ARROW_COLOR, 2.0)
	SignalLines.draw(self, shot)
