extends Node2D

# 手動驗證用：體力、存活倒數、脫殼次數、時間軸公開到 HudData，預設 UI 被認領時讓位。
# 1／2／3／4 假裝學員的 HUD 認領（再按一次放掉）體力／存活倒數／脫殼次數／時間軸；K 拔掉體力卡

const _SOURCES := [HudData.STAMINA, HudData.SURVIVAL, HudData.MOLT, HudData.TIMELINE]

var _claimers: Dictionary = {}   # 來源名稱 -> 假裝認領的節點

# 印出操作說明，每秒印一次四個來源
func _ready() -> void:
	print("[測試] 畫面上有預設 UI：左下體力條、右上存活倒數、右上「殼：…（剩 3 次）」、右上時間軸秒數")
	print("[測試] ① 每秒印一次四個來源的值：左右走體力會變、存活倒數往下數、時間軸往上數；按 C 脫殼，脫殼次數 3 → 2 → 1 → 0")
	print("[測試] ② 按 1／2／3／4：對應的預設 UI 藏起來（學員的 HUD 認領了），再按一次又出現")
	print("[測試] ③ 按 K：拔掉體力卡，左下體力條消失，「體力」從來源清單裡不見")
	print("[測試] ④ 右上角三行（存活倒數、殼、時間軸）靠右上下排開，不會疊在一起；拔掉體力卡、認領讓位時其他行自動補位")
	print("[測試] （時間軸事件「沒連線」的警告是正常的，事件只是湊數用）")
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_print_values)
	add_child(timer)

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_toggle_claim(_SOURCES[event.physical_keycode - KEY_1])
		KEY_K:
			var card := get_node_or_null("Player/Mechanics/Mechanic_Stamina")
			if card != null:
				card.queue_free()
				await get_tree().process_frame
				print("[測試] 拔掉體力卡，來源清單：%s" % [HudData.get_source_names()])

# 認領或放掉一個來源
func _toggle_claim(source_name: String) -> void:
	if _claimers.has(source_name):
		_claimers[source_name].queue_free()
		_claimers.erase(source_name)
		await get_tree().process_frame
	else:
		var claimer := Node.new()
		add_child(claimer)
		HudData.claim(source_name, claimer)
		_claimers[source_name] = claimer
	print("[測試] %s 被認領了嗎：%s" % [source_name, HudData.is_claimed(source_name)])

# 每秒印一次四個來源的值與上限
func _print_values() -> void:
	var parts: Array = []
	for source_name in _SOURCES:
		if HudData.has_source(source_name):
			parts.append("%s %.1f / %.1f" % [source_name, HudData.get_value(source_name), HudData.get_max_value(source_name)])
		else:
			parts.append("%s（沒有）" % source_name)
	print("[測試] " + "｜".join(parts))
