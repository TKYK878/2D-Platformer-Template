extends Node2D

# 手動驗證用：HUD 範本的底框 Panel、UIRoot 的 hud_background（無／字加外框，U210）。背景是很花的亮黃格子。
# B：換 hud_background　P：換配色　S：換風格　N：金幣 +111（看底框跟著變寬）　H：藏起／顯示金幣那一列（底框跟著縮）

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 編輯器：點 HudTemplate，Inspector 有 hud_background（預設「字加外框」）；把 kind 改成暫停選單，這一格就藏起來")
	print("[測試] 編輯器：HUD 範本裡 Rows 包在 Panel 底下，畫面上左上角有一塊跟暫停選單一樣的底框")
	print("[測試] F6：左上角有底框，字外面有一圈深色描邊（hud_background 預設「字加外框」）")
	print("[測試] B：字加外框 ↔ 無")
	print("[測試] P：換配色，底框和描邊顏色跟著變（亮色、糖果配色的字是深色，描邊變淺色）")
	print("[測試] S：換風格，底框形狀跟著變（像素復古切角、乾淨極簡、可愛圓角）")
	print("[測試] N：金幣 +111，數字變長時底框跟著變寬")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var hud := get_tree().get_first_node_in_group("custom_ui_0") as UIRoot
	if hud == null:
		return
	match event.physical_keycode:
		KEY_B:
			hud.hud_background = (hud.hud_background + 1) % 2
			print("[測試] hud_background：%s" % ["無", "字加外框"][hud.hud_background])
		KEY_P:
			hud.palette = (hud.palette + 1) % 5
			print("[測試] palette：%d" % hud.palette)
		KEY_S:
			hud.style = (hud.style + 1) % 3
			print("[測試] style：%d" % hud.style)
		KEY_H:
			var coin_row: Control = hud.get_node("Panel/Rows/CoinRow")
			coin_row.visible = not coin_row.visible
			hud.get_node("Panel").reset_size.call_deferred()
			print("[測試] 金幣那一列：%s" % ("顯示" if coin_row.visible else "藏起來"))
		KEY_N:
			Stats.add("金幣", 111)
			print("[測試] 金幣 +111")
