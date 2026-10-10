extends Node

# 手動驗證用：HudData 顯示來源。不需要角色，用按鍵假造事件，每秒印一次目前的值。
# D 假裝死一次、C 金幣 +1、H 血量 -1、U 公開一個自訂來源、L 認領／放掉金幣、R 這一輪重來、Esc 暫停

var _claimer: Node = null
var _custom_value: float = 0.0

# 印出操作說明，接上來源變動，每秒印一次
func _ready() -> void:
	HudData.source_changed.connect(_on_source_changed)
	print("[測試] 每秒印一次：遊玩時間、死亡次數、金幣、血量")
	print("[測試] ① 遊玩時間每秒加 1；按 Esc 開暫停選單等幾秒再關掉，遊玩時間不會把暫停的時間算進去")
	print("[測試] ② 按 D：死亡次數 +1；按 C：金幣 +1；按 H：血量 -1（Stats 的數值自動變成來源，上限也跟著）")
	print("[測試] ③ 按 U：公開「測試來源」（上限 10），值每按一次 +1，來源清單裡多一個名字")
	print("[測試] ④ 按 L：金幣被認領／放掉，is_claimed 跟著變 true／false")
	print("[測試] ⑤ 按 R：遊玩時間、死亡次數歸零，金幣、血量不變")
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
		KEY_D:
			Events.player_died.emit()
		KEY_C:
			Stats.add("金幣", 1)
		KEY_H:
			Stats.add(Stats.HEALTH_KIND, -1)
		KEY_U:
			_custom_value += 1.0
			HudData.publish("測試來源", _custom_value, 10.0)
			print("[測試] 來源清單：%s" % [HudData.get_source_names()])
		KEY_L:
			if _claimer == null:
				_claimer = Node.new()
				add_child(_claimer)
				HudData.claim("金幣", _claimer)
			else:
				_claimer.queue_free()
				_claimer = null
				await get_tree().process_frame
			print("[測試] 金幣被認領了嗎：%s" % HudData.is_claimed("金幣"))
		KEY_R:
			HudData.reset_run()
			print("[測試] 這一輪重來")

# 每秒印一次目前的值
func _print_values() -> void:
	print("[測試] 遊玩時間 %.1f 秒｜死亡次數 %d｜金幣 %d｜血量 %d / %d" % [
		HudData.get_value(HudData.PLAY_TIME), int(HudData.get_value(HudData.DEATHS)),
		int(HudData.get_value("金幣")), int(HudData.get_value(Stats.HEALTH_KIND)),
		int(HudData.get_max_value(Stats.HEALTH_KIND))])

# 來源變動時印出來（遊玩時間每幀都變，不印）
func _on_source_changed(source_name: String) -> void:
	if source_name == HudData.PLAY_TIME:
		return
	print("[測試] 來源變動：%s → %s（上限 %s）" % [source_name, HudData.get_value(source_name), HudData.get_max_value(source_name)])
