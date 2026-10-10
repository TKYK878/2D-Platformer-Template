extends Node2D

# 手動驗證用：鏡頭推近。Juice_CameraZoom 用預設值（打倒敵人時、放大 0.25、0.4 秒），
# Juice_CameraZoom_Manual 是「不自動觸發」、放大 0.6、0.8 秒，按 Z 呼叫它的 play()。
# 鏡頭是預設的瞬切模式；按 1／2／3 可以切換鏡頭模式比較；Q 換 Z 推近的放大中心、E 換偏移方式。

@onready var _camera: Camera2D = $Camera2D
@onready var _manual: Node = $Player/Juice/Juice_CameraZoom_Manual

const _MODE_NAMES := ["瞬切", "房間內跟隨", "自由跟隨"]
const _FOCUS_NAMES := ["畫面中心", "玩家", "觸發位置"]
const _STYLE_NAMES := ["偏一點", "定在原地", "拉到正中央"]

# 印出操作說明，監聽推近請求
func _ready() -> void:
	Events.zoom_requested.connect(func(strength: float, duration: float, focus: Variant, focus_style: int):
		print("[測試] 推近請求：放大 %.2f　%.2f 秒　中心 %s　偏移方式 %d" % [strength, duration, focus, focus_style]))
	print("[測試] 方向鍵移動、空白跳、F 攻擊、Z 大推近、Q 換放大中心、E 換偏移方式、1／2／3 切鏡頭模式、0 Juice 總開關")
	print("[測試] ① F 打倒敵人：鏡頭快速放大一點再慢慢回來，畫面往玩家那邊偏")
	print("[測試] ② 站在房間左右兩端按 Z：放大明顯；瞬切、房間內跟隨模式都不會看到房間外（黑色區域）")
	print("[測試] ③ 按 Z 後馬上按 0：推近立刻停、回到原本大小")
	print("[測試] ④ 按 3 切自由跟隨，站在畫面一側：Q 選畫面中心 → Z 從畫面正中間放大，不偏移")
	print("[測試] ⑤ Q 選玩家：E 選偏一點 → 往玩家偏一點；定在原地 → 玩家在畫面上不動；拉到正中央 → 玩家被拉到畫面正中間")
	print("[測試] ⑥ Q 選觸發位置，按 Z 後馬上走開：放大中心停在按 Z 時玩家站的地方，不跟著玩家走")

# 除錯按鍵：Z 大推近、1／2／3 切鏡頭模式
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_Z:
			_manual.play()
		KEY_Q:
			_manual.focus = (_manual.focus + 1) % _FOCUS_NAMES.size()
			print("[測試] Z 推近的放大中心：%s" % _FOCUS_NAMES[_manual.focus])
		KEY_E:
			_manual.focus_style = (_manual.focus_style + 1) % _STYLE_NAMES.size()
			print("[測試] Z 推近的偏移方式：%s" % _STYLE_NAMES[_manual.focus_style])
		KEY_1, KEY_2, KEY_3:
			_camera.mode = event.physical_keycode - KEY_1
			_camera.position_smoothing_enabled = _camera.mode != 0
			print("[測試] 鏡頭模式：%s" % _MODE_NAMES[_camera.mode])
