@tool
extends Sprite2D

# 零件的皮（靜態圖）：在關卡裡選一個零件（終點、門、敵人…），把這個拖進去當子節點，再把圖片拖進 texture_normal。
# 遊戲開始時零件會藏起原本的色塊、改顯示這張圖；狀態改變時換成 texture_active（空白就把平常的圖變色）。
# 編輯器裡的黃色虛線框是原本色塊的範圍：碰撞範圍不會跟著圖片變，圖要畫在框裡。
# 也可以放在 Player → Visual 底下當角色的圖。

## 平常的樣子：從檔案系統把圖片拖進來
@export var texture_normal: Texture2D:
	set(value):
		texture_normal = value
		texture = value
		update_configuration_warnings()
## 狀態改變後的樣子（終點踩到、按鈕亮起、門打開、重生點啟用、開關方塊切換…）；空白就用平常的圖再變色表示
@export var texture_active: Texture2D
## 要不要跟著零件左右翻（敵人轉向）
@export var follow_facing: bool = true

# 顯示平常的圖；編輯器裡持續重畫外框（零件大小改了框跟著變）
func _ready() -> void:
	texture = texture_normal
	set_process(Engine.is_editor_hint())

# 編輯器裡每一幀重畫外框
func _process(_delta: float) -> void:
	queue_redraw()

# 被拖到別的地方時重新檢查黃色驚嘆號
func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED:
		update_configuration_warnings()

# texture 由 texture_normal 決定，不存進場景檔、Inspector 也不顯示，免得學員拖錯格
func _validate_property(property: Dictionary) -> void:
	if property.name == "texture":
		property.usage = PROPERTY_USAGE_NONE

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
	return warnings

# 零件開場時呼叫：能用回傳空字串，不能用回傳原因
func skin_setup(_is_enemy: bool) -> String:
	if texture_normal == null:
		return "texture_normal 是空的，請把圖片拖進來"
	texture = texture_normal
	return ""

# 零件呼叫：切換平常／狀態改變後的樣子；沒有 texture_active 時用 tint 把平常的圖染色
func skin_set_state(active: bool, tint: Color) -> void:
	if active and texture_active != null:
		texture = texture_active
		self_modulate = Color.WHITE
	else:
		texture = texture_normal
		self_modulate = tint if active else Color.WHITE

# 零件呼叫：面向左邊時翻過來（follow_facing 有勾才翻）
func skin_set_facing(facing_left: bool) -> void:
	if follow_facing:
		flip_h = facing_left

# 零件呼叫：靜態圖沒有動畫，什麼都不做
func skin_play(_anim_name: String) -> void:
	pass
