extends Node

# 鏡頭縮放：拖進房間（Room）底下，玩家走進這個房間時鏡頭平滑放大到設定的倍率，離開房間再平滑恢復。
# 狹窄的過道、小房間用，不用連任何線；實際的縮放由關卡的鏡頭（CameraRig）處理。

## 走進這個房間時鏡頭放大幾倍：1 是原本大小，2 是放大兩倍（看到的範圍變一半）；小於 1 是拉遠
@export_range(0.5, 3.0, 0.05) var strength: float = 1.5

# 加入群組讓鏡頭找得到；等場景都準備好再檢查有沒有放在房間底下
func _ready() -> void:
	add_to_group("camera_zoom")
	_check_room.call_deferred()

# 沒有放在任何房間底下的話印中文警告，不然走到哪都不會放大卻沒有提示
func _check_room() -> void:
	for room in get_tree().get_nodes_in_group("room"):
		if room.is_ancestor_of(self):
			return
	var message := "[鏡頭縮放] %s 沒有放在房間（Room）底下，走到哪裡都不會放大。把它拖到要放大的房間底下" % name
	push_warning(message)
	printerr("⚠ %s" % message)
