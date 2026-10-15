extends AbilityBase

# 近戰：按下攻擊鍵（鍵盤或滑鼠）時，在玩家面向方向短暫生成一塊攻擊判定區（MeleeHitbox.tscn），
# 打到有 take_hit() 的東西就呼叫，造成傷害跟擊退。判定區的大小跟外觀直接改 MeleeHitbox.tscn。
# 拖進 Player → Abilities 底下就能用，不用連任何線。

## 用鍵盤按鍵、滑鼠按鍵，還是 Input Map 動作（可以綁手把）攻擊
@export_enum("鍵盤按鍵", "滑鼠左鍵", "滑鼠右鍵", "滑鼠中鍵", "Input Map 動作") var input_type: int = 0

## 攻擊鍵（「按鍵種類」選鍵盤按鍵時才會顯示這一欄）
@export var key: Key = KEY_F

## 「按鍵種類」選 Input Map 動作時，要聽哪一個動作（動作在「專案設定 → Input Map」裡加，可以綁手把等其他裝置）
@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin") var action: StringName = &""

## 冷卻秒數，這段時間內再按不會生效
@export_range(0.1, 3.0) var cooldown: float = 0.5

## 擊退力道
@export_range(0.0, 600.0) var knockback: float = 200.0

## 傷害
@export_range(1, 10) var damage: int = 1

## 揮擊的圖：從檔案系統把圖片拖進來（畫成往右揮，往左攻擊時會自動翻過來）；空白就用原本的色塊
@export var slash_texture: Texture2D

const _HITBOX_SCENE := preload("res://abilities/MeleeHitbox.tscn")
const _HITBOX_DURATION := 0.15

var _facing: int = 1
var _cooldown_left: float = 0.0
var _hitbox: Area2D

# input_type 的「Input Map 動作」選項
const _INPUT_MAP_ACTION := 4

# 選滑鼠按鍵時隱藏 key 欄位
func _validate_property(property: Dictionary) -> void:
	if property.name == "key" and input_type != 0:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "action" and input_type != _INPUT_MAP_ACTION:
		property.usage = PROPERTY_USAGE_NONE

# 接玩家面向訊號、向 InputRouter 註冊攻擊鍵
func _on_setup() -> void:
	if input_type == 0:
		InputRouter.warn_if_dangerous_key(key, "[近戰]")
	if player.has_signal("direction_changed"):
		player.direction_changed.connect(func(dir): _facing = dir)
	InputRouter.bind_input(self, input_type, key, InputRouter.PRESSED, _on_attack_pressed, 0, action)

# 按下攻擊鍵：冷卻中不生效，否則在面向方向生成一個判定區（上一個還沒消失就先收掉）並發出 attacked
func _on_attack_pressed() -> void:
	if _cooldown_left > 0.0:
		return
	_cooldown_left = cooldown
	if is_instance_valid(_hitbox):
		_hitbox.queue_free()
	_hitbox = _HITBOX_SCENE.instantiate()
	_hitbox.scale.x = _facing
	_hitbox.damage = damage
	_hitbox.knockback = Vector2(_facing, 0) * knockback
	_hitbox.lifetime_left = _HITBOX_DURATION
	_hitbox.attacker = player
	add_child(_hitbox)
	_hitbox.set_texture(slash_texture)
	attacked.emit()

# 每一幀處理冷卻倒數
func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
