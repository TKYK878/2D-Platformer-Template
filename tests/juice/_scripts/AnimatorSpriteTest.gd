extends Node2D

# 手動驗證用：Juice_Animator 用 AnimatedSprite2D（U183）。八段動畫都有（Foxy）。
# T：播「特殊」（代替學員把訊號連到 play_custom()）　K：直接死掉　0：Juice 總開關

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 站著：待機（狐狸呼吸）；左右走：跑步，往左走時臉朝左")
	print("[測試] 跳：往上是跳起那一格、往下是落下那一格，落地回到待機或跑步")
	print("[測試] F（近戰）、G（遠程）：播一次攻擊（翻滾）再回到原本的狀態；冷卻中按了不播")
	print("[測試] 走去碰右邊的尖刺：播受傷；T：播特殊（勝利姿勢）約 1 秒再回來")
	print("[測試] K：播死亡（頭暈）停在最後一格，重生後回到待機")
	print("[測試] 0（Juice 總開關關掉）：停在待機、不翻面；再按 0 恢復")
	print("[測試] 編輯器：Juice_Animator 沒有黃色驚嘆號；Inspector 有 follow_facing，沒有觸發時機")

# T：播特殊；K：死掉
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_T:
			$Player/Juice/Juice_Animator.play_custom()
			print("[測試] T：play_custom()")
		KEY_K:
			$Player.kill()
			print("[測試] K：kill()")
