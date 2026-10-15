extends Node2D

# 手動驗證用：訊號換圖（U208）。Skin／SkinAnimated 的 show_normal、show_active、next_look、previous_look、show_first、show_last、show_look。
# Look1～3、5 是同一套圖：旗子降下 → 旗子升起 → 門 → 門打開；Look4 是動畫：平常 → 啟動 → 其他動畫照名稱排（傳送門、門）。

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 編輯器：Look1～3 的 Skin 有「訊號換圖」群組（more_textures 兩張門、signal_priority、loop_looks）")
	print("[測試] 　Look5 黃色驚嘆號「more_textures 第 2 格是空的…」")
	print("[測試] 踩左邊的按鈕（踩一下切換）：按鈕的 turned_on／turned_off 都連到 Look1 的 next_look，每踩一下旗子降下 → 升起 → 門 → 門打開 → 旗子降下")
	print("[測試] 按鍵（Look1～5 一起做）：")
	print("[測試] 　N 下一張　P 上一張　1 show_normal　2 show_active　F 第一張　L 最後一張　3 show_look(3)　9 show_look(9)")
	print("[測試] 　按 N 四次：Look1、2 回到旗子降下；Look3（loop_looks 沒勾）停在門打開；Look4 平常 → 啟動 → 傳送門 → 門 → 平常")
	print("[測試] 　按 P：Look3 一直按會停在旗子降下，其他會從第一張繞到最後一張")
	print("[測試] 　按 2：Look5 印「show_active 被呼叫了，但 texture_active 是空的」，其他換成旗子升起（Look4 播「啟動」）")
	print("[測試] 　按 9：每個都印「show_look(9)：只有 N 張圖」，圖不換")
	print("[測試] 　Look5 按 N：只在旗子降下、門之間換（空的格子跳過）")
	print("[測試] A（零件自己的狀態改變，跟終點被踩到一樣）：先按 L 換到最後一張，再按 A：")
	print("[測試] 　Look1、3、4、5（零件的狀態優先）換回零件該有的樣子（旗子升起，Look4 播「啟動」，Look5 沒有升起的圖就變綠）；")
	print("[測試] 　Look2（訊號優先）維持門打開（active_style 是「換圖就好」所以不變色）。再按一次 A：Look2 還是門打開，其他回到旗子降下")

# 除錯按鍵：對每個假零件底下的皮呼叫訊號換圖的函式；A 切換零件自己的狀態
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_A:
		get_tree().call_group("skin_test_block", "toggle_active")
		print("[測試] A：切換零件自己的狀態")
		return
	var calls := {
		KEY_N: ["next_look", []], KEY_P: ["previous_look", []], KEY_1: ["show_normal", []], KEY_2: ["show_active", []],
		KEY_F: ["show_first", []], KEY_L: ["show_last", []], KEY_3: ["show_look", [3]], KEY_9: ["show_look", [9]],
	}
	if not calls.has(event.physical_keycode):
		return
	var method: String = calls[event.physical_keycode][0]
	var args: Array = calls[event.physical_keycode][1]
	print("[測試] %s%s" % [method, args])
	for block in get_tree().get_nodes_in_group("skin_test_block"):
		for child in block.get_children():
			if child.has_method(method):
				child.callv(method, args)
