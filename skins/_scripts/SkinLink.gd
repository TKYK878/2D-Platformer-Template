class_name SkinLink
extends RefCounted

# 零件端的皮：零件開場時建一個（SkinLink.new(self, 色塊)），之後所有外觀變化都透過它。
# 零件底下有 Skin／SkinAnimated 就藏起色塊、改作用在皮上；沒有皮就照舊改色塊。
# 皮設定有問題（沒放圖、缺動畫）時印中文警告，照舊顯示色塊，遊戲不會因此看不到零件。
# 另外放 Skin、SkinAnimated 共用的檢查：放對地方了沒、原本色塊的範圍在哪。

# 零件裡色塊的節點名稱（風扇的本體叫 BodyVisual）
const BLOCK_VISUAL_NAMES := ["Visual", "BodyVisual"]
# 這些零件是敵人：動畫名稱用「走路」「受傷」「死亡」
const _ENEMY_SCRIPTS := ["res://blocks/_scripts/Enemy.gd"]
# 這些零件有方向（direction 下拉），皮勾了 follow_direction 會跟著轉；值是每個選項要轉幾度（圖畫成朝上）
const _DIRECTIONAL_SCRIPTS := {
	"res://blocks/_scripts/Fan.gd": [0.0, 180.0, -90.0, 90.0],  # 上、下、左、右
}
# 狀態改變後沒有另外的圖時，平常的圖往狀態顏色染多少（0～1）
const _TINT_STRENGTH := 0.6
# SkinEvent「什麼時候」下拉顯示的中文：零件訊號名稱 → 中文（沒列到的照訊號名稱顯示）
const _EVENT_LABELS := {
	"reached": "踩到時",
	"turned_on": "打開時",
	"turned_off": "關掉時",
	"opened": "門打開時",
	"closed": "門關上時",
	"launched": "彈出時",
	"teleported": "傳送時",
}
# 這些事件發生時零件馬上藏起來，播動畫也看不到，不列進 SkinEvent 的下拉（敵人被打倒用「死亡」動畫）
const _EVENT_SKIP := ["collected", "broken", "crumbled", "defeated"]
# 尖刺、岩漿關掉時變暗的顏色（跟色塊原本變暗的程度一樣）
const _DARK := Color(0.45, 0.45, 0.45)
# 皮的「狀態改變後」選項：換圖就好、換圖再加原本效果、只用原本效果（皮沒有狀態圖時一律當成只用原本效果）
const LOOK_SWAP_ONLY := 0
const LOOK_SWAP_AND_EFFECT := 1
const LOOK_EFFECT_ONLY := 2

var _owner: Node = null
var _rect: CanvasItem = null
var _skin: Node2D = null
var _skin_origin := Vector2.ZERO
var _rect_origin := Vector2.ZERO

# 找零件底下的皮並套上；color_rect 是零件原本的色塊
func _init(owner: Node, color_rect: CanvasItem) -> void:
	_owner = owner
	_rect = color_rect
	if _rect is Control:
		_rect_origin = (_rect as Control).position
	for child in owner.get_children():
		if not child.has_method("skin_setup"):
			continue
		if _skin != null:
			_warn("「%s」底下有不只一個皮，只用第一個「%s」，「%s」可以刪掉" % [owner.name, _skin.name, child.name])
			child.visible = false
			continue
		_skin = child
	var share: Node = null
	if _skin == null:
		share = _shared_skin(owner)
	if _skin == null:
		return
	var problem: String = _skin.skin_setup(is_enemy_host(owner))
	if problem != "":
		if share != null:
			share.report_problem(problem)
		else:
			_warn("「%s」的皮「%s」：%s；先顯示原本的色塊" % [owner.name, _skin.name, problem])
		_skin.visible = false
		_skin = null
		return
	_skin_origin = _skin.position
	if _skin.has_method("skin_bind"):
		_skin.skin_bind(owner)
	if _rect != null:
		_rect.visible = false

# 零件自己沒掛皮時，找關卡裡同種零件的共用皮（SkinShare），複製一份掛上去；回傳用到的共用皮，沒有回傳 null
func _shared_skin(owner: Node) -> Node:
	if Engine.is_editor_hint() or not owner.is_inside_tree():
		return null
	for share in owner.get_tree().get_nodes_in_group("skin_share"):
		var copy: Node2D = share.make_skin_for(owner)
		if copy != null:
			owner.add_child(copy)
			_skin = copy
			return share
	return null

# 零件有沒有套上皮
func has_skin() -> bool:
	return _skin != null

# 顯示零件的狀態（變色的零件：終點、按鈕、重生點）：active 是「狀態改變後」（終點踩到、按鈕亮起…），
# color 是色塊在這個狀態的顏色；皮沒有狀態圖（或選了只用原本效果）時把圖往 color 染色
func show_state(active: bool, color: Color) -> void:
	if _skin != null:
		_show_on_skin(active, Color.WHITE.lerp(color, _TINT_STRENGTH), false)
	elif _rect is ColorRect:
		(_rect as ColorRect).color = color

# 顯示零件的狀態（變淡的零件：門打開）：active 時變淡成 alpha
func show_faded(active: bool, alpha: float) -> void:
	if _skin != null:
		_show_on_skin(active, Color(1, 1, 1, alpha), false)
	elif _rect != null:
		_rect.modulate.a = alpha if active else 1.0

# 顯示零件的狀態（藏起來的零件：開關方塊關掉）：active 時整個看不到
func show_hidden(active: bool) -> void:
	if _skin != null:
		_show_on_skin(active, Color.WHITE, true)
	elif _rect != null:
		_rect.visible = not active

# 顯示零件的狀態（變暗的零件：尖刺、岩漿關掉）：active 時變暗
func show_dark(active: bool) -> void:
	if _skin != null:
		_show_on_skin(active, _DARK, false)
	elif _rect != null:
		_rect.modulate = _DARK if active else Color.WHITE

# 把狀態套到皮上：依皮的「狀態改變後」選項決定換圖、加原本效果（tint 染色／變淡、hide 藏起來），或兩個都做
func _show_on_skin(active: bool, tint: Color, hide: bool) -> void:
	var look: int = _skin.skin_active_look() if active else LOOK_EFFECT_ONLY
	var swap := active and look != LOOK_EFFECT_ONLY
	var effect := active and look != LOOK_SWAP_ONLY
	_skin.skin_set_state(swap, tint if effect else Color.WHITE)
	_skin.visible = not (effect and hide)

# 整個零件變淡（alpha 0～1），例如崩塌地板快消失、門打開後半透明
func set_alpha(alpha: float) -> void:
	var target: CanvasItem = _skin if _skin != null else _rect
	if target != null:
		target.modulate.a = alpha

# 零件看不看得到（例如可破壞的方塊碎掉時藏起來）
func set_visible(value: bool) -> void:
	if _skin != null:
		_skin.visible = value
	elif _rect != null:
		_rect.visible = value

# 零件抖一下：offset 是離原本位置多遠，傳 Vector2.ZERO 回到原位（例如崩塌地板快碎掉）
func set_shake(offset: Vector2) -> void:
	if _skin != null:
		_skin.position = _skin_origin + offset
	elif _rect is Control:
		(_rect as Control).position = _rect_origin + offset

# 零件面向左邊還是右邊（敵人轉向），皮勾了 follow_facing 才會翻；
# 以皮在編輯器裡的 Flip H 當「朝右」的樣子（圖朝左畫的，學員勾 Flip H 讓它朝右）
func set_facing(facing_left: bool) -> void:
	if _skin != null:
		_skin.skin_set_facing(facing_left)

# 播一段動畫（敵人的「受傷」「死亡」）；靜態的皮、沒有這段動畫時什麼都不做
func play(anim_name: String) -> void:
	if _skin != null:
		_skin.skin_play(anim_name)

# 這段動畫播一次要幾秒；靜態的皮、沒有這段動畫時回傳 0（敵人用來決定死掉後多久才藏起來）
func anim_length(anim_name: String) -> float:
	return _skin.skin_anim_length(anim_name) if _skin != null else 0.0

# 回到平常的動畫（敵人重生復活時，從停在最後一格的「死亡」回到「走路」）
func reset_anim() -> void:
	if _skin != null:
		_skin.skin_reset()

# ---- Skin、SkinAnimated 共用

# 這個節點是不是敵人（SkinAnimated 依此決定要檢查哪些動畫名稱）
static func is_enemy_host(node: Node) -> bool:
	var host_script := _host_script(node)
	return host_script != null and host_script.resource_path in _ENEMY_SCRIPTS

# 這個零件有哪些事件可以讓 SkinEvent 播動畫：中文 → 訊號名稱（照零件定義的順序）
static func event_signals(host: Node) -> Dictionary:
	var result := {}
	var host_script := _host_script(host)
	if host_script == null:
		return result
	for info in host_script.get_script_signal_list():
		var signal_name: String = info.name
		if signal_name in _EVENT_SKIP:
			continue
		result[_EVENT_LABELS.get(signal_name, signal_name)] = signal_name
	return result

# 這個零件有沒有方向（風扇吹的方向），皮可以跟著轉
static func is_directional_host(node: Node) -> bool:
	var host_script := _host_script(node)
	return host_script != null and _DIRECTIONAL_SCRIPTS.has(host_script.resource_path)

# 這個零件現在的方向要把皮轉幾度（弧度）；沒有方向的零件回傳 0
static func host_angle(node: Node) -> float:
	if not is_directional_host(node) or is_share(node):
		return 0.0
	var angles: Array = _DIRECTIONAL_SCRIPTS[node.get_script().resource_path]
	var index := int(node.get("direction"))
	return deg_to_rad(angles[index]) if index >= 0 and index < angles.size() else 0.0

# 皮套在哪種零件上：一般是零件自己的腳本；放在共用皮底下時是共用皮選的那種零件
static func _host_script(node: Node) -> Script:
	if node == null:
		return null
	if is_share(node):
		return node.share_target_script()
	return node.get_script()

# 這個節點是不是共用皮（SkinShare）
static func is_share(node: Node) -> bool:
	return node != null and node.has_method("make_skin_for")

# 皮放在零件底下或共用皮底下（fill_style 這類「對齊零件」的設定才有意義）
static func is_block_host(node: Node) -> bool:
	return block_visual(node) != null or is_share(node)

# 這個節點是不是 Player → Visual（皮放在這裡當角色的圖）
static func is_player_visual(node: Node) -> bool:
	if node == null or node is ColorRect:
		return false
	return node.name == "Visual" or node.is_in_group("player_visual")

# 零件原本的色塊（找不到回傳 null，代表不是有色塊的零件）
static func block_visual(host: Node) -> ColorRect:
	if host == null:
		return null
	for n in BLOCK_VISUAL_NAMES:
		var found := host.get_node_or_null(NodePath(n))
		if found is ColorRect:
			return found
	return null

# 皮的放置問題：沒問題回傳空字串
static func placement_problem(skin: Node) -> String:
	var host := skin.get_parent()
	if host == null:
		return ""
	if block_visual(host) == null and not is_player_visual(host) and not is_share(host):
		return "皮要放在零件（終點、門、敵人…）底下、共用皮 SkinShare 底下，或 Player → Visual 底下；放在「%s」底下不會有作用" % host.name
	for sibling in host.get_children():
		if sibling.has_method("skin_setup") and not sibling.has_meta(&"skin_share_preview"):
			if sibling != skin:
				return "「%s」底下已經有一個皮「%s」，只會用那一個，這個可以刪掉" % [host.name, sibling.name]
			break
	return ""

# 原本色塊的範圍（換算成皮自己的座標），編輯器畫外框用；不在零件底下回傳空的範圍
static func block_rect_local(skin: Node2D) -> Rect2:
	var visual := block_visual(skin.get_parent())
	if visual == null:
		return Rect2()
	return skin.transform.affine_inverse() * Rect2(visual.position, visual.size)

# 編輯器裡：皮能用（usable）時藏起零件原本的色塊，擺的時候看到的就是遊戲裡的樣子；皮有問題、被藏起來、放錯地方時色塊照舊顯示。
# 只改畫面、不改色塊的 visible，不會存進學員的場景。hidden 是上次藏的色塊（皮被拖到別的零件時把舊的顯示回來），回傳這次藏的色塊
static func editor_hide_block(skin: CanvasItem, usable: bool, hidden: ColorRect) -> ColorRect:
	var visual := block_visual(skin.get_parent())
	if hidden != visual:
		editor_show_block(hidden)
	if visual == null:
		return null
	var hide := usable and skin.visible and placement_problem(skin) == ""
	RenderingServer.canvas_item_set_visible(visual.get_canvas_item(), visual.visible and not hide)
	return visual if hide else null

# 編輯器裡：把 editor_hide_block 藏起來的色塊顯示回來（皮被刪掉、拖走時）
static func editor_show_block(hidden: ColorRect) -> void:
	if hidden != null and is_instance_valid(hidden):
		RenderingServer.canvas_item_set_visible(hidden.get_canvas_item(), hidden.visible)

# 畫原本色塊的虛線外框（教學提醒「圖要畫在框裡」）
static func draw_outline(skin: Node2D) -> void:
	var r := block_rect_local(skin)
	if r.size == Vector2.ZERO:
		return
	var color := Color(1.0, 0.85, 0.2, 0.9)
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		skin.draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 1.0, 2.0)

# 印中文警告到輸出面板（皮自己也用這個）
static func warn(message: String) -> void:
	_warn(message)

# 印中文警告到輸出面板
static func _warn(message: String) -> void:
	push_warning("[皮] %s" % message)
	printerr("⚠ [皮] %s" % message)
