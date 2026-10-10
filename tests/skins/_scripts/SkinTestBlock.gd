extends Node2D

# 測試用的假零件：只有一個色塊（Visual），開場建 SkinLink，示範零件端怎麼接皮。
# U178、U179 的真零件照這個寫法改。

const _COLOR_NORMAL := Color(0.95, 0.8, 0.2, 1)
const _COLOR_ACTIVE := Color(0.3, 0.85, 0.35, 1)

var _skin: SkinLink = null
var _active := false
var _facing_left := false
var _faded := false

# 找底下的皮並套上
func _ready() -> void:
	add_to_group("skin_test_block")
	_skin = SkinLink.new(self, $Visual)
	print("[測試] %s：%s" % [name, "套上皮了" if _skin.has_skin() else "沒有皮，顯示色塊"])

# 切換平常／狀態改變後
func toggle_active() -> void:
	_active = not _active
	_skin.show_state(_active, _COLOR_ACTIVE if _active else _COLOR_NORMAL)

# 切換面向
func toggle_facing() -> void:
	_facing_left = not _facing_left
	_skin.set_facing(_facing_left)

# 切換變淡
func toggle_fade() -> void:
	_faded = not _faded
	_skin.set_alpha(0.4 if _faded else 1.0)
