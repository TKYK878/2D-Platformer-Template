extends Node2D

# 手動驗證用：CameraRig 三種鏡頭模式。Room1、Room3 是一個畫面大，Room2_Wide 是兩個畫面寬（藍色柱子當參考）。
# 場景預設「房間內跟隨」；按 1／2／3 在執行中切換模式（只是測試用的捷徑，學員是在 Inspector 選），按 K 自殺測重生，按 Z 震動。
# W3 加的：X 先強震再馬上弱震（弱的不能蓋掉強的）、C 鏡頭推近、0 Juice 總開關（關掉時震動、推近立刻停）。

@onready var _camera: Camera2D = $Camera2D

const _MODE_NAMES := ["瞬切", "房間內跟隨", "自由跟隨"]

func _ready() -> void:
	print("[測試] 目前鏡頭模式：%s（按 1 瞬切／2 房間內跟隨／3 自由跟隨）" % _MODE_NAMES[_camera.mode])
	print("[測試] 房間內跟隨：Room1 鏡頭不動；走進 Room2_Wide 瞬間切過去，之後左右跟著你走，但畫面不會露出 Room1、Room3；")
	print("[測試]   上下不會晃（房間跟畫面一樣高）；走進 Room3 又瞬間切過去")
	print("[測試] 瞬切：跟以前一樣，每個房間一個固定畫面（Room2_Wide 只看得到中間）")
	print("[測試] 自由跟隨：完全不管房間，一路平滑跟著你，房間交界也不會跳")
	print("[測試] 按 K 讓玩家死掉：跟隨模式重生時鏡頭直接到位，不會從死掉的地方滑過去；按 Z 震動，震完回原位")
	print("[測試] 按 X：強震（12）後馬上要求弱震（2），應該維持強震慢慢減弱，不會突然變小")
	print("[測試] 按 C：鏡頭推近 0.5 秒（放大 1.5 倍再回來），畫面往玩家偏一點；房間內跟隨模式下推近時畫面不會露出房間外")
	print("[測試] 按 C 後馬上按 0 關掉 Juice：推近立刻停、回到原本大小（再按 0 打開）")

# 測試用快捷鍵：1／2／3 切模式、K 自殺、Z 震動、X 強震接弱震、C 推近
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_1, KEY_2, KEY_3:
			_camera.mode = (event as InputEventKey).physical_keycode - KEY_1
			_camera.position_smoothing_enabled = _camera.mode != 0
			print("[測試] 鏡頭模式切成：%s（瞬切模式要再走進一個房間才會對齊）" % _MODE_NAMES[_camera.mode])
		KEY_K:
			$Player.kill()
		KEY_Z:
			Events.shake_requested.emit(6.0, 0.4)
		KEY_X:
			Events.shake_requested.emit(12.0, 1.0)
			Events.shake_requested.emit(2.0, 1.0)
			print("[測試] 強震 12 → 弱震 2")
		KEY_C:
			Events.zoom_requested.emit(0.5, 0.5, $Player, 0)
			print("[測試] 推近 0.5 倍、0.5 秒")
