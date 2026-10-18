extends Node2D

# 手動驗證用：Mechanic_Slingshot 鍵盤完全鎖住，只能用滑鼠拖曳、放開往反方向射出去。

func _ready() -> void:
	Events.mechanic_event.connect(_on_mechanic_event)
	print("[測試] 先試試看方向鍵、空白鍵：角色應該完全沒反應，鍵盤被鎖住了")
	print("[測試] 按住滑鼠左鍵在角色旁邊拖曳，應該看到一條瞄準線；往某個方向拖越遠，線越長")
	print("[測試] 拖曳時按下去的位置有一個黃色圓點（拉的中心點），外面一圈淡白色的圓是最遠能拉到的範圍，")
	print("[測試] 　黃線從中心點拉到滑鼠，拉出圈外黃線就停在圈上；放開後圓點、圓圈、黃線都消失")
	print("[測試] 把 show_drag_center 關掉再跑：只剩白色瞄準線，沒有圓點和圓圈；Inspector 的「中心點外觀」群組也會藏起來")
	print("[測試] 「中心點外觀」：center_style 換沒有圈／只有中心點；line_width、center_size 拉大")
	print("[測試] 　look 一個個換：簡單、虛線、像素復古（方格鋸齒圈、方點）、乾淨極簡（細線、空心點）、可愛圓角（粗圈加影子、點有反光）、")
	print("[測試] 　木牌（雙層框加四顆釘子）、科幻（發光圈、內圈虛線、刻度、菱形點）、漫畫（粗黑框加陰影）、復古遊戲機（雙線圈、方框點）")
	print("[測試] 　palette 換復古綠、糖果…顏色一起換；選「自訂」才出現三個取色器，點色塊換顏色")
	print("[測試] 　關掉 range_follow_drag 才出現 range_size，拉到 300 圈變大，但實際能拉的距離不變；把 icon.svg 拖進 center_texture，中心點變成圖")
	print("[測試] 　把某個顏色的透明度拉到 0 再按 F6：輸出面板出現「透明度是 0」的中文警告")
	print("[測試] 遊戲中改這些欄位，下一次開始拉就會套用")
	print("[測試] 放開滑鼠左鍵：角色應該往拖曳的反方向射出去，拖得越遠射得越用力")
	print("[測試] ground_only 開著：如果放開後角色還在空中，這時候按住左鍵應該沒辦法開始拖曳瞄準")
	print("[測試] 彈弓改走 InputRouter 之後，上面的行為應該跟以前完全一樣")
	print("[測試] 把 Mechanic_Slingshot 的 input_type 改成滑鼠右鍵再跑：右鍵拖曳能發射，左鍵應該沒反應")
	print("[測試] 改成鍵盤按鍵（預設 E）：按住 E 移動滑鼠瞄準，放開 E 發射")

func _on_mechanic_event(card: String, event: String) -> void:
	print("[測試] Events.mechanic_event：%s / %s" % [card, event])
