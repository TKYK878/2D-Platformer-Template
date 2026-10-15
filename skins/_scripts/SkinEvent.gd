@tool
extends Node

# 零件發生事件時播一段動畫：拖到零件的 SkinAnimated 底下，選「什麼時候」和「播哪段」就好，不用打字、不用連線。
# 例如彈射台「彈出時」播「壓下」、傳送門「傳送時」播「閃光」；播完回到原本的動畫（平常或啟動）。
# 兩個下拉都是自動列出來的：什麼時候＝這個零件有的事件，播哪段＝上面 SkinAnimated 的 Sprite Frames 裡做好的動畫。
# 可以放好幾個，各自聽不同的事件。

## 什麼時候播：零件發生這件事的時候（自動列出這個零件有的事件）
@export var when: String = "":
	set(value):
		when = value
		update_configuration_warnings()
## 播哪一段動畫（自動列出上面 SkinAnimated 做好的動畫），播完回到原本的動畫；勾了循環也只播一輪
@export var animation: String = "":
	set(value):
		animation = value
		update_configuration_warnings()

# 編輯器裡每隔幾秒重新整理下拉選項與黃色驚嘆號（學員一邊改 Sprite Frames，選項一邊更新）
const _REFRESH_SECONDS := 1.0

var _refresh_timer := 0.0
var _last_options := ""  # 上次的下拉選項，有變才重新整理 Inspector（不然會打斷學員正在選的下拉）

# 編輯器裡持續更新選項；遊戲中檢查有沒有放在 SkinAnimated 底下
func _ready() -> void:
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		_fill_defaults()
	elif not _skin_ok():
		_warn("要放在 SkinAnimated 底下才會播動畫（靜態的 Skin 沒有動畫可以播）")

# 編輯器裡每隔一段時間重新整理下拉選項與黃色驚嘆號
func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < _REFRESH_SECONDS:
		return
	_refresh_timer = 0.0
	var options := ",".join(_event_names()) + "|" + ",".join(_anim_names())
	if options != _last_options:
		_last_options = options
		_fill_defaults()
		notify_property_list_changed()
	update_configuration_warnings()

# 被拖到別的地方時重新整理選項與黃色驚嘆號
func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED:
		_last_options = ""
		update_configuration_warnings()

# 兩個欄位都是下拉：選項依零件與 Sprite Frames 自動產生
func _validate_property(property: Dictionary) -> void:
	if property.name == "when":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(_event_names())
	elif property.name == "animation":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(_anim_names())

# 還沒選的欄位自動選第一個能用的（不打字也能用）；「播哪段」優先選平常、啟動、走路以外的動畫
func _fill_defaults() -> void:
	var events := _event_names()
	if when == "" and not events.is_empty():
		when = events[0]
	var anims := _anim_names()
	if animation == "" and not anims.is_empty():
		animation = anims[0]
		var main: Array = get_parent().main_animations() if _skin_ok() else []
		for n in anims:
			if n not in main:
				animation = n
				break

# 上面是不是 SkinAnimated
func _skin_ok() -> bool:
	return get_parent() != null and get_parent().has_method("play_event")

# 這個零件有哪些事件（中文 → 訊號名稱）
func _events() -> Dictionary:
	if not _skin_ok():
		return {}
	return SkinLink.event_signals(get_parent().skin_host())

# 「什麼時候」下拉的選項
func _event_names() -> Array:
	return _events().keys()

# 「播哪段」下拉的選項：上面 SkinAnimated 做好的動畫名稱
func _anim_names() -> Array:
	if not _skin_ok() or get_parent().sprite_frames == null:
		return []
	var names: Array = []
	for n in get_parent().sprite_frames.get_animation_names():
		names.append(String(n))
	return names

# 黃色驚嘆號：放錯地方、零件沒有事件、選的事件或動畫不存在
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var problem := _problem()
	if problem != "":
		warnings.append(problem)
	return warnings

# 設定有什麼問題，沒問題回傳空字串（編輯器黃色驚嘆號與執行時警告共用）
func _problem() -> String:
	if not _skin_ok():
		return "要放在 SkinAnimated 底下才會播動畫（靜態的 Skin 沒有動畫可以播）"
	var events := _event_names()
	if events.is_empty():
		return "這個零件沒有可以播動畫的事件（零件會馬上消失的事件，例如道具被撿走，也不算），這個可以刪掉"
	if when not in events:
		return "「什麼時候」選的「%s」這個零件沒有，請重新選；這個零件有的：%s" % [when, NameCheck.list_text(events)]
	var anims := _anim_names()
	if animation in anims:
		return ""
	var message := "上面的 SkinAnimated 沒有「%s」動畫，請在「播哪段」重新選；現在有的：%s" % [animation, NameCheck.list_text(anims)]
	var similar := NameCheck.find_similar(animation, anims)
	if similar != "":
		message += "。是不是要選「%s」？" % similar
	return message

# SkinAnimated 開場時呼叫：去聽零件的事件，發生時播動畫；設定有問題就印中文警告、不聽
func skin_event_setup(host: Node, skin: Node) -> void:
	var problem := _problem()
	if problem != "":
		_warn(problem)
		return
	var signal_name: String = _events()[when]
	var arg_count := 0
	for info in host.get_signal_list():
		if info.name == signal_name:
			arg_count = info.args.size()
			break
	var callback: Callable = skin.play_event.bind(animation)
	host.connect(signal_name, callback.unbind(arg_count) if arg_count > 0 else callback)

# 印中文警告到輸出面板
func _warn(message: String) -> void:
	push_warning("[皮的事件] %s：%s" % [name, message])
	printerr("⚠ [皮的事件] %s：%s" % [name, message])
