extends Node

# 手動驗證用：標題 → 開始遊戲 → 關卡（TitleFlowLevel）→ 過關畫面「回標題」→ 標題，整條流程走一次。
# 「回標題」本來回專案的主場景，這裡改成回這個測試場景（PauseMenu.title_scene_override），不用改主場景。
# 外觀用 TitleScreenTemplate_Side（左文右圖、復古綠）

static var _visits: int = 0

# 設定回標題回到這裡，印出操作說明與現在的數值（每次回到標題，上一關的東西都要歸零）
func _ready() -> void:
	PauseMenu.title_scene_override = get_tree().current_scene.scene_file_path
	_visits += 1
	print("[測試] ===== 第 %d 次來到標題畫面 =====" % _visits)
	if _visits == 1:
		print("[測試] ① 按「開始遊戲」→ 換到測試關卡，輸出面板會印出關卡開場的數值檢查")
		print("[測試] ② 在關卡裡撿金幣、碰尖刺死一次，再走到右邊終點 → 過關畫面有「回標題」按鈕，按下去回到這裡")
		print("[測試] ③ 再開始一次：金幣、遊玩時間、死亡次數都從 0 開始；也可以在關卡裡按 Esc，暫停選單裡也有「回標題」")
	_check("沒有暫停", not get_tree().paused)
	_check("遊戲速度正常", is_equal_approx(Engine.time_scale, 1.0))
	_check("暫停選單沒開著", not PauseMenu.is_open())
	_check("在標題畫面上「回標題」用不到", not PauseMenu.can_go_to_title())

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
