extends Node

# 手動驗證用（U223）：標題畫面的 music 欄位放了一段測試旋律（tests/ui/_audio/TestTune.wav）。
# 開場淡入、一直循環；按「開始遊戲」換到 TitleFlowLevel 時淡出；回標題後又重新淡入。
# 「回標題」本來回專案的主場景，這裡改成回這個測試場景（PauseMenu.title_scene_override），不用改主場景。

static var _visits: int = 0

# 設定回標題回到這裡，印出操作說明，檢查標題音樂有沒有開始播、走不走 BGM 匯流排
func _ready() -> void:
	PauseMenu.title_scene_override = get_tree().current_scene.scene_file_path
	_visits += 1
	print("[測試] ===== 第 %d 次來到標題畫面 =====" % _visits)
	if _visits == 1:
		print("[測試] ① 聽：音樂從無聲慢慢變大（約 1 秒），旋律播完會自己從頭再播")
		print("[測試] ② 按「開始遊戲」→ 換到測試關卡，音樂在約 1 秒內慢慢變小到聽不到，不是一下子切掉")
		print("[測試] ③ 在關卡裡按 Esc → 暫停選單按「回標題」，回到這裡音樂重新淡入；只會有一份在播，不會疊兩層")
		print("[測試] ④ 在關卡裡把暫停選單的「音樂」拉桿拉到 0，回標題後應該聽不到（標題音樂走 BGM 匯流排）")
		print("[測試] ⑤ 點最上層節點：Inspector 的「標題畫面」群組有 music、music_volume；kind 改成 HUD 的話這兩格會藏起來")
	await get_tree().process_frame
	var player := get_tree().current_scene.get_node_or_null("TitleMusic") as AudioStreamPlayer
	_check("有標題音樂的播放器", player != null)
	if player == null:
		return
	_check("正在播放", player.playing)
	_check("走 BGM 匯流排", player.bus == &"BGM")
	_check("開場是從很小聲開始淡入", player.volume_db < -20.0)
	_check("只有一份標題音樂在播", _count_title_music(get_tree().root) == 1)

# 數場景樹裡有幾個標題音樂播放器（包含換關時交給 PauseMenu 還在淡出的）
func _count_title_music(node: Node) -> int:
	var count := 1 if node.name == "TitleMusic" and (node as AudioStreamPlayer).playing else 0
	for child in node.get_children():
		count += _count_title_music(child)
	return count

# 印出一項檢查的結果
func _check(label: String, ok: bool) -> void:
	print("[測試] %s %s" % ["✓" if ok else "✗", label])
