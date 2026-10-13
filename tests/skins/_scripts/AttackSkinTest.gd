extends Node2D

# 手動驗證用：Ability_Ranged／EnemyShooter 的 bullet_texture、Ability_Melee 的 slash_texture（U181）。
# 圖是 AI_Placeholder 的暫代圖：箭（朝右）、火球、月牙刀光。

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] G：射出一支箭（不是黃色小方塊），往左射時箭頭朝左")
	print("[測試] H：射出有重力的箭，飛成拋物線時箭頭一路朝著飛的方向（往上飛朝斜上、掉下來朝斜下）")
	print("[測試] F：揮出白色月牙刀光（不是黃色方塊），往左揮時刀光跟著翻；左邊兩塊可破壞方塊用來試打")
	print("[測試] 右邊高台：Enemy1 每 2 秒丟一顆有重力的火球，飛行時跟著方向轉；Enemy2 沒放 bullet_texture，照舊是黃色小方塊")
	print("[測試] 編輯器：Ability_Ranged、Ability_Melee、EnemyShooter（「子彈」組）各多一個圖片欄位，空白不會有黃色驚嘆號")
