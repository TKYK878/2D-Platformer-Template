extends Node2D

# 手動驗證用：SkinBackground 的 cover_area（整個關卡／所在的房間／自己拉範圍，U216）。
# Background_Level 藍色蓋整個關卡；Background_Room2 粉紅色放在 Room2 底下、只蓋 Room2；Background_Custom 黃色自己拉 8×4 格。

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 編輯器：左邊房間是藍色，右邊房間（Room2）整間是粉紅色；左上方有一塊 8×4 格的黃色，外面有黃色虛線框")
	print("[測試] 　點 Background_Custom：Inspector 有 cover_area（自己拉範圍）和 width_in_tiles／height_in_tiles；拖拉桿黃色那塊跟著變")
	print("[測試] 　把 Background_Custom 的 cover_area 改成「所在的房間」：黃色驚嘆號「背景不在 Room 底下…」，黃色變成蓋整個關卡（改回自己拉範圍）")
	print("[測試] 　把 Background_Room2 拖到 Room1 底下：粉紅色跑到左邊房間；拖回 Room2 底下")
	print("[測試] 　Room2 在場景樹裡排在藍色前面，粉紅色還是蓋在藍色上面（範圍小的自動在上面），三個都沒有黃色驚嘆號")
	print("[測試] 　複製一個 Background_Level（Ctrl+D）：新的那個出現驚嘆號「把前面的背景…整個蓋住了」（刪掉就消失）")
	print("[測試] F6：走到右邊房間，鏡頭切過去看到粉紅色背景；左邊房間是藍色，左上有黃色那塊")
