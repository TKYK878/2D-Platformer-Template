extends Node

# Stats 的預設畫面：用 ui/templates/HudTemplate.tscn 範本顯示在左上角，學員不用擺任何 UI 節點。
# ValueSettings 把 show_in_hud 打開的種類一開場就顯示；沒有 ValueSettings 的種類，第一次被實際加減到時才出現。
# 範本裡有的種類（血量、金幣）用範本那一列，其他種類自動多生一列「圖示＋數字」。
# 學員的 HUD 有顯示某個數值時（HudData 有人認領），預設的那一列讓位藏起來。
# 另外提供畫面角落的共用容器，給機制卡、零件放自己的預設 UI。

const _TEMPLATE := preload("res://ui/templates/HudTemplate.tscn")
const _NUMBER := preload("res://ui/HudNumber.tscn")

var _hud: CanvasLayer = null
var _rows_box: Container = null
var _rows: Dictionary = {}   # kind(String) -> 那一列的 Control
var _seen: Dictionary = {}   # kind(String) -> true：已經該出現了（設定成顯示，或被用到過）
var _corner_layer: CanvasLayer = null
var _corners: Dictionary = {}  # 角落 -> VBoxContainer，機制卡、零件的預設 UI 放這裡自動上下排

const CORNER_TOP_RIGHT := 0
const CORNER_BOTTOM_LEFT := 1

# 開始監聽 Stats 的數值變動與設定、學員 HUD 的認領
func _ready() -> void:
	Stats.value_changed.connect(_on_value_changed)
	Stats.configured.connect(_on_configured)
	HudData.claims_changed.connect(_refresh_visibility)

# ValueSettings 套用設定：show_in_hud 打開就立刻顯示這一列，關掉就藏起來
func _on_configured(kind: String) -> void:
	if Stats.is_hud_visible(kind):
		_seen[kind] = true
		_ensure_row(kind)
	_refresh_visibility()

# 數值變動時：第一次看到這個種類就讓它出現（範本沒有的種類先生一列）。
# ValueSettings 把 show_in_hud 關掉的種類永遠不出現在畫面上。
func _on_value_changed(kind: String, _old_value: int, _new_value: int) -> void:
	if not Stats.is_hud_visible(kind):
		return
	_seen[kind] = true
	_ensure_row(kind)
	_refresh_visibility()

# 每一列要不要顯示：該出現了、沒被設定成不顯示、沒被學員的 HUD 認領
func _refresh_visibility() -> void:
	for kind in _rows:
		var row: Control = _rows[kind]
		if is_instance_valid(row):
			row.visible = _seen.has(kind) and Stats.is_hud_visible(kind) and not HudData.is_claimed(kind)

# 拿到畫面某個角落的共用容器：機制卡、零件把自己的預設 UI 加進來，好幾個同時出現時自動上下排、不會疊在一起。
# 加進來的東西屬於這裡，不會跟著卡片一起刪掉，卡片被拔掉時要自己 queue_free 掉
func get_corner(corner: int) -> VBoxContainer:
	if _corners.has(corner):
		return _corners[corner]
	if _corner_layer == null:
		_corner_layer = CanvasLayer.new()
		add_child(_corner_layer)
	var box := VBoxContainer.new()
	if corner == CORNER_TOP_RIGHT:
		box.anchor_left = 1.0
		box.anchor_right = 1.0
		box.offset_left = -4.0
		box.offset_right = -4.0
		box.offset_top = 4.0
		box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		box.alignment = BoxContainer.ALIGNMENT_BEGIN
		box.child_entered_tree.connect(func(child: Node):
			if child is Control:
				child.size_flags_horizontal = Control.SIZE_SHRINK_END)
	else:
		box.anchor_top = 1.0
		box.anchor_bottom = 1.0
		box.offset_left = 4.0
		box.offset_top = -4.0
		box.offset_bottom = -4.0
		box.grow_vertical = Control.GROW_DIRECTION_BEGIN
		box.alignment = BoxContainer.ALIGNMENT_END
	_corner_layer.add_child(box)
	_corners[corner] = box
	return box

# 第一次真的需要顯示東西時，把範本生出來放進自己的 CanvasLayer；範本裡每一列先藏起來，記下是哪個種類
func _ensure_hud() -> void:
	if _hud != null:
		return
	_hud = CanvasLayer.new()
	add_child(_hud)
	var root: Control = _TEMPLATE.instantiate()
	_mark_default(root)
	_hud.add_child(root)
	_rows_box = root.get_node("Rows")
	for row in _rows_box.get_children():
		var kind := _row_kind(row)
		if kind != "":
			_rows[kind] = row
			row.visible = false

# 這個種類還沒有對應的一列就生一列「圖示＋數字」（圖示顏色依名稱固定，同一個種類每次都一樣）
func _ensure_row(kind: String) -> void:
	_ensure_hud()
	if _rows.has(kind):
		return
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(10, 10)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hue: float = float(absi(hash(kind)) % 360) / 360.0
	icon.color = Color.from_hsv(hue, 0.6, 0.9)
	row.add_child(icon)
	var number: Control = _NUMBER.instantiate()
	number.kind = kind
	row.add_child(number)
	_mark_default(row)
	row.visible = false
	_rows_box.add_child(row)
	_rows[kind] = row

# 一列裡第一個顯示「數值」的零件綁的是哪個種類，找不到就回傳空字串
func _row_kind(row: Node) -> String:
	for child in row.get_children():
		if "source" in child and "kind" in child and child.source == HudBinding.SOURCE_VALUE:
			return NameCheck.clean(child.kind)
	return ""

# 把預設 HUD 裡的節點都標上 meta：零件不認領來源，UIRoot 不算學員的自訂畫面
func _mark_default(node: Node) -> void:
	node.set_meta(HudBinding.DEFAULT_META, true)
	for child in node.get_children():
		_mark_default(child)
