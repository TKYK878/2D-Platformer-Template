extends Node2D

# 手動驗證用：Fan 的 direction/force/range_tiles 效果，以及 activate/deactivate/toggle；
# 吹法「固定速度」（U199）：Fan_SlowUp、Fan_FixedSide。

@onready var _button: Area2D = $Button_Toggle
@onready var _fan_toggle: Area2D = $Fan_Toggle

func _ready() -> void:
	_button.turned_on.connect(_fan_toggle.activate)
	_button.turned_off.connect(_fan_toggle.deactivate)
	print("[測試] Fan_Up（左側，固定速度 20 格/秒往上）一直開著，站上去應該很快被往上吹，速度不會越來越快")
	print("[測試] Fan_Side（中間）一直開著，走進範圍應該被持續往右吹")
	print("[測試] Fan_Toggle（右側，固定速度 0 格/秒）一開始關著，踩一下旁邊的 Button_Toggle 打開後走進去應該懸在空中不動，再踩一次會停")
	print("[測試] Fan_SlowUp（最左邊，固定速度 0.1 格/秒往上）：走進去應該非常慢地往上飄，大約 10 秒才升 1 格，不會越來越快")
	print("[測試] Fan_FixedSide（最右邊，固定速度 2 格/秒往右）：走進去放開方向鍵，應該穩定地每秒被推 2 格，不會越來越快")
	print("[測試] Fan_Side（越吹越快）手感應該跟以前一模一樣")
	print("[測試] 摩擦力開關：把 Fan_Side 的 friction_enabled 勾起來再測，往右吹應該明顯變溫和（力道就是 force）；吹法改成固定速度時這個勾選框會藏起來")
	print("[測試] 方向預覽：在編輯器裡改任一台的 direction、range_tiles，淡藍範圍和箭頭應該馬上跟著變；把 Fan_Side 的旋轉改成 45 或 -90 度，按 Play 後風要往箭頭指的方向吹")
