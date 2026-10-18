extends Node2D

# 手動驗證用：岩漿用 width_tiles／height_tiles 拉大小，皮的重複鋪滿／拉伸蓋滿跟著對齊（U221）。

@onready var _player: CharacterBody2D = $Player

# 印出操作說明與預期結果
func _ready() -> void:
	_player.hurt.connect(func(): print("[測試] 玩家受傷了（站在岩漿上每秒扣 1 點血）"))
	print("[測試] 由左到右：")
	print("[測試] 　Lava_Tile（6×1，重複鋪滿）：同一張 16×16 的圖重複 6 次，每格都一樣清楚，不會被拉長")
	print("[測試] 　Lava_Stretch（3×2，拉伸蓋滿）：一張圖拉大蓋滿整塊")
	print("[測試] 　Lava_NoSkin（2×3，沒有皮）：橘色色塊整塊變大")
	print("[測試] 　Lava_Scaled（scale 改成 2）：場景樹上有黃色驚嘆號、輸出面板有「scale 被改過」的中文警告")
	print("[測試] F6：走過每一塊岩漿，整塊範圍都站得住、都會扣血；邊緣以外不扣血")
	print("[測試] 編輯器：點 Lava_Tile 拉 width_tiles／height_tiles，色塊、碰撞框、皮的圖即時跟著變（試完 Ctrl+Z 還原）")
