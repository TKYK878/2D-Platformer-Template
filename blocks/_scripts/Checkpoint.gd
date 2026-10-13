@tool
extends Area2D

# 重生點：感應，玩家踩到時把重生位置改成這裡（轉發 Events.checkpoint_reached(self) 給重生記憶），並發出 reached。
# 什麼時候改重生位置看 save_trigger，reached 要不要再發看 repeatable，兩個分開。拖進場景就能用，不用連任何線。

## 什麼時候把重生位置改成這個重生點：每次踩到都改，或只有第一次踩到才改（走回頭路再踩不會改）
@export_enum("每次踩到", "只有第一次踩到") var save_trigger: int = 1

## 踩過一次之後，再踩還會不會再發出 reached 訊號（只管訊號，重生位置看 save_trigger）
@export var repeatable: bool = false

## 踩到時發出，給學員自己接效果用（例如接特效或音效）
signal reached

const _SAVE_EVERY_TIME := 0

var _touched: bool = false
var _saved: bool = false
var _skin: SkinLink = null

# 設定碰撞層／遮罩，只偵測玩家；底下有皮就換上皮
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_skin = SkinLink.new(self, $Visual)
	add_to_group("signal_source")
	add_to_group("checkpoint")
	collision_layer = Layers.SENSOR
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)

# 玩家踩到：依 save_trigger 把重生位置改成這裡；依 repeatable 決定要不要再發出 reached
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if save_trigger == _SAVE_EVERY_TIME or not _saved:
		_saved = true
		Events.checkpoint_reached.emit(self)
	if _touched and not repeatable:
		return
	_touched = true
	_update_visual()
	reached.emit()

# 變回沒踩過的樣子，重生記憶被清空（整關重來、過關）時呼叫，之後可以再踩一次、再記一次
func forget() -> void:
	_touched = false
	_saved = false
	_update_visual()

# 踩過一次之後外觀保持「已啟用」的顏色（有皮就換皮的樣子），之後再踩也不會變回去
func _update_visual() -> void:
	if _skin != null:
		_skin.show_state(_touched, Color(0.3, 0.85, 0.35) if _touched else Color(0.5, 0.55, 0.85))

# 編輯畫面持續請求重畫，讓虛線跟著訊號連接的變化即時更新
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

# 編輯畫面用：幫這個零件自己發出的每個訊號的每條連接畫一條虛線到目標節點
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	SignalLines.draw(self, reached)
