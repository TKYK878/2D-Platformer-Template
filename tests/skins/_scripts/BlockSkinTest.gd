extends Node2D

# 手動驗證用：終點、按鈕、重生點、門、開關方塊、道具、尖刺、岩漿套上皮之後的狀態回饋（U178）。
# 每一種都擺了「有狀態圖」「沒有狀態圖」「沒有皮」來對照。T：門、開關方塊、尖刺、岩漿一起切換

const _TOGGLE_PREFIXES := ["Door", "Spike", "Lava"]

var _switched := false

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 開場：有皮的零件看不到原本的色塊，改顯示素材的圖（Button_NoSkin、Door4、Switch3、Spike3、Lava3 是沒有皮的色塊，對照用）")
	print("[測試] 　由左到右：金幣、樹樁（重生點）、紅色按鈕（按鈕頭上下動）、紅旗（終點）、木門×3、紅磚、金塊、尖刺×2、火焰陷阱×2（第二個火焰會動）")
	print("[測試] 往右走：金幣撿到整個消失；樹樁換成營火；")
	print("[測試] 　紅色按鈕踩一下換成綠色閃爍的「啟動」動畫，再踩一下換回紅色；紅旗終點（沒有 texture_active）踩到變綠")
	print("[測試] T（門、開關方塊、尖刺、岩漿一起切換）：")
	print("[測試] 　Door1 換成黑色門洞、不透明；Door2 黑色門洞＋變淡；Door3 還是木門、只變淡；Door4 色塊變淡")
	print("[測試] 　紅磚換成紅色虛線框；金塊（沒有 texture_active）整個藏起來；Switch3 色塊藏起來")
	print("[測試] 　Spike1 換成收起來的底座；Spike2（沒有收起來的圖）尖刺變暗；Spike3 色塊變暗")
	print("[測試] 　Lava1 火焰熄掉（換成 Off 的圖）；Lava2（動畫，沒有「啟動」）火焰照動但變暗；Lava3 色塊變暗")
	print("[測試] 　再按一次 T 全部回復原樣")
	print("[測試] 編輯器：選 Door1～3 的 Skin，Inspector 有 active_style 下拉；終點、金塊、Spike2 的 Skin 沒有 texture_active，看不到這個欄位")

# T：切換門、開關方塊、尖刺、岩漿
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode != KEY_T:
		return
	_switched = not _switched
	for child in get_children():
		var n := String(child.name)
		if n.begins_with("Switch"):
			child.set_active(not _switched)
		else:
			for prefix in _TOGGLE_PREFIXES:
				if n.begins_with(prefix):
					child.toggle()
	print("[測試] T：%s" % ("門打開、開關方塊關掉、尖刺岩漿關掉" if _switched else "全部回復原樣"))
