extends Node2D

# 手動驗證用：標題流程測試的關卡（TitleFlowTest 按「開始遊戲」換過來）。
# 開場檢查上一輪的東西有沒有歸零：金幣、遊玩時間、死亡次數、暫停、重生記憶

# 等一幀（場景裡的東西都準備好）再檢查開場的數值
func _ready() -> void:
	print("[測試] ----- 進到關卡 -----")
	print("[測試] 撿金幣（+5）、碰尖刺死一次，再走到右邊終點；過關畫面按「回標題」。也可以按 Esc，用暫停選單的「回標題」")
	await get_tree().process_frame
	_check("金幣從 0 開始（現在 %d）" % Stats.get_value("金幣"), Stats.get_value("金幣") == 0)
	_check("血量是滿的（現在 %d／%d）" % [Stats.get_value(Stats.HEALTH_KIND), Stats.get_max_value(Stats.HEALTH_KIND)],
		Stats.get_value(Stats.HEALTH_KIND) == Stats.get_max_value(Stats.HEALTH_KIND))
	_check("遊玩時間從 0 開始（現在 %.2f 秒）" % HudData.get_value(HudData.PLAY_TIME), HudData.get_value(HudData.PLAY_TIME) < 0.5)
	_check("死亡次數從 0 開始（現在 %d）" % int(HudData.get_value(HudData.DEATHS)), HudData.get_value(HudData.DEATHS) == 0.0)
	_check("沒有暫停", not get_tree().paused)
	_check("沒有記著上一輪的重生位置", not RespawnMemory.has_respawn_point())
	_check("在關卡裡「回標題」用得到", PauseMenu.can_go_to_title())

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
