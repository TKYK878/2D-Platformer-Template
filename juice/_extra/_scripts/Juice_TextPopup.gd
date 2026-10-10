@tool
extends JuiceBase

# 跳字：數值一變（撿到金幣、扣血…），玩家頭上就跳出「+1 金幣」「-1 血量」，往上飄、淡掉。
# 拖進 Player → Juice 底下就一直作用（持續型），不用選觸發時機。
# 很短的時間內同一種數值連續變化（一次撿一串金幣）會合併成一個字，例如「+3 金幣」。
# 種類選「自訂」時可以自己打數值種類名稱，名稱檢查走共用工具 NameCheck。

## 哪些數值變化要跳字：全部、只有血量，或選「自訂」自己打數值種類名稱
@export_enum("全部數值", "只有血量", "自訂") var kind: int = 0:
	set(value):
		kind = value
		notify_property_list_changed()
		update_configuration_warnings()
## 自訂的數值種類名稱，例如「星星」。要跟 ValueSettings、道具用的名稱打一樣的字；
## 頭尾空白、全形字會自動整理，打錯字時場景樹會出現黃色驚嘆號
@export var custom_kind: String = "":
	set(value):
		custom_kind = value
		update_configuration_warnings()
## 字的顏色：「加綠減紅」= 變多是綠色、變少是紅色
@export_enum("加綠減紅", "白", "黃") var color: int = 0
## 字的大小
@export_range(8, 32) var size: int = 11
## 字飄多久才消失（秒）
@export_range(0.3, 2.0) var duration: float = 0.8

const _KIND_ALL := 0
# 編輯器裡自動載入的 Stats 不存在，血量的名稱直接從它的腳本拿
const _StatsScript := preload("res://autoload/Stats.gd")
const _KIND_HEALTH := 1
const _KIND_CUSTOM := 2
const _UP_COLOR := Color(0.4, 1.0, 0.45)
const _DOWN_COLOR := Color(1.0, 0.35, 0.3)
const _COLORS := [Color.WHITE, Color(1.0, 0.9, 0.3)]
# 字出現在頭頂再往上多少、總共往上飄多遠（像素）
const _HEAD_GAP := 6.0
const _RISE := 24.0
# 同一種數值在這段時間內又變了，就合併到同一個字（秒）
const _MERGE_TIME := 0.3
# 畫面上最多幾個字，太多就先刪最舊的
const _MAX_POPUPS := 8
const _WARNING_REFRESH_SECONDS := 1.0

var _popups: Array = []   # 還在場上的字：{ node, kind, amount, born, stack（往上疊第幾行）}，舊的在前面
var _warning_timer: float = 0.0

# 持續型：拖進來就一直作用
func _is_continuous() -> bool:
	return true

# 聽數值變化；選了自訂就檢查名稱
func _on_setup() -> void:
	_listen(Stats.value_changed, _on_value_changed)
	if kind == _KIND_CUSTOM:
		_check_custom_kind.call_deferred()

# 數值變了：符合種類就跳字（玩家死掉到重生前的變化不跳，例如重生補血、退回金幣）
func _on_value_changed(changed_kind: String, old_value: int, new_value: int) -> void:
	if not _is_juice_on() or not is_instance_valid(player) or player.is_dead():
		return
	if not _wants(changed_kind):
		return
	_show(changed_kind, new_value - old_value)

# 這個數值種類要不要跳字
func _wants(changed_kind: String) -> bool:
	match kind:
		_KIND_HEALTH: return changed_kind == _StatsScript.HEALTH_KIND
		_KIND_CUSTOM: return changed_kind == NameCheck.clean(custom_kind)
	return true

# 跳出一個字；同一種數值剛跳過的字還很新的話，改成合併到那個字上
func _show(changed_kind: String, amount: int) -> void:
	_popups = _popups.filter(func(p): return is_instance_valid(p.node))
	var now := Time.get_ticks_msec() / 1000.0
	for p in _popups:
		if p.kind == changed_kind and now - p.born < _MERGE_TIME and signi(p.amount) == signi(amount):
			p.amount += amount
			p.born = now
			_restart(p)
			return
	var level := get_tree().current_scene
	if level == null:
		return
	var node := Node2D.new()
	node.z_index = 100
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(label)
	level.add_child(node)
	# 同時有別的字剛跳出來（例如扣血又撿金幣），往上疊一行，不要擠在同一個位置
	var stack := 0
	for p in _popups:
		if now - p.born < duration * 0.5:
			stack = maxi(stack, p.stack + 1)
	var popup := { "node": node, "kind": changed_kind, "amount": amount, "born": now, "stack": stack }
	_popups.append(popup)
	_restart(popup)
	while _popups.size() > _MAX_POPUPS:
		_popups.pop_front().node.queue_free()

# 更新字的內容（數值名稱用 ValueSettings 的 display_name），從頭頂重新開始往上飄、淡掉
func _restart(popup: Dictionary) -> void:
	var node: Node2D = popup.node
	var label: Label = node.get_child(0)
	label.text = "%+d %s" % [popup.amount, Stats.get_display_name(popup.kind)]
	var tint: Color
	if color == 0:
		tint = _UP_COLOR if popup.amount > 0 else _DOWN_COLOR
	else:
		tint = _COLORS[color - 1]
	label.add_theme_color_override("font_color", tint)
	label.reset_size()
	label.position = Vector2(-label.size.x * 0.5, -label.size.y)
	node.global_position = _head_position() - Vector2(0.0, (size + 2) * popup.stack)
	node.modulate.a = 1.0
	if node.has_meta("tween"):
		var old: Tween = node.get_meta("tween")
		if old:
			old.kill()
	var tween := node.create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(node, "position:y", node.position.y - _RISE, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.chain().tween_callback(node.queue_free)
	node.set_meta("tween", tween)

# 玩家頭頂的位置（畫面上方那一側，重力翻轉後也一樣在畫面上方）
func _head_position() -> Vector2:
	var feet: Vector2 = player.get_feet_position()
	var center: Vector2 = player.global_position
	var top := minf(feet.y, 2.0 * center.y - feet.y)
	return Vector2(center.x, top - _HEAD_GAP)

# 重生時清掉還在飄的字
func _on_reset() -> void:
	for p in _popups:
		if is_instance_valid(p.node):
			p.node.queue_free()
	_popups.clear()

# 只有選「自訂」時才顯示名稱欄位
func _validate_property(property: Dictionary) -> void:
	super(property)
	if property.name == "custom_kind" and kind != _KIND_CUSTOM:
		property.usage = PROPERTY_USAGE_NONE

# 編輯器場景樹的黃色驚嘆號：選了「自訂」但名稱空白，或場景裡找不到這個數值種類
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if kind != _KIND_CUSTOM or not is_inside_tree():
		return warnings
	var root := get_tree().edited_scene_root
	if root == null:
		return warnings
	var message := _custom_kind_problem(_scene_kinds(root))
	if message != "":
		warnings.append(message)
	return warnings

# 執行時檢查自訂名稱，有問題印中文警告
func _check_custom_kind() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var kinds := _scene_kinds(root)
	for k in Stats.get_known_kinds():
		if k not in kinds:
			kinds.append(k)
	var message := _custom_kind_problem(kinds)
	if message != "":
		message = "[跳字] %s：%s" % [name, message]
		push_warning(message)
		print(message)

# 回傳自訂名稱的問題說明（空白、找不到、疑似打錯字），沒問題回傳空字串
func _custom_kind_problem(kinds: Array) -> String:
	var clean_kind := NameCheck.clean(custom_kind)
	if clean_kind == "":
		return "種類選了「自訂」，但 custom_kind 是空的，請打上數值種類名稱（例如「星星」），不然不會跳任何字。"
	if clean_kind in kinds:
		return ""
	var similar := NameCheck.find_similar(clean_kind, kinds)
	var hint := "是不是想打「%s」？" % similar if similar != "" else ""
	return "場景裡找不到數值種類「%s」，%s現有的數值種類：%s" % [clean_kind, hint, NameCheck.list_text(kinds)]

# 場景裡用到的數值種類名稱（ValueSettings、道具、門…），再加上內建的血量
func _scene_kinds(root: Node) -> Array:
	var kinds := NameCheck.collect_value_kinds(root, self)
	if _StatsScript.HEALTH_KIND not in kinds:
		kinds.append(_StatsScript.HEALTH_KIND)
	return kinds

# 編輯器裡每隔一段時間重新檢查自訂名稱，學員改了別的零件之後黃色警告會跟著更新
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_warning_timer += delta
	if _warning_timer >= _WARNING_REFRESH_SECONDS:
		_warning_timer = 0.0
		update_configuration_warnings()
