@tool
class_name SkinShare
extends Node2D

# 共用皮：拖進關卡，target 下拉選零件種類，把一個 Skin／SkinAnimated 拖到這個底下。
# 關卡裡這種零件只要自己沒掛皮，全部用這個皮（遊戲開始時每個零件各複製一份）；自己有皮的照舊用自己的。
# 皮的位置以這個節點為準：皮放在這裡的 (0, 0) 就是零件的中心。
# 編輯器裡會在每個零件上放一份預覽（不存進場景檔），擺的時候看到的就是遊戲裡的樣子。

## 要套在哪種零件上：下拉會列出關卡裡有的零件
@export var target: String = NONE:
	set(value):
		target = value
		update_configuration_warnings()

const NONE := "（選零件）"
const GROUP := "skin_share"
const _PREVIEW_META := &"skin_share_preview"
const _REFRESH_SECONDS := 0.5
# 零件腳本 → 下拉顯示的中文名稱（有色塊、能換皮的零件）
const KINDS := {
	"res://blocks/_scripts/Box.gd": "箱子",
	"res://blocks/_scripts/Breakable.gd": "可破壞方塊",
	"res://blocks/_scripts/Button.gd": "按鈕",
	"res://blocks/_scripts/Checkpoint.gd": "重生點",
	"res://blocks/_scripts/CrumbleFloor.gd": "崩塌地板",
	"res://blocks/_scripts/Door.gd": "門",
	"res://blocks/_scripts/Enemy.gd": "笨敵人",
	"res://blocks/_scripts/Fan.gd": "風扇",
	"res://blocks/_scripts/Goal.gd": "終點",
	"res://blocks/_scripts/Launcher.gd": "彈射台",
	"res://blocks/_scripts/Lava.gd": "岩漿",
	"res://blocks/_scripts/MovingPlatform.gd": "移動平台",
	"res://blocks/_scripts/NoBounceBlock.gd": "不反彈方塊",
	"res://blocks/_scripts/OneWayPlatform.gd": "單向平台",
	"res://blocks/_scripts/Pickup.gd": "道具",
	"res://blocks/_scripts/Portal.gd": "傳送門",
	"res://blocks/_scripts/Spike.gd": "尖刺",
	"res://blocks/_scripts/SwitchBlock.gd": "開關方塊",
}

var _refresh_timer := 0.0
var _previews: Array[Node] = []  # 編輯器裡放在零件上的預覽
var _preview_signature := ""  # 預覽是照哪個樣子做的，皮改了就重做
var _reported := false  # 皮有問題的警告只印一次
var _listed_kinds: Array = []  # 上次 target 下拉列出的零件種類，變了才重整 Inspector

# 加進 group，零件開場時靠這個找到共用皮（_enter_tree 比所有零件的 _ready 都早）
func _enter_tree() -> void:
	add_to_group(GROUP)

# 遊戲中：模板皮藏起來（零件會各自複製一份），設定有問題印中文警告
func _ready() -> void:
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	var template := template_skin()
	if template != null:
		template.visible = false
	for problem in _problems(get_tree().current_scene):
		push_warning("[共用皮] 「%s」：%s" % [name, problem])

# 編輯器裡定時更新零件上的預覽與黃色驚嘆號
func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < _REFRESH_SECONDS:
		return
	_refresh_timer = 0.0
	_refresh_previews()
	update_configuration_warnings()
	var kinds := _kinds_in_scene(_scene_root())
	if kinds != _listed_kinds:
		_listed_kinds = kinds
		notify_property_list_changed()

# 被刪掉、拖走時把預覽拿掉
func _exit_tree() -> void:
	if Engine.is_editor_hint():
		_clear_previews()

# target 的下拉：列出關卡裡有的零件種類（現在選的那個就算關卡裡沒有也留著）
func _validate_property(property: Dictionary) -> void:
	if property.name != "target":
		return
	var names: Array = [NONE]
	for kind in _kinds_in_scene(_scene_root()):
		names.append(kind)
	if not target in names:
		names.append(target)
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(names)

# 黃色驚嘆號
func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(_problems(_scene_root()))

# 這個共用皮的模板（底下第一個 Skin／SkinAnimated），沒有回傳 null
func template_skin() -> Node2D:
	for child in get_children():
		if child.has_method("skin_setup") and not child.has_meta(_PREVIEW_META):
			return child
	return null

# 選的零件種類對應的零件腳本路徑，沒選回傳空字串
func target_script_path() -> String:
	for path in KINDS:
		if KINDS[path] == target:
			return path
	return ""

# 皮在編輯器裡判斷「套在哪種零件上」用（敵人的動畫名稱、風扇的方向、事件下拉）
func share_target_script() -> Script:
	var path := target_script_path()
	return load(path) if path != "" else null

# 零件開場時呼叫：這個共用皮要不要套在 host 上，要的話回傳一份新的皮（還沒加進場景），不要回傳 null
func make_skin_for(host: Node) -> Node2D:
	var path := target_script_path()
	var host_script: Script = host.get_script()
	if path == "" or host_script == null or host_script.resource_path != path:
		return null
	var template := template_skin()
	if template == null:
		return null
	var copy: Node2D = template.duplicate()
	copy.visible = true
	return copy

# 複製出去的皮不能用時呼叫（沒放圖、缺動畫）：只印一次警告，不要每個零件都印
func report_problem(problem: String) -> void:
	if _reported:
		return
	_reported = true
	SkinLink.warn("共用皮「%s」的皮不能用：%s；%s都先顯示原本的色塊" % [name, problem, target])

# 設定有問題的地方（編輯器和遊戲中共用）
func _problems(root: Node) -> Array:
	var result: Array = []
	if target == NONE or target_script_path() == "":
		result.append("target 下拉選要套在哪種零件上")
	else:
		var kinds := _kinds_in_scene(root)
		if root != null and not target in kinds:
			result.append("關卡裡沒有「%s」，這個共用皮不會套到任何東西；關卡裡有的：%s" % [target, NameCheck.list_text(kinds)])
		for other in _all_shares():
			if other == self:
				break
			if other.target == target:
				result.append("「%s」已經有共用皮「%s」了，只會用那一個，這個可以刪掉" % [target, other.name])
				break
	var skins := 0
	for child in get_children():
		if child.has_method("skin_setup") and not child.has_meta(_PREVIEW_META):
			skins += 1
	if skins == 0:
		result.append("底下還沒有皮：從 skins/ 把 Skin 或 SkinAnimated 拖到這個底下")
	elif skins > 1:
		result.append("底下有 %d 個皮，只會用第一個「%s」" % [skins, template_skin().name])
	return result

# 場景裡所有共用皮（照場景樹順序）
func _all_shares() -> Array:
	var root := _scene_root()
	if root == null:
		return get_tree().get_nodes_in_group(GROUP) if is_inside_tree() else []
	var result: Array = []
	for n in root.find_children("*", "Node2D", true, false):
		if n.has_method("make_skin_for"):
			result.append(n)
	return result

# 編輯器裡是正在編輯的場景，遊戲中是目前的關卡
func _scene_root() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene

# 場景裡有哪幾種能換皮的零件（中文名稱，照 KINDS 的順序）
func _kinds_in_scene(root: Node) -> Array:
	var found := {}
	for host in _hosts_in(root, ""):
		found[KINDS[host.get_script().resource_path]] = true
	var result: Array = []
	for path in KINDS:
		if found.has(KINDS[path]):
			result.append(KINDS[path])
	return result

# 場景裡的零件；path 不是空字串時只找這種
func _hosts_in(root: Node, path: String) -> Array:
	var result: Array = []
	if root == null:
		return result
	for n in root.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s == null or not KINDS.has(s.resource_path):
			continue
		if path == "" or s.resource_path == path:
			result.append(n)
	return result

# 零件自己有沒有掛皮（不算預覽）
static func _has_own_skin(host: Node) -> bool:
	for child in host.get_children():
		if child.has_method("skin_setup") and not child.has_meta(_PREVIEW_META):
			return true
	return false

# 編輯器裡：每個沒掛皮的同種零件放一份預覽；皮改了就全部重做，零件自己掛了皮就把預覽拿掉
func _refresh_previews() -> void:
	var template := template_skin()
	var path := target_script_path()
	var signature := _signature(template) + path
	if signature != _preview_signature:
		_clear_previews()
		_preview_signature = signature
	if template == null or path == "" or _is_shadowed():
		_clear_previews()
		return
	for preview in _previews.duplicate():
		if not is_instance_valid(preview) or _has_own_skin(preview.get_parent()):
			_remove_preview(preview)
	var covered := {}
	for preview in _previews:
		covered[preview.get_parent()] = true
	for host in _hosts_in(_scene_root(), path):
		if covered.has(host) or _has_own_skin(host):
			continue
		var copy: Node2D = template.duplicate()
		copy.set_meta(_PREVIEW_META, true)
		copy.visible = true
		host.add_child(copy)  # 不設 owner：不會存進場景檔，場景樹上也看不到
		_previews.append(copy)

# 前面已經有同種零件的共用皮了（這個不會被用到，不放預覽）
func _is_shadowed() -> bool:
	for other in _all_shares():
		if other == self:
			return false
		if other.target == target:
			return true
	return false

# 模板皮現在的樣子（存進場景的欄位＋子節點數），用來判斷要不要重做預覽
func _signature(template: Node) -> String:
	if template == null:
		return ""
	var parts: Array = [template.get_script(), template.get_child_count()]
	for p in template.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE and not p.name in ["frame", "frame_progress"]:
			parts.append(template.get(p.name))
	return str(parts)

# 拿掉一份預覽
func _remove_preview(preview: Node) -> void:
	_previews.erase(preview)
	if is_instance_valid(preview):
		preview.get_parent().remove_child(preview)
		preview.queue_free()

# 拿掉所有預覽
func _clear_previews() -> void:
	for preview in _previews.duplicate():
		_remove_preview(preview)
	_previews.clear()
