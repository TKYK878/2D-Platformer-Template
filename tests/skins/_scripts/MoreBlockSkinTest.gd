extends Node2D

# 手動驗證用：箱子、可破壞、崩塌地板、彈射、風扇、移動平台、無反彈方塊、單向平台、傳送門套上皮（U179），
# 還有 fill_style（只放一張／重複鋪滿／拉伸蓋滿）與風扇的 follow_direction。每一種都擺了「沒有皮」的對照。
# T：彈射台、風扇、傳送門 A 一起開關　H：打所有可破壞方塊一下

const _TOGGLE_PREFIXES := ["Launcher", "Fan", "PortalA"]

var _off := false

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 開場：有皮的零件看不到原本的色塊（名字有 NoSkin 的是色塊，對照用）")
	print("[測試] 上排：NoBounce1 紅磚重複鋪成 4×2 格；NoBounce2 一塊紅磚拉長蓋滿；NoBounce3 只有中間一塊紅磚（看得到虛線框）")
	print("[測試] 　OneWay1 灰色平台重複兩段；OneWay2 灰色平台動畫拉長成 4 格；Moving1 棕色平台動畫跟著移動")
	print("[測試] 地上：箱子推得動、皮跟著走；崩塌地板（動畫）踩上去皮跟著抖、碎掉後皮消失、2～3 秒後長回來")
	print("[測試] 　H：Breakable1（22×22 的圖縮進格子）、Breakable2（裁好的 16×16）越打越淡，第 3 下碎掉消失，2 秒後長回來")
	print("[測試] 　彈跳床會把玩家彈上去；走進傳送門 A（紫色）傳到右邊的 B")
	print("[測試] 風扇：Fan1 往上吹、葉片在轉；Fan2 往左吹、皮轉成朝左；Fan3 往左吹但 follow_direction 沒勾，皮還是朝上")
	print("[測試] T：彈跳床、傳送門 A 變暗（不彈、不傳）；風扇停下來換成 Off 的圖、風力框變淡。再按一次 T 回復")
	print("[測試] 編輯器：選 Fan2 的 SkinAnimated 有 follow_direction，其他零件的皮沒有")
	print("[測試] 　把 NoBounce1 的 width_tiles 拉大，紅磚即時跟著多鋪幾塊；NoBounce2 跟著拉長")

# T：開關彈射台、風扇、傳送門 A；H：打可破壞方塊
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_T:
			_off = not _off
			for child in get_children():
				for prefix in _TOGGLE_PREFIXES:
					if String(child.name).begins_with(prefix):
						child.toggle()
			print("[測試] T：%s" % ("彈射台、風扇、傳送門 A 關掉" if _off else "全部打開"))
		KEY_H:
			for child in get_children():
				if String(child.name).begins_with("Breakable"):
					child.take_hit(1, Vector2.ZERO, self)
			print("[測試] H：打了可破壞方塊一下")
