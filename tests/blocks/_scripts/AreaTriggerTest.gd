extends Node2D

# 手動驗證用：觸發區 AreaTrigger（遊戲中看不見，編輯器裡是淡藍色框）。
# Trigger_Door 把門包在裡面：走進去門打開（entered → activate），走出去門關上（exited → deactivate）。
# Trigger_Once：只有第一次進入、勾了 reset_on_death。Trigger_Unconnected 沒連線、Trigger_GroupTypo 群組打錯字。

var _once_count := 0

# 印出操作說明
func _ready() -> void:
	print("[測試] ① 開場輸出面板有兩則提醒：Trigger_Unconnected 還沒連線、Trigger_GroupTypo 找不到群組「鑰匙箱」")
	print("[測試] ② 往右走：一走進淡藍色框（遊戲中看不見）門就打開，穿過門走出框，門在背後關上；回頭走進框，門又打開")
	print("[測試] ③ 跳過尖刺，走進 Trigger_Once：輸出面板印「第 1 次觸發」；來回進出不會再印")
	print("[測試] ④ 故意碰尖刺死掉重生，再走進 Trigger_Once：印「第 2 次觸發」（reset_on_death 有勾）")
	print("[測試] ⑤ 編輯器裡：拉 width_tiles／height_tiles，框跟著變；Trigger_GroupTypo 有黃色驚嘆號；")
	print("[測試] 　 trigger_mode 選「每次進入」時看不到 reset_on_death，triggered_by 不是「指定群組」時看不到 tag")

# Trigger_Once 的 entered 連到這裡
func _on_once_entered() -> void:
	_once_count += 1
	print("[測試] Trigger_Once：第 %d 次觸發" % _once_count)
