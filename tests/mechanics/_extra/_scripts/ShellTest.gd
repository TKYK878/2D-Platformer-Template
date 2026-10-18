extends Node2D

# 手動驗證用：殼本體 Shell 的物理勾選框、預設外觀、特性組件註冊、碎掉

func _ready() -> void:
	for shell in get_tree().get_nodes_in_group("shell"):
		shell.broken.connect(_on_shell_broken.bind(shell.name))
	print("[測試] 最左邊棕色的是箱子，拿來比較")
	print("[測試] 琥珀色殼（一般）：會掉到地上，走過去推得動，跟箱子一樣；推到最左邊的牆就推不動，殼不會陷進牆裡")
	print("[測試] 玩家右邊的藍色殼是塑膠殼：從側面撞上去，玩家往回彈、殼往前彈出去；殼卡在綠色殼或牆邊時只有玩家被彈回來")
	print("[測試] 藍色殼（不受重力）：一開始飄在空中不會掉，推它會移動、然後慢慢停下")
	print("[測試] 綠色殼（不受重力＋推不動）：固定在空中，走過去會被擋住，跳上去可以站在上面")
	print("[測試] 灰色殼底下有一個特性組件：輸出面板應該有「[殼的特性] Trait 已啟用」")
	print("[測試] 最右邊的殼底下有自己的圖片：只看到白色圖片，沒有預設的方框")
	print("[測試] 場景裡另外放了一個不在殼底下的特性組件：輸出面板應該有「LooseTrait 沒有放在殼（Shell）底下」的警告")
	print("[測試] 按 B：所有殼直接消失，每顆印一行「碎掉了」，箱子不受影響")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_B:
		print("[測試] 打碎所有殼")
		for shell in get_tree().get_nodes_in_group("shell"):
			shell.break_shell()

# 殼碎掉時印出名字
func _on_shell_broken(shell_name: String) -> void:
	print("[測試] %s 碎掉了" % shell_name)
