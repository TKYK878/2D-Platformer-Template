@tool
extends MechanicBase

# 只能用滑鼠控制：鍵盤移動完全鎖住，按住拖曳鍵（預設滑鼠左鍵）移動滑鼠瞄準，像彈弓一樣
# 放開往反方向射出去。拖進 Player → Mechanics 底下就能用，不用連任何線。

## 用哪一種按鍵拖曳；選鍵盤按鍵時，按住那顆鍵移動滑鼠瞄準，放開發射
@export_enum("鍵盤按鍵", "滑鼠左鍵", "滑鼠右鍵", "滑鼠中鍵", "Input Map 動作") var input_type: int = 1:
	set(value):
		input_type = value
		notify_property_list_changed()

## 拖曳鍵（「按鍵種類」選鍵盤按鍵時才會顯示這一欄）
@export var key: Key = KEY_E

## 「按鍵種類」選 Input Map 動作時，要聽哪一個動作（動作在「專案設定 → Input Map」裡加，可以綁手把等其他裝置）
@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin") var action: StringName = &""

## 拖到最遠時發射的力道上限
@export_range(200.0, 1200.0) var max_launch_force: float = 700.0

## 拖曳超過這個距離，力道就不會再增加
@export_range(50.0, 300.0) var max_drag_distance: float = 150.0

## 開啟後只有站在地面上才能開始拖曳瞄準
@export var ground_only: bool = true

## 拖曳時要不要畫出瞄準線
@export var show_aim_line: bool = true

## 拖曳時要不要畫出拉的中心點（按下去的位置）、可拉範圍圈，和從中心點拉到滑鼠的線
@export var show_drag_center: bool = true:
	set(value):
		show_drag_center = value
		notify_property_list_changed()

@export_group("中心點外觀")
## 要畫出哪些東西
@export_enum("中心點＋範圍圈＋拉線", "中心點＋拉線（沒有圈）", "只有中心點") var center_style: int = 0
## 風格：圈、中心點、拉線的形狀（簡單＝細實線圓點、虛線＝虛線圈，其他跟 UI 的風格同名：像素復古＝方格鋸齒圈方點、
## 乾淨極簡＝細線空心點、可愛圓角＝粗圓圈加影子、木牌＝雙層木框加釘子、科幻＝發光雙圈加刻度菱形點、
## 漫畫＝粗黑框加硬陰影、復古遊戲機＝雙線圈方框點）
@export_enum("簡單", "虛線", "像素復古", "乾淨極簡", "可愛圓角", "木牌", "科幻", "漫畫", "復古遊戲機") var look: int = 0
## 配色：中心點、圈、拉線的顏色一起換，跟 UI 的配色同名；選「自訂」才會出現下面三個取色器
@export_enum("預設", "暗色", "亮色", "復古綠", "糖果", "海洋", "森林", "夕陽", "黑白", "萬聖節", "自訂") var palette: int = 0:
	set(value):
		palette = value
		notify_property_list_changed()
## 開啟時範圍圈就是最遠能拉到的地方（跟著 max_drag_distance 變）；關掉就用下面的 range_size 自己決定圈多大
@export var range_follow_drag: bool = true:
	set(value):
		range_follow_drag = value
		notify_property_list_changed()
## 範圍圈的半徑（range_follow_drag 關掉才會顯示）；只是畫出來的大小，實際能拉多遠還是看 max_drag_distance
@export_range(20.0, 400.0) var range_size: float = 150.0
## 範圍圈、拉線的粗細
@export_range(1.0, 10.0) var line_width: float = 2.0
## 中心點的大小（有放圖片時就是圖片的大小）
@export_range(2.0, 40.0) var center_size: float = 5.0
## 中心點的顏色（palette 選自訂才會顯示；點色塊選顏色，可以調透明度）
@export var center_color: Color = Color(1.0, 0.85, 0.3, 0.9)
## 範圍圈的顏色（palette 選自訂才會顯示）
@export var range_color: Color = Color(1.0, 1.0, 1.0, 0.35)
## 從中心點拉到滑鼠那條線的顏色（palette 選自訂才會顯示）
@export var band_color: Color = Color(1.0, 0.85, 0.3, 0.9)
## 中心點換成自己的圖：把圖片從檔案系統拖進來；空白就照風格畫
@export var center_texture: Texture2D
@export_group("")

## 開始拉的那一刻發出（例如連到 Player 的 stop_motion，拉的時候速度歸零）
signal drag_started
## 放開、要射出去的那一刻發出，在推力之前（連到 Player 的 stop_motion 就是先歸零再射）；拉的距離是 0 也會發出
signal launched

# 拖曳鍵用較高優先權向 InputRouter 註冊，跟其他綁同一顆鍵的組件同時存在時彈弓先收到
const _PRIORITY := 100

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _aim_line: Line2D
# 拉的中心點、可拉範圍圈、中心點拉到滑鼠的線；放在世界座標，角色移動時中心點不會跟著跑
var _center_mark: Node2D

# center_style 的選項
const _STYLE_NO_RING := 1
const _STYLE_DOT_ONLY := 2
# look 的選項
const _LOOK_SIMPLE := 0
const _LOOK_DASHED := 1
const _LOOK_PIXEL := 2
const _LOOK_CLEAN := 3
const _LOOK_CUTE := 4
const _LOOK_WOOD := 5
const _LOOK_SCIFI := 6
const _LOOK_COMIC := 7
const _LOOK_RETRO := 8
# palette 的「自訂」選項
const _PALETTE_CUSTOM := 10
# 「預設」配色的顏色
const _DEFAULT_CENTER := Color(1.0, 0.85, 0.3, 0.9)
const _DEFAULT_RANGE := Color(1.0, 1.0, 1.0, 0.35)
# 漫畫風的黑框、陰影
const _INK := Color(0.0, 0.0, 0.0, 0.85)
# 範圍圈切成幾段（虛線圈就是隔一段畫一段）
const _RANGE_POINTS := 48
# 「中心點外觀」群組裡的欄位，show_drag_center 關掉時一起藏起來
const _LOOK_FIELDS := ["center_style", "look", "palette", "range_follow_drag", "range_size", "line_width", "center_size",
		"center_color", "range_color", "band_color", "center_texture"]
# 配色選「自訂」才出現的取色器
const _CUSTOM_COLOR_FIELDS := ["center_color", "range_color", "band_color"]

# input_type 的「Input Map 動作」選項
const _INPUT_MAP_ACTION := 4

# 編輯器裡不跑卡片的檢查（@tool 只是為了讓欄位能跟著下拉選項藏起來）
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	super._ready()

# 選滑鼠按鍵時隱藏 key 欄位；沒開中心點時藏起外觀欄位；範圍圈跟著拉的距離時藏起 range_size；配色不是自訂時藏起取色器
func _validate_property(property: Dictionary) -> void:
	if property.name == "key" and input_type != 0:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "action" and input_type != _INPUT_MAP_ACTION:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name in _LOOK_FIELDS and not show_drag_center:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "range_size" and range_follow_drag:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name in _CUSTOM_COLOR_FIELDS and palette != _PALETTE_CUSTOM:
		property.usage = PROPERTY_USAGE_NONE

# 向 InputRouter 註冊拖曳鍵的按下／放開；show_aim_line 開啟時自己生成一條瞄準線，學員不用擺
func _on_setup() -> void:
	if input_type == 0:
		InputRouter.warn_if_dangerous_key(key, "[彈弓]")
	InputRouter.bind_input(self, input_type, key, InputRouter.PRESSED, _on_drag_pressed, _PRIORITY, action)
	InputRouter.bind_input(self, input_type, key, InputRouter.RELEASED, _on_drag_released, _PRIORITY, action)
	if show_drag_center:
		_make_center_mark()
		_warn_invisible_colors()
	if not show_aim_line:
		return
	_aim_line = Line2D.new()
	_aim_line.width = 2.0
	_aim_line.default_color = Color(1.0, 1.0, 1.0, 0.8)
	_aim_line.visible = false
	add_child(_aim_line)

# 按下拖曳鍵：開始拖曳（ground_only 開啟時要先站在地面上）；沒開始拖曳就不攔截，讓其他組件收到
func _on_drag_pressed() -> bool:
	if ground_only and not player.is_on_ground():
		return false
	_dragging = true
	_drag_start = player.get_global_mouse_position()
	if _center_mark:
		_center_mark.global_position = _drag_start
		_refresh_center_mark()
	drag_started.emit()
	return true

# 放開拖曳鍵：正在拖曳才發射並攔截，否則讓其他組件收到
func _on_drag_released(_seconds: float) -> bool:
	if not _dragging:
		return false
	_release()
	return true

# 鍵盤全鎖住；拖曳中同步更新瞄準線
func apply(ctx: MoveContext) -> void:
	ctx.input_locked = true

	if _dragging and _aim_line:
		var drag: Vector2 = player.get_global_mouse_position() - _drag_start
		drag = drag.limit_length(max_drag_distance)
		_aim_line.visible = true
		_aim_line.points = PackedVector2Array([Vector2.ZERO, -drag])
	if _dragging and _center_mark:
		var pull: Vector2 = (player.get_global_mouse_position() - _drag_start).limit_length(max_drag_distance)
		for line in _center_mark.get_node("Band").get_children():
			(line as Line2D).points = PackedVector2Array([Vector2.ZERO, pull])
		_center_mark.visible = true

# 重生時取消拖曳中的狀態、藏起瞄準線
func on_respawn() -> void:
	_dragging = false
	if _aim_line:
		_aim_line.visible = false
	if _center_mark:
		_center_mark.visible = false

# 放開拖曳鍵：往拖曳的反方向發射，力道依拖曳距離比例縮放。launched 一定在推力之前發出，
# 拉的距離是 0 也發，學員用 drag_started 凍住、launched 解凍時才不會卡在空中
func _release() -> void:
	_dragging = false
	if _aim_line:
		_aim_line.visible = false
	if _center_mark:
		_center_mark.visible = false
	var drag: Vector2 = player.get_global_mouse_position() - _drag_start
	drag = drag.limit_length(max_drag_distance)
	var ratio := drag.length() / max_drag_distance
	launched.emit()
	if ratio <= 0.0:
		return
	var direction := -drag.normalized()
	player.add_impulse(direction * max_launch_force * ratio)
	Events.mechanic_event.emit("Mechanic_Slingshot", "launched")

# 生成中心點、範圍圈、拉線的節點，平常藏著；樣子在每次開始拉時由 _refresh_center_mark 照欄位畫
func _make_center_mark() -> void:
	_center_mark = Node2D.new()
	_center_mark.name = "DragCenter"
	_center_mark.top_level = true
	_center_mark.visible = false
	add_child(_center_mark)
	for part in ["Ring", "Band", "Dot"]:
		var holder := Node2D.new()
		holder.name = part
		_center_mark.add_child(holder)
	var picture := Sprite2D.new()
	picture.name = "Picture"
	_center_mark.add_child(picture)

# 照外觀欄位重畫中心點、範圍圈、拉線（遊戲中改了欄位，下次開始拉就會套用）
func _refresh_center_mark() -> void:
	for part in ["Ring", "Band", "Dot"]:
		for child in _center_mark.get_node(part).get_children():
			child.free()
	var colors := _look_colors()
	if center_style != _STYLE_NO_RING and center_style != _STYLE_DOT_ONLY:
		_draw_ring(_center_mark.get_node("Ring"), max_drag_distance if range_follow_drag else range_size, colors)
	if center_style != _STYLE_DOT_ONLY:
		_draw_band(_center_mark.get_node("Band"), colors)
	var picture: Sprite2D = _center_mark.get_node("Picture")
	picture.visible = center_texture != null
	if center_texture == null:
		_draw_dot(_center_mark.get_node("Dot"), colors)
	else:
		picture.texture = center_texture
		var longest := maxf(center_texture.get_width(), center_texture.get_height())
		picture.scale = Vector2.ONE * (center_size * 2.0 / maxf(longest, 1.0))

# 現在用的顏色：center 中心點、range 圈、band 拉線、dark 影子和釘子；跟 UI 同名的配色用 UIRoot 的那一套（亮色當中心點和拉線、字的顏色當圈）
func _look_colors() -> Dictionary:
	if palette == _PALETTE_CUSTOM:
		return {"center": center_color, "range": range_color, "band": band_color, "dark": Color(0.0, 0.0, 0.0, 0.5)}
	if palette <= 0 or palette >= UIRoot._PALETTES.size():
		return {"center": _DEFAULT_CENTER, "range": _DEFAULT_RANGE, "band": _DEFAULT_CENTER, "dark": Color(0.0, 0.0, 0.0, 0.5)}
	var set_colors: Dictionary = UIRoot._PALETTES[palette]
	return {"center": set_colors.accent, "range": Color(set_colors.text, 0.5), "band": set_colors.accent,
		"dark": Color(set_colors.back, 0.7)}

# 照風格畫範圍圈
func _draw_ring(ring: Node2D, radius: float, colors: Dictionary) -> void:
	var color: Color = colors.range
	var w := line_width
	var circle := _circle_points(radius, _RANGE_POINTS)
	match look:
		_LOOK_DASHED:
			for i in range(0, _RANGE_POINTS, 2):
				_add_line(ring, PackedVector2Array([circle[i], circle[i + 1]]), w, color)
		_LOOK_PIXEL:
			var line := _add_line(ring, _pixel_circle(radius, maxf(w * 2.0, 4.0)), w, color, true)
			line.joint_mode = Line2D.LINE_JOINT_SHARP
			line.antialiased = false
		_LOOK_CLEAN:
			_add_line(ring, circle, maxf(w * 0.5, 1.0), color, true)
		_LOOK_CUTE:
			_add_line(ring, circle, w * 2.0, Color(colors.dark, 0.35), true, Vector2(0.0, w + 1.0))
			var line := _add_line(ring, circle, w * 2.0, color, true)
			line.joint_mode = Line2D.LINE_JOINT_ROUND
		_LOOK_WOOD:
			_add_line(ring, circle, w * 3.0, Color(color.darkened(0.45), maxf(color.a, 0.6)), true)
			_add_line(ring, circle, w, color.lightened(0.2), true)
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				_add_poly(ring, _circle_points(maxf(w, 2.0), 8), colors.dark, Vector2.RIGHT.rotated(angle) * radius)
		_LOOK_SCIFI:
			_add_line(ring, circle, w * 4.0, Color(color, color.a * 0.3), true)
			_add_line(ring, circle, maxf(w * 0.75, 1.0), color, true)
			var inner := _circle_points(radius * 0.85, _RANGE_POINTS * 2)
			for i in range(0, _RANGE_POINTS * 2, 4):
				_add_line(ring, PackedVector2Array([inner[i], inner[i + 1]]), maxf(w * 0.5, 1.0), color)
			for i in 8:
				var dir := Vector2.RIGHT.rotated(TAU * i / 8.0)
				_add_line(ring, PackedVector2Array([dir * radius, dir * (radius + w * 4.0 + 4.0)]), maxf(w * 0.75, 1.0), color)
		_LOOK_COMIC:
			_add_line(ring, circle, w + 4.0, _INK, true, Vector2(4.0, 4.0))
			_add_line(ring, circle, w + 4.0, Color(0.0, 0.0, 0.0, 1.0), true)
			_add_line(ring, circle, w, Color(color, 1.0), true)
		_LOOK_RETRO:
			var thin := maxf(w * 0.75, 1.0)
			_add_line(ring, circle, thin, color, true)
			_add_line(ring, _circle_points(maxf(radius - maxf(w * 2.5, 4.0), 4.0), _RANGE_POINTS), thin, color, true)
		_:
			_add_line(ring, circle, w, color, true)

# 照風格準備拉線（點會在拖曳時每幀更新）
func _draw_band(band: Node2D, colors: Dictionary) -> void:
	var color: Color = colors.band
	var w := line_width
	match look:
		_LOOK_CLEAN:
			_add_line(band, PackedVector2Array(), maxf(w * 0.5, 1.0), color)
		_LOOK_CUTE:
			var line := _add_line(band, PackedVector2Array(), w * 1.5, color)
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_LOOK_SCIFI:
			_add_line(band, PackedVector2Array(), w * 4.0, Color(color, color.a * 0.3))
			_add_line(band, PackedVector2Array(), maxf(w * 0.75, 1.0), color)
		_LOOK_COMIC:
			_add_line(band, PackedVector2Array(), w + 4.0, Color(0.0, 0.0, 0.0, 1.0))
			_add_line(band, PackedVector2Array(), w, Color(color, 1.0))
		_LOOK_PIXEL:
			var line := _add_line(band, PackedVector2Array(), w, color)
			line.antialiased = false
		_:
			_add_line(band, PackedVector2Array(), w, color)

# 照風格畫中心點
func _draw_dot(dot: Node2D, colors: Dictionary) -> void:
	var color: Color = colors.center
	var size := center_size
	match look:
		_LOOK_PIXEL:
			_add_poly(dot, _square_points(size), color)
		_LOOK_CLEAN:
			_add_line(dot, _circle_points(size, 20), maxf(line_width * 0.5, 1.0), color, true)
			_add_poly(dot, _circle_points(maxf(size * 0.3, 1.0), 8), color)
		_LOOK_CUTE:
			_add_poly(dot, _circle_points(size, 20), Color(colors.dark, 0.35), Vector2(0.0, line_width + 1.0))
			_add_poly(dot, _circle_points(size, 20), color)
			_add_poly(dot, _circle_points(size * 0.35, 10), Color(1.0, 1.0, 1.0, 0.7), Vector2(-size, -size) * 0.3)
		_LOOK_WOOD:
			_add_poly(dot, _circle_points(size + 2.0, 16), Color(color.darkened(0.45), maxf(color.a, 0.6)))
			_add_poly(dot, _circle_points(size, 16), color)
		_LOOK_SCIFI:
			var big := size * 1.3
			_add_poly(dot, PackedVector2Array([Vector2(0, -big), Vector2(big, 0), Vector2(0, big), Vector2(-big, 0)]), color)
		_LOOK_COMIC:
			_add_poly(dot, _circle_points(size + 2.0, 16), _INK, Vector2(3.0, 3.0))
			_add_poly(dot, _circle_points(size + 2.0, 16), Color(0.0, 0.0, 0.0, 1.0))
			_add_poly(dot, _circle_points(size, 16), Color(color, 1.0))
		_LOOK_RETRO:
			_add_poly(dot, _square_points(size + 2.0), colors.dark)
			_add_poly(dot, _square_points(size), color)
		_:
			_add_poly(dot, _circle_points(size, 16), color)

# 加一條線
func _add_line(parent: Node2D, points: PackedVector2Array, width: float, color: Color, closed: bool = false, offset: Vector2 = Vector2.ZERO) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.closed = closed
	line.points = points
	line.position = offset
	parent.add_child(line)
	return line

# 加一塊填滿的形狀
func _add_poly(parent: Node2D, points: PackedVector2Array, color: Color, offset: Vector2 = Vector2.ZERO) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.position = offset
	parent.add_child(poly)
	return poly

# 正方形的四個角（size 是中心到邊的距離）
func _square_points(size: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-size, -size), Vector2(size, -size), Vector2(size, size), Vector2(-size, size)])

# 像素風的圓：圓周上的點對齊格子，相鄰兩點之間補一個轉角，變成方格鋸齒
func _pixel_circle(radius: float, grid: float) -> PackedVector2Array:
	var snapped_points := PackedVector2Array()
	for point in _circle_points(radius, _RANGE_POINTS):
		var snapped_point := point.snapped(Vector2(grid, grid))
		if snapped_points.is_empty() or snapped_points[snapped_points.size() - 1] != snapped_point:
			snapped_points.append(snapped_point)
	var stairs := PackedVector2Array()
	for i in snapped_points.size():
		var a := snapped_points[i]
		var b := snapped_points[(i + 1) % snapped_points.size()]
		stairs.append(a)
		if a.x != b.x and a.y != b.y:
			stairs.append(Vector2(b.x, a.y))
	return stairs

# 自訂配色的顏色透明度拉到 0 會完全看不到，提醒學員（不然會以為壞掉）
func _warn_invisible_colors() -> void:
	if palette != _PALETTE_CUSTOM:
		return
	var names := {"center_color": "中心點", "range_color": "範圍圈", "band_color": "拉線"}
	for field in names:
		if (get(field) as Color).a <= 0.01:
			var message: String = "[彈弓] %s 的顏色（%s）透明度是 0，畫出來會完全看不到；點色塊把透明度（A）拉高" % [names[field], field]
			push_warning(message)
			print(message)

# 算出一圈圓周上的點
func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		points.append(Vector2.RIGHT.rotated(TAU * i / count) * radius)
	return points
