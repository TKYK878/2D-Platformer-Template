extends Node2D

# 手動驗證用：UIRoot 整套換字型、字的大小、配色，以及直接放在關卡裡時會自己移進 CanvasLayer 固定在畫面上。
# 1～5 換配色、Q／E 字變小／變大、F 換字型（系統字型／預設像素字）、方向鍵移動鏡頭

const _PALETTE_NAMES := ["預設", "暗色", "亮色", "復古綠", "糖果"]

@onready var _camera: Camera2D = $Camera2D

var _ui: UIRoot = null

# 印出操作說明，等 UIRoot 移進 CanvasLayer 之後檢查
func _ready() -> void:
	_ui = $UIRoot
	print("[測試] ① 編輯器裡選 UIRoot，改 palette、font_size：編輯畫面上的面板、字、按鈕、條、拉桿馬上跟著變")
	print("[測試] ② 按 1～5 換配色；「預設」跟原本 Godot 預設的樣子一樣；紅字那行有主題覆寫，永遠是紅字")
	print("[測試] ③ 按 Q／E：字變小／變大（12、24、36、48）；按 F：字型在系統字型與像素字之間切換")
	print("[測試] ④ 按方向鍵移動鏡頭：地板會動，面板固定在畫面上不動")
	print("[測試] ⑤ 存檔後用文字編輯器打開這個 .tscn：UIRoot 底下不會多出一大塊 theme 資料")
	await get_tree().process_frame
	await get_tree().process_frame
	print("[測試] UIRoot 現在的上一層：%s（應該是 CanvasLayer）" % _ui.get_parent().get_class())

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_ui.palette = event.physical_keycode - KEY_1
			print("[測試] 配色：%s" % _PALETTE_NAMES[_ui.palette])
		KEY_Q:
			_ui.font_size = maxi(_ui.font_size - 12, 12)
			print("[測試] 字的大小：%d" % _ui.font_size)
		KEY_E:
			_ui.font_size = mini(_ui.font_size + 12, 48)
			print("[測試] 字的大小：%d" % _ui.font_size)
		KEY_F:
			_ui.font = SystemFont.new() if _ui.font == null else null
			print("[測試] 字型：%s" % ("系統字型" if _ui.font != null else "預設像素字"))

# 方向鍵移動鏡頭
func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_camera.position += dir * 120.0 * delta
