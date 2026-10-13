class_name StyleCheck
extends RefCounted

# 畫面風格檢查（Skin、SkinAnimated、SkinBackground 共用）：像素圖會不會糊、像素大小一不一致。
# 只在編輯器裡出黃色驚嘆號，不阻擋、遊戲中不印；皮勾了 ignore_style_check 就不檢查。
# 三件事：Texture 的 Filter 被改成會糊的、縮放不是整數倍、跟場景裡多數的皮比起來像素大小差 2 倍以上。

# 縮放跟最近的整數差多少以內算整數倍
const _SCALE_TOLERANCE := 0.05
# 像素大小跟多數的差幾倍以上才警告
const _DENSITY_RATIO := 2.0
# 場景裡至少要有幾個皮才比像素大小（太少沒有「多數」可比）
const _DENSITY_MIN_SKINS := 3
# 掃一次場景的結果用多久（毫秒），很多個皮同時檢查時不用每個都重掃
const _SCAN_CACHE_MS := 500

const _SCRIPT_PATHS := ["res://skins/_scripts/Skin.gd", "res://skins/_scripts/SkinAnimated.gd"]
# Inspector 上 Texture → Filter 的選項名稱（照 CanvasItem.TextureFilter 的順序）
const _FILTER_NAMES := ["Inherit", "Nearest", "Linear", "Nearest Mipmap", "Linear Mipmap",
	"Nearest Mipmap Anisotropic", "Linear Mipmap Anisotropic"]

static var _scan_scene_id := 0
static var _scan_at_ms := -_SCAN_CACHE_MS
static var _scan_scales: Array[float] = []

# 這個皮的風格問題（中文），沒問題回傳空的。皮自己用 style_scale_free() 回答會不會自己拉伸（拉伸蓋滿），
# 會的話不檢查縮放與像素大小；compare：要不要跟場景裡其他的皮比像素大小（背景不比，遠景故意縮小很常見）
static func problems(node: CanvasItem, compare: bool) -> PackedStringArray:
	var result := PackedStringArray()
	if not Engine.is_editor_hint() or not node.is_inside_tree() or node.get("ignore_style_check"):
		return result
	var filter_problem := _filter_problem(node)
	if filter_problem != "":
		result.append(filter_problem)
	if node.style_scale_free():
		return result
	var scale_problem := _scale_problem(node)
	if scale_problem != "":
		result.append(scale_problem)
	if compare:
		var density_problem := _density_problem(node)
		if density_problem != "":
			result.append(density_problem)
	return result

# 一個皮在畫面上的像素大小（左右、上下縮放的平均，不管左右翻）
static func pixel_scale(node: Node2D) -> float:
	var s := node.global_scale.abs()
	return (s.x + s.y) / 2.0

# Filter 不是 Inherit（照專案的 Nearest）或 Nearest，像素圖會糊
static func _filter_problem(node: CanvasItem) -> String:
	var filter := node.texture_filter
	if filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE or filter == CanvasItem.TEXTURE_FILTER_NEAREST:
		return ""
	return "Texture → Filter 改成了「%s」，像素圖會糊：改回 Inherit 或 Nearest（故意的話勾 ignore_style_check）" % _FILTER_NAMES[filter]

# 左右或上下的縮放不是整數倍（含上層的縮放），像素會一格大一格小
static func _scale_problem(node: Node2D) -> String:
	var s := node.global_scale.abs()
	if _is_whole(s.x) and _is_whole(s.y):
		return ""
	var text := "縮放是 %s 倍，不是整數倍，像素會一格大一格小：Scale 改成 1、2、3…" % _scale_text(s)
	if node.has_method("style_fill_hint"):
		text += node.style_fill_hint()
	return text

# 跟場景裡多數的皮比，像素大小差 2 倍以上
static func _density_problem(node: Node2D) -> String:
	var scales := _scene_scales(node)
	if scales.size() < _DENSITY_MIN_SKINS:
		return ""
	var common := _most_common(scales)
	var mine := pixel_scale(node)
	if common <= 0.0 or mine <= 0.0:
		return ""
	var ratio := mine / common
	if ratio < _DENSITY_RATIO and ratio > 1.0 / _DENSITY_RATIO:
		return ""
	var compare := "大 %s 倍" % _num(ratio) if ratio > 1.0 else "小 %s 倍" % _num(1.0 / ratio)
	return "這張圖的像素在畫面上比場景裡多數的皮%s（多數是 %s 倍、這個是 %s 倍），放在一起不像同一套：Scale 調成跟其他皮一樣，或換一張解析度相近的圖（故意的話勾 ignore_style_check）" \
		% [compare, _num(common), _num(mine)]

# 場景裡要拿來比的皮的像素大小：沒勾 ignore_style_check、不是拉伸蓋滿的 Skin、SkinAnimated（半秒內重複問就用上次的結果）
static func _scene_scales(node: Node) -> Array[float]:
	var root := node.get_tree().edited_scene_root
	if root == null:
		return []
	var now := Time.get_ticks_msec()
	if root.get_instance_id() == _scan_scene_id and now - _scan_at_ms < _SCAN_CACHE_MS:
		return _scan_scales
	_scan_scene_id = root.get_instance_id()
	_scan_at_ms = now
	_scan_scales = []
	for other in root.find_children("*", "Node2D", true, false):
		var script: Script = other.get_script()
		if script == null or script.resource_path not in _SCRIPT_PATHS:
			continue
		if other.get("ignore_style_check") or other.style_scale_free():
			continue
		_scan_scales.append(pixel_scale(other))
	return _scan_scales

# 出現最多次的像素大小（四捨五入到 0.25 再數），一樣多時取小的
static func _most_common(scales: Array[float]) -> float:
	var counts := {}
	for s in scales:
		var key := snappedf(s, 0.25)
		counts[key] = counts.get(key, 0) + 1
	var best := 0.0
	var best_count := 0
	for key in counts:
		if counts[key] > best_count or (counts[key] == best_count and key < best):
			best = key
			best_count = counts[key]
	return best

# 是不是整數倍（0 倍不算）
static func _is_whole(value: float) -> bool:
	var nearest := roundf(value)
	return nearest >= 1.0 and absf(value - nearest) <= _SCALE_TOLERANCE

# 縮放寫成字：左右上下一樣就一個數字，不一樣就「左右 × 上下」
static func _scale_text(s: Vector2) -> String:
	if is_equal_approx(s.x, s.y):
		return _num(s.x)
	return "%s × %s" % [_num(s.x), _num(s.y)]

# 數字最多兩位小數，整數不寫小數點（2 而不是 2.0）
static func _num(value: float) -> String:
	var v := snappedf(value, 0.01)
	return str(int(v)) if is_equal_approx(v, roundf(v)) else String.num(v)
