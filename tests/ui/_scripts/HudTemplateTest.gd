extends Node2D

# 手動驗證用：預設 HUD 改用範本、學員的 HUD 直接放進關卡時預設的一列一列讓位、放兩個的警告。
# H 血量 -1、C 金幣 +1、K 鑰匙 +1、G 隱藏分數 +1、T 放進／拿掉自訂 HUD、Y 再放一個自訂 HUD

const _MY_HUD := preload("res://tests/ui/MyHudExample.tscn")

var _my_hud: Node = null

# 印出操作說明
func _ready() -> void:
	print("[測試] ① 一開場左上角只有「血量」血條（ValueSettings 有勾 show_in_hud），跟以前的預設 HUD 一樣")
	print("[測試] ② C：金幣第一次 +1 才出現「金幣：1」那一列；K：鑰匙第一次 +1 才多一列「鑰匙：1」（範本裡沒有，自動生）")
	print("[測試] ③ G：隱藏分數 +1，畫面上不會出現（show_in_hud 沒勾）；H：血量 -1，血條變短")
	print("[測試] ④ T：放進自訂 HUD（右上角粉紅色「我的 HUD」血條）——左上角的血量那一列藏起來，金幣、鑰匙照舊；再按 T 拿掉，血量那一列回來")
	print("[測試] ⑤ 放著自訂 HUD 按 Y：再放一個，輸出面板警告「關卡裡已經有一個自訂HUD…不會用到」，畫面上不會多一個")
	print("[測試] ⑥ 編輯器：打開 ui/templates/HudTemplate.tscn，長得跟遊戲中左上角一樣（血量條＋金幣）")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_H:
			Stats.add(Stats.HEALTH_KIND, -1)
		KEY_C:
			Stats.add("金幣", 1)
		KEY_K:
			Stats.add("鑰匙", 1)
		KEY_G:
			Stats.add("隱藏分數", 1)
		KEY_T:
			if is_instance_valid(_my_hud):
				_my_hud.get_parent().queue_free() if _my_hud.get_parent() is CanvasLayer else _my_hud.queue_free()
				_my_hud = null
				print("[測試] 拿掉自訂 HUD")
			else:
				_my_hud = _MY_HUD.instantiate()
				add_child(_my_hud)
				print("[測試] 放進自訂 HUD")
		KEY_Y:
			add_child(_MY_HUD.instantiate())
			print("[測試] 再放一個自訂 HUD")
