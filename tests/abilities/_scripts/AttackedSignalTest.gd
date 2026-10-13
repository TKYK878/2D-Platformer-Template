extends Node2D

# 手動驗證用：Ability_Melee／Ability_Ranged 的 attacked 訊號（U182）。兩個能力的冷卻都設成 1 秒。

# 接上兩個能力的 attacked，印出操作說明與預期結果
func _ready() -> void:
	for ability in $Player/Abilities.get_children():
		ability.attacked.connect(func(): print("[測試] 收到 %s 的 attacked" % ability.name))
	print("[測試] F（近戰）：每揮一下印一行「收到 Ability_Melee 的 attacked」")
	print("[測試] G（遠程）：每射一發印一行「收到 Ability_Ranged 的 attacked」")
	print("[測試] 連按（1 秒內按好幾下）：冷卻中沒揮出去、沒射出去的那幾下不會印")
	print("[測試] 編輯器：選 Ability_Melee 或 Ability_Ranged，「節點」面板的訊號清單裡有 attacked，滑過去有中文說明")
