extends Node2D

# 手動驗證用：Ability_Ranged／EnemyShooter 的 bullet_texture、Ability_Melee 的 slash_texture（U181）。
# 暫代圖在 U202 刪掉了，欄位現在都是空白（照舊顯示色塊）；要測換圖時自己把圖拖進欄位。

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 欄位都是空白：G、H 射出黃色小方塊，F 揮出色塊，空白不會有黃色驚嘆號、不會警告")
	print("[測試] 要測換圖：把朝右畫的圖拖進 Player → Abilities 的 bullet_texture／slash_texture、Enemy1 的 EnemyShooter 的 bullet_texture")
	print("[測試] 　G：射出的圖往左射時跟著朝左；H：有重力的子彈飛成拋物線時一路朝著飛的方向")
	print("[測試] 　F：揮擊的圖往左揮時跟著翻；左邊兩塊可破壞方塊用來試打")
	print("[測試] 　右邊高台：Enemy1 每 2 秒丟一顆有重力的子彈，飛行時跟著方向轉；Enemy2 照舊是黃色小方塊")
	print("[測試] 編輯器：Ability_Ranged、Ability_Melee、EnemyShooter（「子彈」組）各有一個圖片欄位")
