extends RefCounted
class_name HudBinding

# 顯示零件（HudNumber、HudBar、HudIcons）共用的部分：依 source／kind 找到 HudData 的顯示來源、
# 值變了通知零件、認領來源讓預設 UI 讓位、找不到來源時的中文警告、變化時閃一下／抖一下。
# 每個顯示零件各帶一個，零件自己只管「怎麼畫」。

# source 下拉的選項，順序要跟零件的 @export_enum 一樣
const SOURCE_VALUE := 0
const SOURCE_NAMES := ["", "遊玩時間", "死亡次數", "體力", "存活倒數", "脫殼次數", "時間軸"]
# 內建來源要掛什麼才會有，找不到時寫在警告裡
const SOURCE_NEEDS := {
	"體力": "Player → Mechanics 底下要有「移動會扣血」卡（Mechanic_Stamina）",
	"存活倒數": "Player → Mechanics 底下要有「存活計時」卡（Mechanic_SurvivalTimer）",
	"脫殼次數": "Player → Mechanics 底下要有「脫殼」卡（Extra_Molt）",
	"時間軸": "關卡裡要有時間軸（blocks/Timeline.tscn）",
}
# 預設 HUD（StatsHud 用範本生出來的）裡的零件會被標上這個 meta
const DEFAULT_META := &"hud_default"
# 這些來源是秒數，「數字」格式顯示到小數一位
const SECOND_SOURCES := ["遊玩時間", "體力", "存活倒數", "時間軸"]

var _owner: Control
var _source_name: String = ""
var _last_value: float = 0.0
var _has_value: bool = false
var _base_modulate: Color = Color.WHITE
var _base_position: Vector2 = Vector2.ZERO
var _flash_tween: Tween = null
var _shake_tween: Tween = null

# 帶著要通知的零件；零件要有 _on_hud_value(value, max_value, found) 這個函式
func _init(owner: Control) -> void:
	_owner = owner

# 依 source 與 kind 算出顯示來源的名稱（數值就是整理過的 kind）
static func source_name_of(source: int, kind: String) -> String:
	if source == SOURCE_VALUE:
		return NameCheck.clean(kind)
	return SOURCE_NAMES[source]

# 編輯器裡用的檢查：名稱空白；零件放在關卡裡（不是單獨編輯 HUD 場景）時，關卡裡找不到這個數值種類
static func editor_warnings(source: int, kind: String, scene_root: Node) -> PackedStringArray:
	var warnings := PackedStringArray()
	if source != SOURCE_VALUE:
		return warnings
	var clean_kind := NameCheck.clean(kind)
	if clean_kind == "":
		warnings.append("kind 是空白的：打上要顯示的數值名稱，例如「血量」「金幣」")
		return warnings
	if scene_root == null or scene_root is UIRoot:
		return warnings
	var kinds := _scene_kinds(scene_root)
	if clean_kind not in kinds:
		warnings.append(_not_found_message(clean_kind, kinds))
	return warnings

# 開始顯示：接上 HudData、認領這個來源（預設 HUD 的零件不認領，不然預設的會自己讓位給自己）、
# 先畫一次目前的值；下一幀檢查來源到底存不存在
func start(source: int, kind: String) -> void:
	_source_name = source_name_of(source, kind)
	_base_modulate = _owner.modulate
	HudData.source_changed.connect(_on_source_changed)
	if not _owner.get_meta(DEFAULT_META, false):
		HudData.claim(_source_name, _owner)
	_refresh(false)
	_check_found.call_deferred(source)

# 這個零件綁的來源名稱
func get_source_name() -> String:
	return _source_name

# 依目前的值畫「數字」格式：整數就不帶小數，秒數類的來源帶一位小數
func format_number(value: float) -> String:
	if _source_name in SECOND_SOURCES:
		return "%.1f" % value
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

# 數值變化時閃一下：變多閃白、變少閃紅；shake 為 true 時變少再左右抖一下
func play_change(increased: bool, flash: bool, shake: bool) -> void:
	if flash:
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_owner.modulate = Color(1.8, 1.8, 1.8) if increased else Color(1.8, 0.5, 0.5)
		_flash_tween = _owner.create_tween()
		_flash_tween.tween_property(_owner, "modulate", _base_modulate, 0.3)
	if shake and not increased:
		if _shake_tween != null and _shake_tween.is_valid():
			_shake_tween.kill()
			_owner.position = _base_position
		_base_position = _owner.position
		_shake_tween = _owner.create_tween()
		for i in 4:
			var offset := Vector2(3.0 if i % 2 == 0 else -3.0, 0.0)
			_shake_tween.tween_property(_owner, "position", _base_position + offset, 0.04)
		_shake_tween.tween_property(_owner, "position", _base_position, 0.04)

# 來源變了：是自己綁的就重畫
func _on_source_changed(changed: String) -> void:
	if changed == _source_name:
		_refresh(true)

# 從 HudData 讀值通知零件；值真的變了就發出變化（第一次畫不算變化）
func _refresh(notify_change: bool) -> void:
	var found := HudData.has_source(_source_name)
	var value := HudData.get_value(_source_name)
	_owner._on_hud_value(value, HudData.get_max_value(_source_name), found or _in_scene_kinds())
	if notify_change and found and _has_value and not is_equal_approx(value, _last_value):
		_owner._on_hud_changed(_last_value, value)
	if found:
		_last_value = value
		_has_value = true

# 數值種類還沒被用到之前（例如金幣還沒撿）HudData 裡沒有它，但關卡裡有道具用到這個名稱，就先當成 0
func _in_scene_kinds() -> bool:
	var scene := _owner.get_tree().current_scene
	return scene != null and _source_name in _scene_kinds(scene)

# 下一幀檢查來源存不存在，不存在就印中文警告（列出現有的名稱、附近似名稱建議）；
# 預設 HUD 的零件不警告（還沒用到的種類那一列本來就藏著）
func _check_found(source: int) -> void:
	if _owner.get_meta(DEFAULT_META, false):
		return
	if HudData.has_source(_source_name) or _in_scene_kinds():
		return
	var message: String
	if source == SOURCE_VALUE:
		var names: Array = Stats.get_known_kinds()
		var scene := _owner.get_tree().current_scene
		if scene != null:
			for k in _scene_kinds(scene):
				if k not in names:
					names.append(k)
		message = _not_found_message(_source_name, names)
	else:
		message = "找不到「%s」：%s" % [_source_name, SOURCE_NEEDS.get(_source_name, "")]
	push_warning("[%s] %s" % [_owner.name, message])
	printerr("⚠ [%s] %s" % [_owner.name, message])

# 關卡裡用到的數值種類名稱，血量一定有
static func _scene_kinds(scene_root: Node) -> Array:
	var kinds := NameCheck.collect_value_kinds(scene_root)
	if "血量" not in kinds:
		kinds.append("血量")
	return kinds

# 找不到數值種類時的訊息：列出現有的、附近似名稱建議
static func _not_found_message(clean_kind: String, names: Array) -> String:
	var similar := NameCheck.find_similar(clean_kind, names)
	var hint := "是不是想打「%s」？" % similar if similar != "" else ""
	return "關卡裡找不到數值「%s」，會顯示「?」。%s現有的數值：%s" % [clean_kind, hint, NameCheck.list_text(names)]
