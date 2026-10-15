extends Node2D

# 手動驗證用：Juice_Animator 用 AnimationPlayer（U183），只改 Sprite2D 的 frame（Foxy 圖集）。
# 角色掛了自動奔跑卡，在兩面牆之間來回跑。跑步動畫叫「跑」（U214 起會自動認出來）；故意放了一個錯：攻擊動畫改了 scale。

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 編輯器：Juice_Animator 有黃色驚嘆號一行：「動畫「攻擊」改了「scale」…」；run_animation 是（自動），會認出「跑」")
	print("[測試] F6：輸出面板有同樣一行中文警告")
	print("[測試] 自動奔跑：撞牆轉向時臉跟著轉，不會倒著跑（自動奔跑卡也會翻，兩邊不會翻兩次）")
	print("[測試] 　跑的時候播「跑」那段動畫")
	print("[測試] 跳：跳起、落下；F：播攻擊（翻滾，圖會忽大忽小，這就是警告說的打架）")
