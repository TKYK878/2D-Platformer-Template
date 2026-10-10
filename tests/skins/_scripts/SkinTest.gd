extends Node2D

# 手動驗證用：Skin、SkinAnimated 與零件端的共用接法（SkinLink）。假零件是黃色 16×32 的色塊。
# A：切換「狀態改變後」　F：切換面向（左右翻）　G：切換變淡

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 編輯器：每個皮都有黃色虛線框（原本色塊 16×32 的範圍）；把 1 號的 Skin 拖遠一點，框還是畫在零件原本的位置")
	print("[測試] 編輯器黃色驚嘆號：")
	print("[測試] 　4 號 SkinAnimated「缺少「平常」動畫…現在有的：「啟動」、「平」。「平」是不是要改名成「平常」？」")
	print("[測試] 　5 號 Skin「texture_normal 是空的」；6 號第二個皮「底下已經有一個皮…」；放在場景最上層的 LostSkin「皮要放在零件…底下」")
	print("[測試] F6：1、2、3 號看不到黃色色塊，改顯示圖；4、5 號照舊顯示黃色色塊，輸出面板有中文警告（…先顯示原本的色塊）")
	print("[測試] 　6 號顯示第一個皮，第二個藏起來，輸出面板警告「底下有不只一個皮」")
	print("[測試] A：1 號（沒有 texture_active）圖變綠；2 號換成另一張圖；3 號播「啟動」動畫；4、5 號色塊變綠。再按一次回復")
	print("[測試] F：1、3 號左右翻，2 號不翻（follow_facing 沒勾）　G：有皮的變淡、沒皮的色塊變淡")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_A:
			get_tree().call_group("skin_test_block", "toggle_active")
		KEY_F:
			get_tree().call_group("skin_test_block", "toggle_facing")
		KEY_G:
			get_tree().call_group("skin_test_block", "toggle_fade")
