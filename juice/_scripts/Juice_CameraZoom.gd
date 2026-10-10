@tool
extends JuiceBase

# 鏡頭推近：觸發時鏡頭快速放大再慢慢回到原本大小，可以選放大在誰身上。拖進 Player → Juice 底下就能用，
# 預設是打倒敵人時推近、往玩家偏一點。房間內跟隨模式下，推近時畫面也不會露出房間外。

## 放大多少，0.25 是放大到 1.25 倍
@export_range(0.05, 1.0) var strength: float = 0.25
## 整段推近再回來要多久（秒）
@export_range(0.1, 1.5) var duration: float = 0.4
## 放大在哪裡：畫面中心（不偏移）、玩家（跟著玩家）、觸發位置（例如被打倒的敵人所在的位置）
@export_enum("畫面中心", "玩家", "觸發位置") var focus: int = FOCUS_PLAYER:
	set(value):
		focus = value
		notify_property_list_changed()
## 畫面往放大中心偏多少：偏一點、定在原地（那個點在畫面上的位置不動）、拉到正中央
@export_enum("偏一點", "定在原地", "拉到正中央") var focus_style: int = 0

const FOCUS_CENTER := 0
const FOCUS_PLAYER := 1
const FOCUS_TRIGGER := 2

# 請鏡頭推近一次，落地時勾選「跟著落地力道」的話放大程度會跟著變
func _on_play() -> void:
	var target: Variant = null
	if focus == FOCUS_PLAYER:
		target = player
	elif focus == FOCUS_TRIGGER:
		target = _trigger_position
	Events.zoom_requested.emit(strength * _trigger_power, duration, target, focus_style)

# 放大中心選「畫面中心」時藏起 focus_style
func _validate_property(property: Dictionary) -> void:
	super(property)
	if property.name == "focus_style" and focus == FOCUS_CENTER:
		property.usage &= ~PROPERTY_USAGE_EDITOR
