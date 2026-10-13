@tool
extends Sprite2D

# 零件的皮（靜態圖）：在關卡裡選一個零件（終點、門、敵人…），把這個拖進去當子節點，再把圖片拖進 texture_normal。
# 遊戲開始時零件會藏起原本的色塊、改顯示這張圖；狀態改變時換成 texture_active（空白就把平常的圖變色）。
# 編輯器裡的黃色虛線框是原本色塊的範圍：碰撞範圍不會跟著圖片變，圖要畫在框裡。
# fill_style 選「重複鋪滿」「拉伸蓋滿」時，位置和大小自動對齊色塊（可以拉大小的無反彈方塊、單向平台用得到）。
# 也可以放在 Player → Visual 底下當角色的圖。

## 平常的樣子：從檔案系統把圖片拖進來
@export var texture_normal: Texture2D:
	set(value):
		texture_normal = value
		_show(value)
		update_configuration_warnings()
## 狀態改變後的樣子（終點踩到、按鈕亮起、門打開、重生點啟用、開關方塊關掉、尖刺岩漿關掉…）；空白就用平常的圖再變色表示
@export var texture_active: Texture2D:
	set(value):
		texture_active = value
		notify_property_list_changed()
## 狀態改變後怎麼顯示：只換成 texture_active、換圖之外再加零件原本的效果（變色、變淡、藏起來、變暗），
## 或不換圖只用原本的效果
@export_enum("換圖就好", "換圖再加原本效果", "只用原本效果") var active_style: int = 0
## 圖怎麼蓋住零件：只放一張（位置大小自己調）、重複鋪滿、拉伸蓋滿；
## 後兩個會自動對齊原本色塊的範圍，零件拉大拉小也跟著變
@export_enum("只放一張", "重複鋪滿", "拉伸蓋滿") var fill_style: int = 0:
	set(value):
		fill_style = value
		_show(_shown)
## 要不要跟著零件左右翻（敵人轉向）
@export var follow_facing: bool = true
## 要不要跟著零件的方向轉（風扇吹的方向）；圖請畫成朝上吹
@export var follow_direction: bool = true
## 不檢查畫面風格（圖會不會糊、縮放是不是整數倍、像素大小跟其他皮差太多）：故意混用不同風格的素材時勾起來
@export var ignore_style_check: bool = false:
	set(value):
		ignore_style_check = value
		update_configuration_warnings()

const FILL_ONE := 0
const FILL_TILE := 1
const FILL_STRETCH := 2

var _shown: Texture2D = null  # 現在顯示的是哪一張（平常或狀態改變後）
var _tile_textures := {}  # 從圖集切出來的圖要重複鋪滿時，先轉成單張圖（圖集直接重複會鋪到整張大圖）
var _base_flip := false  # 編輯器裡 Flip H 有沒有勾（當作「朝右」的樣子）
var _style_timer := 0.0

# 顯示平常的圖；編輯器裡持續重畫外框（零件大小改了框跟著變）
func _ready() -> void:
	_show(texture_normal)
	set_process(Engine.is_editor_hint())

# 編輯器裡每一幀重畫外框，並跟著零件的大小、方向重新對齊；每秒重新檢查黃色驚嘆號（縮放、Filter 改了要更新）
func _process(delta: float) -> void:
	queue_redraw()
	_fit()
	_style_timer += delta
	if _style_timer >= 1.0:
		_style_timer = 0.0
		update_configuration_warnings()

# 被拖到別的地方時重新檢查黃色驚嘆號、Inspector 要顯示哪些欄位
func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED:
		update_configuration_warnings()
		notify_property_list_changed()

# texture 由 texture_normal 決定，不存進場景檔、Inspector 也不顯示，免得學員拖錯格；
# 用不到的欄位不顯示：沒有 texture_active 時的 active_style、不在零件底下時的 fill_style、零件沒有方向時的 follow_direction
func _validate_property(property: Dictionary) -> void:
	if property.name == "texture":
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "active_style" and texture_active == null:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "fill_style" and SkinLink.block_visual(get_parent()) == null:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "follow_direction" and not SkinLink.is_directional_host(get_parent()):
		property.usage = PROPERTY_USAGE_NO_EDITOR

# 編輯器裡畫原本色塊的虛線外框
func _draw() -> void:
	if Engine.is_editor_hint():
		SkinLink.draw_outline(self)

# 黃色驚嘆號：放錯地方、沒放圖
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var problem := SkinLink.placement_problem(self)
	if problem != "":
		warnings.append(problem)
	if texture_normal == null:
		warnings.append("texture_normal 是空的：從檔案系統把圖片拖進來，不然遊戲中還是顯示原本的色塊")
	warnings.append_array(StyleCheck.problems(self, true))
	return warnings

# 風格檢查用：拉伸蓋滿會自己縮放，不檢查縮放與像素大小
func style_scale_free() -> bool:
	return fill_style == FILL_STRETCH and SkinLink.block_visual(get_parent()) != null

# 風格檢查用：縮放不是整數倍時的補充建議（在零件底下才有 fill_style 可以選）
func style_fill_hint() -> String:
	if SkinLink.block_visual(get_parent()) == null:
		return ""
	return "（要蓋住整個零件就把 fill_style 改成「重複鋪滿」）"

# 換成顯示 tex，依 fill_style 準備重複鋪滿用的圖，再對齊零件
func _show(tex: Texture2D) -> void:
	_shown = tex
	var tile := fill_style == FILL_TILE and tex != null
	texture = _tile_texture(tex) if tile else tex
	region_enabled = tile
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED if tile else CanvasItem.TEXTURE_REPEAT_PARENT_NODE
	_fit()

# 重複鋪滿用的圖：從圖集切出來的圖轉成單張圖，其他的直接用
func _tile_texture(tex: Texture2D) -> Texture2D:
	if not (tex is AtlasTexture):
		return tex
	if not _tile_textures.has(tex):
		var image := tex.get_image()
		_tile_textures[tex] = ImageTexture.create_from_image(image) if image != null else tex
	return _tile_textures[tex]

# 跟著零件的方向轉；重複鋪滿、拉伸蓋滿時把位置和大小對齊原本色塊的範圍
func _fit() -> void:
	var host := get_parent()
	if host == null:
		return
	if follow_direction and SkinLink.is_directional_host(host):
		var angle := SkinLink.host_angle(host)
		if not is_equal_approx(rotation, angle):
			rotation = angle
	var visual := SkinLink.block_visual(host)
	if fill_style == FILL_ONE or visual == null or texture == null:
		return
	var rect := Rect2(visual.position, visual.size)
	centered = true
	offset = Vector2.ZERO
	if position != rect.get_center():
		position = rect.get_center()
	var target_scale := Vector2.ONE
	if fill_style == FILL_TILE:
		region_rect = Rect2(Vector2.ZERO, rect.size)
	elif _shown.get_width() > 0 and _shown.get_height() > 0:
		target_scale = rect.size / _shown.get_size()
	if scale != target_scale:
		scale = target_scale

# 零件開場時呼叫：能用回傳空字串，不能用回傳原因
func skin_setup(_is_enemy: bool) -> String:
	if texture_normal == null:
		return "texture_normal 是空的，請把圖片拖進來"
	_show(texture_normal)
	_base_flip = flip_h
	return ""

# 零件呼叫：狀態改變後要怎麼顯示（SkinLink.LOOK_…）；沒有 texture_active 時只能用原本的效果
func skin_active_look() -> int:
	return active_style if texture_active != null else SkinLink.LOOK_EFFECT_ONLY

# 零件呼叫：換成 texture_active（use_active）或平常的圖，再用 tint 染色／變淡（不加效果時是白色）
func skin_set_state(use_active: bool, tint: Color) -> void:
	var tex := texture_active if use_active and texture_active != null else texture_normal
	if tex != _shown:
		_show(tex)
	self_modulate = tint

# 零件呼叫：面向左邊時翻過來（follow_facing 有勾才翻），以編輯器裡的 Flip H 當朝右的樣子
func skin_set_facing(facing_left: bool) -> void:
	if follow_facing:
		flip_h = _base_flip != facing_left

# 零件呼叫：靜態圖沒有動畫，什麼都不做
func skin_play(_anim_name: String) -> void:
	pass

# 零件呼叫：靜態圖沒有動畫，長度是 0
func skin_anim_length(_anim_name: String) -> float:
	return 0.0

# 零件呼叫：靜態圖沒有動畫，什麼都不做
func skin_reset() -> void:
	pass
