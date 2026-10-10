extends Node2D

# 手動驗證用：UISettings（接法 A）。兩個場景共用這個腳本：
# UISettingsTest：hud_scene 接 MyHudExample（正確）、pause_menu_scene 接 HUD 範本（種類錯）、clear_screen_scene 接 HudText（不是 UIRoot）
# UISettingsConflictTest：hud_scene 接 MyHudExample，關卡裡又直接放了一個（暗色配色的那個）
# H 血量 -1

# 印出操作說明
func _ready() -> void:
	if name == "UISettingsTest":
		print("[測試] ① 編輯器：UISettings 有黃色驚嘆號兩則：pause_menu_scene「拖進來的是HUD，不是暫停選單，請拖進 hud_scene」、")
		print("[測試] 　　clear_screen_scene「最上層不是 UIRoot，請從 ui/templates/ 的範本再製出來改」；hud_scene 沒有問題")
		print("[測試] ② F6：右上角出現粉紅色「我的 HUD」血條，左上角預設的血條藏起來；輸出面板有上面兩則警告（後面加「先用預設的」）")
		print("[測試] ③ H：血量 -1，粉紅色血條變短")
	else:
		print("[測試] ① 編輯器：UISettings 有黃色驚嘆號「hud_scene：關卡裡已經直接放了一個自訂HUD，會用那一個，這個欄位不會用到」")
		print("[測試] ② F6：右上角只有一個「我的 HUD」，是暗色配色的（直接放的那個）；輸出面板警告「…用那一個，這個欄位先不用」")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		Stats.add(Stats.HEALTH_KIND, -1)
