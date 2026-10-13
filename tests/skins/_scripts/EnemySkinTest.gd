extends Node2D

# 手動驗證用：敵人套上皮（U180）。五層平台，敵人在各自的平台上來回走（走到邊緣轉身）。
# H：打所有敵人一下（血量 3，第 3 下死掉）　Y：所有敵人重生復活

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 第 1 層 Enemy1（SkinAnimated：走路／受傷／死亡）：邊跑邊播走路動畫，轉身時跟著翻面（臉朝走的方向）")
	print("[測試] 第 2 層 Enemy2（Skin 靜態圖）：轉身時跟著翻面")
	print("[測試] 第 3 層 Enemy3（朝左畫的圖，勾了 Flip H）：臉朝走的方向，跟第 1 層一樣")
	print("[測試] 第 4 層 Enemy4（朝左畫的圖，沒勾 Flip H）：倒著走（臉朝後面）——這是故意的，示範為什麼要勾 Flip H")
	print("[測試] 第 5 層 Enemy5 的動畫名稱打成「走」：編輯器黃色驚嘆號建議改成「走路」，執行時顯示色塊＋輸出面板中文警告；Enemy6 沒有皮")
	print("[測試] H：Enemy1 播受傷動畫後回到走路；第 3 下 Enemy1 播完頭暈（死亡）動畫才消失，其他敵人立刻消失")
	print("[測試] Y：全部復活回到原位、面朝右，Enemy1 回到走路動畫")

# H：打所有敵人一下；Y：全部重生
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_H:
			for enemy in get_tree().get_nodes_in_group("enemy"):
				enemy.take_hit(1, Vector2.ZERO, self)
			print("[測試] H：打了所有敵人一下")
		KEY_Y:
			for child in get_children():
				if String(child.name).begins_with("Enemy"):
					child.reset()
			print("[測試] Y：全部重生")
