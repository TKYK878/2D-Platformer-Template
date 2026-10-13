@tool
extends Node2D

# 練習關的題目告示牌：顯示一道練習題，按 F6 執行時自動檢查有沒有照題目設定好，
# 做對了告示牌變綠色寫「完成！」。給 W3_JuicePractice（Juice 題）、W4_SkinPractice（套皮與 UI 題）用，學員不用拖它。

## 這塊告示牌是哪一題
@export_enum("落地震動", "跳躍音效", "金幣星星", "金幣音效", "用力震", "打倒頓幀", "按鈕推近", "自己的音效",
	"W4 終點換圖", "W4 血條右上角", "W4 遊玩時間", "W4 愛心血量", "W4 字型配色", "W4 角色動畫", "W4 敵人動畫", "W4 暫停選單")
var task: int = 0:
	set(value):
		task = value
		_refresh_text()

# [標題, 提示]
const _TASKS := [
	["1. 落地時畫面震一下", "拖 Juice_ScreenShake 到 Player → Juice"],
	["2. 跳的時候有聲音", "拖 Juice_Sound 進去，不用改設定"],
	["3. 撿金幣時噴星星", "Juice_Particles：timing 選撿到東西時、style 選星星"],
	["4. 撿金幣時叮一聲", "再拖一個 Juice_Sound：timing 撿到東西時、sound 金幣"],
	["5. 震得更用力", "點 Juice_ScreenShake，strength 拉到 8 以上"],
	["6. 打倒敵人時畫面停一下", "Juice_HitStop：timing 選打倒敵人時（按 F 攻擊）"],
	["7. 踩按鈕時鏡頭推近", "Juice_CameraZoom timing 選不自動觸發，按鈕的 turned_on 連到它的 play"],
	["8. 撞牆時播自己的音效", "Juice_Sound：timing 撞牆時、sound 自訂，把音檔拖進 custom_sound"],
	["1. 把終點換成自己的圖", "選 Goal，從 skins/ 拖 Skin 進去當子節點，把圖拖進 texture_normal"],
	["2. 血條移到畫面右上角", "ui/templates/HudTemplate 右鍵再製到 _my/，打開把血條拖到右上角，再把 HUD 拖進關卡"],
	["3. HUD 加一個遊玩時間", "在你的 HUD 裡拖一個 HudNumber，source 選遊玩時間"],
	["4. 血量改成愛心圖示", "你的 HUD 裡血條換成 HudIcons，把愛心圖拖進 full_icon"],
	["5. 整套 UI 換字型或配色", "點你的 HUD 最上層，palette 換一個，或把字型檔拖進 font"],
	["6. 角色有待機和跑步動畫", "Visual 底下換成 AnimatedSprite2D 做「待機」「跑步」，拖 Juice_Animator 進 Player → Juice"],
	["7. 敵人換成會動的皮", "選 Enemy，拖 SkinAnimated 進去，做一段好幾格的「走路」動畫"],
	["8. 換成自己的暫停選單", "PauseMenuTemplate 再製到 _my/ 改排版，拖進 UISettings 的 pause_menu_scene"],
]
# 告示牌等這麼久再檢查（秒）：UISettings 接上的畫面、UI 排版都要等一下才到位
const _CHECK_DELAY := 0.3
const _HUD_PARTS := ["HudBar.gd", "HudIcons.gd"]
const _HEALTH := "血量"
const _SOURCE_PLAY_TIME := 1
const _WIDTH := 120.0
const _TODO_COLOR := Color(0.25, 0.2, 0.15, 0.85)
const _DONE_COLOR := Color(0.15, 0.45, 0.2, 0.9)
const _HINT_COLOR := Color(0.85, 0.85, 0.85)

var _panel: PanelContainer = null
var _title: Label = null
var _hint: Label = null
var _status: Label = null
var _done: bool = false

# 組出告示牌；執行時等 Player 幫 Juice 都準備好再檢查
func _ready() -> void:
	_build()
	_refresh_text()
	if Engine.is_editor_hint():
		return
	add_to_group("practice_sign")
	await get_tree().create_timer(_CHECK_DELAY).timeout
	_set_done(_check())

# 回傳這一題有沒有完成
func is_done() -> bool:
	return _done

# 依題目檢查 Player → Juice 的設定
func _check() -> bool:
	var juice := _find_juice_container()
	if juice == null:
		return false
	match task:
		0: return _has(juice, "Juice_ScreenShake", {"timing": 1})
		1: return _has(juice, "Juice_Sound", {"timing": 0})
		2: return _has(juice, "Juice_Particles", {"timing": 10, "style": 2})
		3: return _has(juice, "Juice_Sound", {"timing": 10, "sound": 5})
		4: return _find(juice, "Juice_ScreenShake").any(func(n): return n.strength >= 8.0)
		5: return _has(juice, "Juice_HitStop", {"timing": 9})
		6: return _button_plays_juice()
		7: return _find(juice, "Juice_Sound").any(func(n): return n.timing == 4 and n.sound == 8 and n.custom_sound != null)
		8: return _goal_has_skin()
		9: return _custom_parts(0, _HUD_PARTS).any(func(n): return _is_health(n) and _in_top_right(n))
		10: return _custom_parts(0, ["HudNumber.gd", "HudText.gd"]).any(func(n): return n.source == _SOURCE_PLAY_TIME)
		11: return _custom_parts(0, ["HudIcons.gd"]).any(func(n): return _is_health(n) and n.full_icon != null)
		12: return _custom_roots(-1).any(func(r): return r.palette != 0 or r.font != null)
		13: return not _find(juice, "Juice_Animator").is_empty() and _player_has_anims(["待機", "跑步"])
		14: return _enemy_walks()
		15: return not _custom_roots(1).is_empty()
	return false

# 有沒有終點套上放了圖的皮（Skin 有 texture_normal、或 SkinAnimated 有「平常」）
func _goal_has_skin() -> bool:
	for goal in get_tree().get_nodes_in_group("goal"):
		for child in goal.get_children():
			if _script_file(child) == "Skin.gd" and child.texture_normal != null:
				return true
			if _script_file(child) == "SkinAnimated.gd" and child.sprite_frames != null and child.sprite_frames.has_animation("平常"):
				return true
	return false

# 學員自己的 UI（kind：0 HUD、1 暫停選單、2 過關畫面，-1 全部），用預設範本的不算
func _custom_roots(kind: int) -> Array:
	var roots: Array = []
	for k in ([0, 1, 2] if kind < 0 else [kind]):
		roots.append_array(get_tree().get_nodes_in_group("custom_ui_%d" % k))
	return roots

# 學員自己的 UI 裡、指定種類的顯示零件
func _custom_parts(kind: int, files: Array) -> Array:
	var parts: Array = []
	for root in _custom_roots(kind):
		for n in root.find_children("*", "", true, false):
			if _script_file(n) in files:
				parts.append(n)
	return parts

# 這個顯示零件是不是在顯示血量
func _is_health(part: Node) -> bool:
	return part.source == 0 and NameCheck.clean(part.kind) == _HEALTH

# 這個顯示零件在不在畫面右上角（中心在右半邊、上半邊）
func _in_top_right(part: Control) -> bool:
	var screen := get_viewport().get_visible_rect().size
	var center := part.get_global_rect().get_center()
	return center.x > screen.x / 2.0 and center.y < screen.y / 2.0

# 角色的播放器（Visual 底下的 AnimationPlayer 或 AnimatedSprite2D）有沒有這些動畫
func _player_has_anims(names: Array) -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.visual == null:
		return false
	for n in player.visual.find_children("*", "", true, false):
		if n is AnimationPlayer and names.all(func(a): return n.has_animation(a)):
			return true
		if n is AnimatedSprite2D and n.sprite_frames != null and names.all(func(a): return n.sprite_frames.has_animation(a)):
			return true
	return false

# 有沒有敵人套上會動的皮（SkinAnimated 的「走路」有兩格以上）
func _enemy_walks() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		for child in enemy.get_children():
			if _script_file(child) == "SkinAnimated.gd" and child.sprite_frames != null 					and child.sprite_frames.has_animation("走路") and child.sprite_frames.get_frame_count("走路") > 1:
				return true
	return false

# 節點腳本的檔名（沒有腳本回傳空字串）
func _script_file(node: Node) -> String:
	var node_script: Script = node.get_script()
	return node_script.resource_path.get_file() if node_script != null else ""

# 找出 Player 底下的 Juice 籃子
func _find_juice_container() -> Node:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("Juice")

# 回傳籃子裡開著的、指定種類的 Juice
func _find(juice: Node, kind: String) -> Array:
	return juice.get_children().filter(func(n): return n.get_script() != null \
		and n.get_script().resource_path.get_file() == kind + ".gd" and n.enabled)

# 有沒有一個指定種類的 Juice 每個欄位都跟要求的一樣
func _has(juice: Node, kind: String, wanted: Dictionary) -> bool:
	for n in _find(juice, kind):
		var ok := true
		for key in wanted:
			if n.get(key) != wanted[key]:
				ok = false
		if ok:
			return true
	return false

# 有沒有一個按鈕的 turned_on 連到「不自動觸發」的鏡頭推近的 play
func _button_plays_juice() -> bool:
	for node in get_tree().get_nodes_in_group("signal_source"):
		if not node.has_signal("turned_on"):
			continue
		for conn in node.get_signal_connection_list("turned_on"):
			var target: Object = conn["callable"].get_object()
			if target is JuiceBase and conn["callable"].get_method() == "play" \
					and target.get_script().resource_path.get_file() == "Juice_CameraZoom.gd" and target.timing == JuiceBase.TIMING_MANUAL:
				return true
	return false

# 套用完成狀態：變色、改字；全部告示牌都完成時印恭喜
func _set_done(value: bool) -> void:
	_done = value
	_status.text = "完成！" if _done else "還沒完成"
	_panel.add_theme_stylebox_override("panel", _make_style(_DONE_COLOR if _done else _TODO_COLOR))
	print("[練習] %s：%s" % [_TASKS[task][0], "完成" if _done else "還沒完成"])
	if _done and get_tree().get_nodes_in_group("practice_sign").all(func(s): return s.is_done()):
		print("[練習] 🎉 全部完成！")

# 用程式組出告示牌：底板、標題、提示、狀態
func _build() -> void:
	if _panel != null:
		return
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(_WIDTH, 0)
	_panel.add_theme_stylebox_override("panel", _make_style(_TODO_COLOR))
	add_child(_panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	_panel.add_child(list)
	_title = _make_label(Color.WHITE)
	_hint = _make_label(_HINT_COLOR)
	_status = _make_label(Color(1, 0.85, 0.3))
	_status.text = "按 F6 檢查"
	for label in [_title, _hint, _status]:
		list.add_child(label)

# 把題目文字放上告示牌
func _refresh_text() -> void:
	if _title == null:
		return
	_title.text = _TASKS[task][0]
	_hint.text = _TASKS[task][1]

# 做一個會自動換行的 12 號字
func _make_label(color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.custom_minimum_size = Vector2(_WIDTH - 8, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label

# 告示牌底板的樣式
func _make_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(4)
	return style
