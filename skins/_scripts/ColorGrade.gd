@tool
extends CanvasModulate

# 統一色調：拖進關卡，整個遊戲畫面蒙上一層同樣的色調（暖、冷、復古、夜晚），HUD、選單這些 UI 不受影響。
# 素材從不同地方找來、顏色兜不起來時，用它把畫面拉成同一個氣氛。編輯器裡馬上看得到。
# 用的是 Godot 內建的 CanvasModulate：只能把顏色往某個色調壓（會變暗一點），不能調亮。一個畫面只能有一個。

## 色調
@export_enum("暖", "冷", "復古", "夜晚") var tone: int = 0:
	set(value):
		tone = value
		_apply()
## 強度：0 是原本的顏色，越大色調越重
@export_range(0.0, 1.0, 0.05) var strength: float = 0.5:
	set(value):
		strength = value
		_apply()

# 每種色調強度 1 時乘上去的顏色
const _TONES := [
	Color(1.0, 0.85, 0.65),   # 暖：偏橘黃
	Color(0.7, 0.85, 1.0),    # 冷：偏藍
	Color(0.9, 0.8, 0.6),     # 復古：泛黃、褪色
	Color(0.4, 0.45, 0.75),   # 夜晚：暗藍
]
const _NAMES := ["暖", "冷", "復古", "夜晚"]
const ONE_ONLY := "畫面裡有不只一個 ColorGrade（或其他 CanvasModulate），只有一個會生效：留一個就好"
const IN_LAYER := "ColorGrade 放在 CanvasLayer 底下只會染到那一層：拖到關卡最上層底下"

# 套用色調；場景裡放了不只一個、放錯地方時印中文警告
func _ready() -> void:
	_apply()
	if Engine.is_editor_hint():
		return
	var problem := _problem(get_tree().current_scene)
	if problem != "":
		push_warning("[統一色調] %s" % problem)
		printerr("⚠ [統一色調] %s" % problem)
	else:
		print("[統一色調] 已啟用：%s，強度 %.2f" % [_NAMES[tone], strength])

# 編輯器裡就看得到：放了不只一個、放在 CanvasLayer 底下
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if is_inside_tree():
		var problem := _problem(get_tree().edited_scene_root)
		if problem != "":
			warnings.append(problem)
	return warnings

# 把色調依強度混進白色（白色＝不變色），設成 CanvasModulate 的顏色
func _apply() -> void:
	color = Color.WHITE.lerp(_TONES[tone], strength)

# 放的方式有什麼問題，沒問題回傳空字串
func _problem(scene_root: Node) -> String:
	if get_parent() is CanvasLayer:
		return IN_LAYER
	if scene_root != null and _count_modulates(scene_root) > 1:
		return ONE_ONLY
	return ""

# 場景裡有幾個 CanvasModulate（不算 CanvasLayer 裡的，那些只管自己那一層）
func _count_modulates(node: Node) -> int:
	var count := 1 if node is CanvasModulate and node.visible else 0
	for child in node.get_children():
		if not child is CanvasLayer:
			count += _count_modulates(child)
	return count
