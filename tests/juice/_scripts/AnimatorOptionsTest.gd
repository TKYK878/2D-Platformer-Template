extends Node2D

# 手動驗證用：Juice_Animator 的下拉選動畫與新的選項（U214）。動畫都用英文名字（idle、run、jump、fall、hurt、die、attack、special）。
# 一次型：落地播 special（勝利姿勢）、轉向播 hurt。
# I：切換 can_interrupt　R：切換 run_speed_follow　M：min_run_speed 10 ↔ 150　L：落地動畫 special ↔（沒有）

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 編輯器：點 Juice_Animator，「動畫」群組每格都是下拉：（自動）、（沒有）、idle、run…；八格都是（自動），沒有黃色驚嘆號")
	print("[測試] 　「一次型動畫」群組：land_animation 是 special、turn_animation 是 hurt，其他是（沒有）")
	print("[測試] 　在 SpriteFrames 把 special 改名成 win：land_animation 出現黃色驚嘆號「選的「special」不見了」（改回來就消失）")
	print("[測試] F6：英文名字的動畫照常播（站著 idle、走 run、跳 jump／fall）")
	print("[測試] 　跳起來落地：播一次 special 再回來；左右轉向：播一次 hurt")
	print("[測試] 　F 攻擊時馬上轉向：can_interrupt 勾著（預設）會換成 hurt；按 I 取消勾選再試，攻擊會播完")
	print("[測試] R：run_speed_follow 打開，慢慢起跑時 run 播得慢、全速時正常")
	print("[測試] M：min_run_speed 改 150，起跑一小段還是 idle，跑快了才播 run")
	print("[測試] L：落地不播動畫 ↔ 播 special")

# 除錯按鍵：切換選項，改完重新決定每個狀態播哪段
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var animator = $Player/Juice/Juice_Animator
	match event.physical_keycode:
		KEY_I:
			animator.can_interrupt = not animator.can_interrupt
			print("[測試] can_interrupt：%s" % animator.can_interrupt)
		KEY_R:
			animator.run_speed_follow = not animator.run_speed_follow
			print("[測試] run_speed_follow：%s" % animator.run_speed_follow)
		KEY_M:
			animator.min_run_speed = 150.0 if animator.min_run_speed < 100.0 else 10.0
			print("[測試] min_run_speed：%s" % animator.min_run_speed)
		KEY_L:
			animator.land_animation = animator.NONE if animator.land_animation == "special" else "special"
			animator._resolve_all()
			print("[測試] land_animation：%s" % animator.land_animation)
