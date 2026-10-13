extends AbilityBase

# 遠程：按下攻擊鍵（鍵盤或滑鼠）時朝面向方向（或滑鼠游標方向）發射子彈，撞到地形或受擊物件即消失。
# 拖進 Player → Abilities 底下就能用，不用連任何線。
# 也可以把任何訊號（例如後座力卡的 fired）連到 shoot()，讓別的東西幫你開槍。

## 用鍵盤按鍵還是滑鼠按鍵攻擊；選「只用訊號觸發」時不綁按鍵，要把別的訊號連到 shoot() 才會開槍
@export_enum("鍵盤按鍵", "滑鼠左鍵", "滑鼠右鍵", "滑鼠中鍵", "只用訊號觸發") var input_type: int = 0

## 攻擊鍵（「按鍵種類」選鍵盤按鍵時才會顯示這一欄）
@export var key: Key = KEY_G

## 子彈速度
@export_range(100.0, 900.0) var bullet_speed: float = 400.0

## 冷卻秒數，這段時間內再按不會生效
@export_range(0.1, 3.0) var cooldown: float = 0.4

## 子彈存在幾秒後自動消失
@export_range(0.2, 5.0) var lifetime: float = 2.0

## 子彈最多飛幾格就消失，0 代表不限制（1 格 = 16 像素）
@export_range(0, 30) var max_range_tiles: int = 0

## 子彈要不要受重力影響（像拋物線一樣往下墜）
@export var use_gravity: bool = false

## 開啟後子彈朝滑鼠游標的方向射，關閉時朝角色面向的方向射
@export var aim_at_mouse: bool = false

## 每顆子彈打中造成的傷害
@export_range(1, 10) var damage: int = 1

## 子彈的圖：從檔案系統把圖片拖進來（畫成朝右飛，飛行時會跟著方向轉）；空白就用原本的色塊
@export var bullet_texture: Texture2D

## 開槍時角色被往反方向推的力道，0 代表沒有後座力
## （把後座力卡的 fired 連到 shoot() 時，推力已經由後座力卡負責，這裡通常保持 0）
@export_range(0.0, 800.0) var recoil_strength: float = 0.0

const _TILE_SIZE := 16.0
# input_type 的「只用訊號觸發」選項
const _SIGNAL_ONLY := 4

var _facing: int = 1
var _cooldown_left: float = 0.0

# 選滑鼠按鍵時隱藏 key 欄位
func _validate_property(property: Dictionary) -> void:
	if property.name == "key" and input_type != 0:
		property.usage = PROPERTY_USAGE_NONE

# 接玩家面向訊號，向 InputRouter 註冊攻擊鍵；選「只用訊號觸發」時不綁按鍵，改檢查有沒有訊號連到 shoot()
func _on_setup() -> void:
	if input_type == 0:
		InputRouter.warn_if_dangerous_key(key, "[遠程]")
	if player.has_signal("direction_changed"):
		player.direction_changed.connect(func(dir): _facing = dir)
	if input_type == _SIGNAL_ONLY:
		_warn_if_shoot_not_connected()
	else:
		InputRouter.bind_input(self, input_type, key, InputRouter.PRESSED, _on_shoot_pressed)

# 按下攻擊鍵：冷卻中不生效，否則開一槍
func _on_shoot_pressed() -> void:
	if _cooldown_left > 0.0:
		return
	_cooldown_left = cooldown
	_fire()

# 開一槍，給學員從任何訊號連過來用（例如後座力卡的 fired）；不看冷卻，什麼時候開槍由發訊號的那一方決定
func shoot() -> void:
	if not enabled or player == null or player.is_dead():
		return
	_fire()

# 從玩家位置朝面向方向（aim_at_mouse 開啟時朝滑鼠游標）發射一顆子彈並發出 attacked，recoil_strength 大於 0 時把玩家往反方向推
func _fire() -> void:
	var direction := _shoot_direction()
	var bullet := Bullet.spawn(player, direction, bullet_speed, Bullet.TEAM_PLAYER)
	bullet.gravity_enabled = use_gravity
	bullet.lifetime_left = lifetime
	bullet.max_distance = max_range_tiles * _TILE_SIZE
	bullet.damage = damage
	bullet.set_texture(bullet_texture)
	if recoil_strength > 0.0:
		player.add_impulse(-direction * recoil_strength)
	attacked.emit()

# 每一幀處理冷卻倒數
func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta

# 子彈要飛的方向：aim_at_mouse 開啟時朝滑鼠游標，游標剛好在角色身上或沒開啟就朝面向方向
func _shoot_direction() -> Vector2:
	var facing_dir := Aim.facing(_facing)
	if aim_at_mouse:
		return Aim.toward_mouse(player, facing_dir)
	return facing_dir

# 選了「只用訊號觸發」卻沒有任何訊號連到 shoot() 時提醒，不然按什麼都不會開槍
func _warn_if_shoot_not_connected() -> void:
	for connection in get_incoming_connections():
		var callable: Callable = connection["callable"]
		if callable.get_method() == "shoot":
			return
	var message := "[%s] 按鍵種類選了「只用訊號觸發」，但沒有任何訊號連到 shoot()，永遠不會開槍。請在「節點」面板把訊號（例如後座力卡的 fired）連到這個節點的 shoot" % name
	push_warning(message)
	printerr("⚠ %s" % message)
