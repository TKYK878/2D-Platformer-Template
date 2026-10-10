class_name SkinLink
extends RefCounted

# 零件端的皮：零件開場時建一個（SkinLink.new(self, 色塊)），之後所有外觀變化都透過它。
# 零件底下有 Skin／SkinAnimated 就藏起色塊、改作用在皮上；沒有皮就照舊改色塊。
# 皮設定有問題（沒放圖、缺動畫）時印中文警告，照舊顯示色塊，遊戲不會因此看不到零件。
# 另外放 Skin、SkinAnimated 共用的檢查：放對地方了沒、原本色塊的範圍在哪。

# 零件裡色塊的節點名稱（風扇的本體叫 BodyVisual）
const BLOCK_VISUAL_NAMES := ["Visual", "BodyVisual"]
# 這些零件是敵人：動畫名稱用「走路」「受傷」「死亡」
const _ENEMY_SCRIPTS := ["res://blocks/_scripts/Enemy.gd", "res://blocks/_scripts/EnemyShooter.gd"]
# 狀態改變後沒有另外的圖時，平常的圖往狀態顏色染多少（0～1）
const _TINT_STRENGTH := 0.6

var _owner: Node = null
var _rect: CanvasItem = null
var _skin: Node2D = null

# 找零件底下的皮並套上；color_rect 是零件原本的色塊
func _init(owner: Node, color_rect: CanvasItem) -> void:
	_owner = owner
	_rect = color_rect
	for child in owner.get_children():
		if not child.has_method("skin_setup"):
			continue
		if _skin != null:
			_warn("「%s」底下有不只一個皮，只用第一個「%s」，「%s」可以刪掉" % [owner.name, _skin.name, child.name])
			child.visible = false
			continue
		_skin = child
	if _skin == null:
		return
	var problem: String = _skin.skin_setup(is_enemy_host(owner))
	if problem != "":
		_warn("「%s」的皮「%s」：%s；先顯示原本的色塊" % [owner.name, _skin.name, problem])
		_skin.visible = false
		_skin = null
		return
	if _rect != null:
		_rect.visible = false

# 零件有沒有套上皮
func has_skin() -> bool:
	return _skin != null

# 顯示零件的狀態：active 是「狀態改變後」（終點踩到、門打開…），color 是色塊在這個狀態的顏色。
# 有皮時換成 texture_active／「啟動」動畫，沒有的話平常的圖往 color 染色
func show_state(active: bool, color: Color) -> void:
	if _skin != null:
		_skin.skin_set_state(active, Color.WHITE.lerp(color, _TINT_STRENGTH))
	elif _rect is ColorRect:
		(_rect as ColorRect).color = color

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

# 零件面向左邊還是右邊（敵人轉向），皮勾了 follow_facing 才會翻
func set_facing(facing_left: bool) -> void:
	if _skin != null:
		_skin.skin_set_facing(facing_left)

# 播一段動畫（敵人的「受傷」「死亡」）；靜態的皮、沒有這段動畫時什麼都不做
func play(anim_name: String) -> void:
	if _skin != null:
		_skin.skin_play(anim_name)

# ---- Skin、SkinAnimated 共用

# 這個節點是不是敵人（SkinAnimated 依此決定要檢查哪些動畫名稱）
static func is_enemy_host(node: Node) -> bool:
	var host_script: Script = node.get_script() if node != null else null
	return host_script != null and host_script.resource_path in _ENEMY_SCRIPTS

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
	if block_visual(host) == null and not is_player_visual(host):
		return "皮要放在零件（終點、門、敵人…）底下，或 Player → Visual 底下；放在「%s」底下不會有作用" % host.name
	for sibling in host.get_children():
		if sibling.has_method("skin_setup"):
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

# 畫原本色塊的虛線外框（教學提醒「圖要畫在框裡」）
static func draw_outline(skin: Node2D) -> void:
	var r := block_rect_local(skin)
	if r.size == Vector2.ZERO:
		return
	var color := Color(1.0, 0.85, 0.2, 0.9)
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		skin.draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 1.0, 2.0)

# 印中文警告到輸出面板
static func _warn(message: String) -> void:
	push_warning("[皮] %s" % message)
	printerr("⚠ [皮] %s" % message)
