extends StyleBox
class_name PanelBox

# 選單、HUD 的底框：底框圖（依配色的 panel 上色）上面再疊一圈外框圖（依配色的 accent 上色）。
# UIRoot 建 Theme 時產生，學員不用碰；外框是空的就只畫底框。

var fill: StyleBoxTexture = null
var outline: StyleBoxTexture = null

# 先畫底框，再把外框疊上去
func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if fill != null:
		fill.draw(to_canvas_item, rect)
	if outline != null:
		outline.draw(to_canvas_item, rect)
