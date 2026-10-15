@tool
extends Node2D

# 關卡的背景：拖進關卡（放最上層底下），把圖片拖進 texture 就好。永遠畫在所有東西後面，不用管場景樹的順序。
# 「重複鋪滿」「拉伸蓋滿」蓋多大看 cover_area：整個關卡（所有 Room 加起來；沒有 Room 就看地形，關卡變大也跟著變）、
# 所在的房間（拖到某個 Room 底下，只蓋那個房間）、自己拉範圍（從這個節點的位置往右下，寬高用格數拉）。
# 「只放一張」放在這個節點的位置，自己拖。勾 parallax 會變成遠景：鏡頭移動時背景動得比較慢。
# 好幾個背景疊在一起時，範圍小的自動蓋在上面（自己拉的 > 所在的房間 > 整個關卡，遠景再往後一層）；同一種的話場景樹排後面的蓋在上面。

## 背景圖：從檔案系統把圖片拖進來
@export var texture: Texture2D:
	set(value):
		texture = value
		_rebuild()
		update_configuration_warnings()
## 圖怎麼蓋住關卡：只放一張（放在這個節點的位置）、重複鋪滿（一格一格接起來，圖要能左右上下接得起來）、拉伸蓋滿（一張拉大蓋住整個關卡）
@export_enum("只放一張", "重複鋪滿", "拉伸蓋滿") var fill_style: int = FILL_TILE:
	set(value):
		fill_style = value
		notify_property_list_changed()
		_rebuild()
## 蓋多大：整個關卡、所在的房間（把背景拖到某個 Room 底下）、自己拉範圍（從這個節點的位置往右下）
@export_enum("整個關卡", "所在的房間", "自己拉範圍") var cover_area: int = COVER_LEVEL:
	set(value):
		cover_area = value
		notify_property_list_changed()
		_rebuild()
		update_configuration_warnings()
## 自己拉範圍：寬幾格（一格 16 像素）
@export_range(1, 256, 1, "or_greater") var width_in_tiles: int = 30:
	set(value):
		width_in_tiles = value
		_rebuild()
## 自己拉範圍：高幾格（一格 16 像素）
@export_range(1, 128, 1, "or_greater") var height_in_tiles: int = 17:
	set(value):
		height_in_tiles = value
		_rebuild()
## 遠景：鏡頭移動時背景動得比較慢，看起來比較遠
@export var parallax: bool = false:
	set(value):
		parallax = value
		notify_property_list_changed()
		_rebuild()
## 遠景有多遠：越小越遠、動得越慢（1 就跟關卡一起動）
@export_range(0.1, 0.9, 0.1) var depth: float = 0.5:
	set(value):
		depth = value
		_rebuild()
## 不檢查畫面風格（圖會不會糊、縮放是不是整數倍）：故意用糊糊的背景時勾起來
@export var ignore_style_check: bool = false:
	set(value):
		ignore_style_check = value
		update_configuration_warnings()

const FILL_ONE := 0
const FILL_TILE := 1
const FILL_STRETCH := 2
const COVER_LEVEL := 0
const COVER_ROOM := 1
const COVER_CUSTOM := 2

const _Z := -100
# 每種範圍往上加幾層（整個關卡最底、所在的房間、自己拉的範圍和只放一張最上），遠景再往下幾層
const _Z_COVER := [0, 1, 2]
const _Z_PARALLAX := -3
const _TILE_SIZE := 16
const _DEFAULT_VIEW := Vector2(480, 270)
const _EDITOR_REFIT_SEC := 0.5

var _parallax_node: Parallax2D = null
var _sprite: Sprite2D = null
var _tile_texture: Texture2D = null   # 從圖集切出來的圖要重複鋪滿時，先轉成單張圖
var _last_bounds := Rect2()
var _refit_timer := 0.0
var _outline: Node2D = null  # 編輯器裡畫「自己拉範圍」的框（畫在最上面，不被背景蓋住）

# 建內部的遠景層和圖、放到最底下；遊戲中等鏡頭準備好再對齊關卡範圍，放錯地方印中文警告
func _ready() -> void:
	z_index = _Z
	z_as_relative = false
	add_to_group("skin_background")
	_parallax_node = Parallax2D.new()
	add_child(_parallax_node, false, Node.INTERNAL_MODE_FRONT)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_parallax_node.add_child(_sprite)
	if Engine.is_editor_hint():
		_outline = Node2D.new()
		_outline.z_index = 100
		_outline.z_as_relative = false
		_outline.draw.connect(_draw_outline)
		add_child(_outline, false, Node.INTERNAL_MODE_BACK)
	_rebuild()
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	for problem in _get_problems():
		push_warning("[背景] %s" % problem)
		printerr("⚠ [背景] %s：%s" % [name, problem])
	_rebuild.call_deferred()

# 編輯器裡每半秒重新對齊一次（Room 拉大拉小、地形畫多了，背景跟著變），順便重新檢查黃色驚嘆號
func _process(delta: float) -> void:
	_refit_timer += delta
	if _refit_timer < _EDITOR_REFIT_SEC:
		return
	_refit_timer = 0.0
	if _target_bounds() != _last_bounds:
		_rebuild()
	update_configuration_warnings()

# 被拖到別的地方時重新檢查黃色驚嘆號；拖到別的 Room 底下時重新對齊
func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED:
		update_configuration_warnings()
		_rebuild.call_deferred()

# 用不到的欄位不顯示：depth 只在勾了 parallax 時；cover_area 只在重複鋪滿、拉伸蓋滿時；寬高只在自己拉範圍時
func _validate_property(property: Dictionary) -> void:
	if property.name == "depth" and not parallax:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "cover_area" and fill_style == FILL_ONE:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name in ["width_in_tiles", "height_in_tiles"] and (fill_style == FILL_ONE or cover_area != COVER_CUSTOM):
		property.usage = PROPERTY_USAGE_NO_EDITOR

# 編輯器裡就看得到：沒放圖、放錯地方、跟別的背景疊在一起、圖會糊或縮放不是整數倍
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := _get_problems()
	warnings.append_array(StyleCheck.problems(self, false))
	return warnings

# 風格檢查用：拉伸蓋滿會自己縮放，不檢查縮放
func style_scale_free() -> bool:
	return fill_style == FILL_STRETCH

# 現在的設定有什麼問題（中文），沒問題回傳空的
func _get_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	if not is_inside_tree():
		return problems
	if texture == null:
		problems.append("還沒放背景圖：從檔案系統把圖片拖進 texture")
	var parent := get_parent()
	if parent != null and parent != _scene_root() and not _is_plain_folder(parent) and not _is_room(parent):
		problems.append("背景放在「%s」底下，會跟著它動或被它藏起來：拖到關卡最上層或某個 Room 底下" % parent.name)
	if fill_style != FILL_ONE and cover_area == COVER_ROOM and not _is_room(parent):
		problems.append("cover_area 選「所在的房間」，但背景不在 Room 底下，先蓋住整個關卡：把背景拖到要蓋的那個 Room 底下")
	if not parallax and fill_style != FILL_ONE:
		var mine := _target_bounds()
		for other in _scene_backgrounds():
			if other == self:
				break
			if not other.parallax and other.fill_style != FILL_ONE and other._layer() == _layer() and mine.encloses(other._target_bounds()):
				problems.append("這個背景把前面的背景「%s」整個蓋住了，它完全看不到（場景樹排後面的蓋在上面）；要遠景加近景的話，把其中一個勾 parallax" % other.name)
				break
	return problems

# 依欄位重新擺圖：大小、位置、鋪法、遠景的速度
func _rebuild() -> void:
	if _sprite == null:
		return
	_parallax_node.scroll_scale = Vector2.ONE * (depth if parallax else 1.0)
	z_index = _layer()
	_sprite.visible = texture != null
	if texture == null:
		return
	_last_bounds = _target_bounds()
	if _outline != null:
		_outline.queue_redraw()
	_sprite.region_enabled = false
	_sprite.scale = Vector2.ONE
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_PARENT_NODE
	match fill_style:
		FILL_ONE:
			_sprite.texture = texture
			_sprite.position = -texture.get_size() / 2.0
		FILL_TILE:
			var area := _cover_area()
			_sprite.texture = _tileable(texture)
			_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			_sprite.region_enabled = true
			_sprite.region_rect = Rect2(Vector2.ZERO, area.size)
			_sprite.position = area.position - global_position
		FILL_STRETCH:
			var area := _cover_area()
			_sprite.texture = texture
			_sprite.scale = area.size / texture.get_size()
			_sprite.position = area.position - global_position

# 背景要蓋住的範圍（世界座標）。遠景動得比鏡頭慢，要蓋住的範圍跟著縮：
# 鏡頭左上角在 c 時，畫面看到的是遠景的 c × depth 到 c × depth + 畫面大小。編輯器裡照關卡範圍畫，方便看
func _cover_area() -> Rect2:
	var bounds := _last_bounds
	if not parallax or Engine.is_editor_hint():
		return bounds
	var view := _view_size()
	var start := bounds.position * depth
	var size := (bounds.size - view).max(Vector2.ZERO) * depth + view
	return Rect2(start, size)

# 畫面在世界裡看得到多大（照鏡頭縮放），四周多留一點給鏡頭震動、放大縮小
func _view_size() -> Vector2:
	var view := _DEFAULT_VIEW
	if is_inside_tree():
		view = get_viewport_rect().size
		var camera := get_viewport().get_camera_2d()
		if camera != null:
			view /= camera.zoom
	return view

# 畫在第幾層：範圍小的在上面，遠景在下面
func _layer() -> int:
	var cover := COVER_CUSTOM if fill_style == FILL_ONE else cover_area
	return _Z + _Z_COVER[cover] + (_Z_PARALLAX if parallax else 0)

# 這個背景要蓋的範圍（世界座標，還沒算遠景）：照 cover_area 是整個關卡、所在的房間、還是自己拉的範圍
func _target_bounds() -> Rect2:
	if cover_area == COVER_CUSTOM:
		return Rect2(global_position, Vector2(width_in_tiles, height_in_tiles) * _TILE_SIZE)
	if cover_area == COVER_ROOM and _is_room(get_parent()):
		return get_parent().get_rect()
	return _level_bounds()

# 編輯器裡畫「自己拉範圍」的虛線框（跟 AreaTrigger 一樣的黃色虛線）
func _draw_outline() -> void:
	if cover_area != COVER_CUSTOM or fill_style == FILL_ONE:
		return
	var size := Vector2(width_in_tiles, height_in_tiles) * _TILE_SIZE
	var color := Color(1.0, 0.85, 0.2, 0.9)
	var corners := [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]
	for i in 4:
		_outline.draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 1.0, 4.0)

# 這個節點是不是 Room（有房間範圍和起點）
func _is_room(node: Node) -> bool:
	return node != null and node.has_method("get_rect") and node.has_method("get_spawn_point")

# 整個關卡的範圍：所有 Room 加起來；沒有 Room 就用地形畫到的範圍；都沒有就一個畫面大
func _level_bounds() -> Rect2:
	var root := _scene_root()
	var bounds := Rect2()
	var found := false
	if root != null:
		for node in root.find_children("*", "Area2D", true, false):
			if node.has_method("get_rect") and node.has_method("get_spawn_point"):
				var rect: Rect2 = node.get_rect()
				bounds = rect if not found else bounds.merge(rect)
				found = true
		if not found:
			for node in root.find_children("*", "TileMapLayer", true, false):
				var layer := node as TileMapLayer
				var used := layer.get_used_rect()
				if used.size == Vector2i.ZERO:
					continue
				var tile := Vector2(layer.tile_set.tile_size) if layer.tile_set != null else Vector2(_TILE_SIZE, _TILE_SIZE)
				var rect := Rect2(layer.to_global(Vector2(used.position) * tile), Vector2(used.size) * tile)
				bounds = rect if not found else bounds.merge(rect)
				found = true
	if not found:
		bounds = Rect2(Vector2.ZERO, _DEFAULT_VIEW)
	return bounds.grow(_TILE_SIZE * 2)

# 從圖集切出來的圖不能直接重複（會鋪到整張大圖），先轉成單張圖
func _tileable(tex: Texture2D) -> Texture2D:
	if not tex is AtlasTexture:
		return tex
	if _tile_texture == null or _tile_texture.get_meta("source", null) != tex:
		_tile_texture = ImageTexture.create_from_image(tex.get_image())
		_tile_texture.set_meta("source", tex)
	return _tile_texture

# 場景的最上層（編輯器裡是正在編輯的場景）
func _scene_root() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene

# 只是用來整理場景樹的資料夾節點（沒掛腳本的 Node／Node2D）
func _is_plain_folder(node: Node) -> bool:
	return node.get_script() == null and (node.get_class() == "Node2D" or node.get_class() == "Node")

# 場景裡的背景零件，照場景樹的順序
func _scene_backgrounds() -> Array:
	var root := _scene_root()
	if root == null:
		return []
	var result := []
	for node in root.find_children("*", "Node2D", true, false):
		if node.get_script() == get_script():
			result.append(node)
	return result
