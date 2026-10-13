@tool
extends Area2D

# 終點：感應，玩家踩到時變色、發出 reached，同步轉發 Events.level_cleared
#（過關畫面 ClearScreen 聽這個跳出來；重生記憶也會訂閱它清空所有記錄，見 autoload/RespawnMemory.gd）。
# 拖進場景就能用，不用連任何線；要有過關畫面，關卡裡要再擺一個 blocks/ClearScreen.tscn。

## 踩到終點時發出，給學員自己接效果用（例如接特效或音效）
signal reached

const _CLEAR_SCREEN_SCRIPT_PATH := "res://blocks/_scripts/ClearScreen.gd"
const _COLOR_WAITING := Color(0.95, 0.8, 0.2, 1)
const _COLOR_REACHED := Color(0.3, 0.85, 0.35, 1)
# 編輯器裡每隔幾秒重新檢查一次有沒有過關畫面，學員拖進來之後黃色警告會跟著消失
const _WARNING_REFRESH_SECONDS := 1.0

var _skin: SkinLink = null
var _cleared: bool = false
var _warning_timer: float = 0.0

# 設定碰撞層／遮罩，只偵測玩家；底下有皮就換上皮
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_skin = SkinLink.new(self, $Visual)
	add_to_group("signal_source")
	add_to_group("goal")
	collision_layer = Layers.SENSOR
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)

# 玩家踩到終點：變色、發出訊號並轉發 Events.level_cleared，只算第一次
func _on_body_entered(body: Node) -> void:
	if _cleared or not body.is_in_group("player"):
		return
	_cleared = true
	_skin.show_state(true, _COLOR_REACHED)
	reached.emit()
	Events.level_cleared.emit()

# 恢復成還沒踩過，可以再過關一次（整關重來、過關畫面按再玩一次時呼叫）
func reset() -> void:
	_cleared = false
	if _skin != null:
		_skin.show_state(false, _COLOR_WAITING)

# 編輯器裡的黃色驚嘆號：場景裡沒有過關畫面，踩到終點畫面上不會有任何反應
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_inside_tree():
		return warnings
	var root := get_tree().edited_scene_root
	if root != null and not _has_clear_screen(root):
		warnings.append("場景裡沒有過關畫面，踩到終點不會跳出「過關！」：把 blocks/ClearScreen.tscn 拖進關卡。")
	return warnings

# 場景裡有沒有過關畫面
func _has_clear_screen(root: Node) -> bool:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var node_script: Script = node.get_script()
		if node_script != null and node_script.resource_path == _CLEAR_SCREEN_SCRIPT_PATH:
			return true
		stack.append_array(node.get_children())
	return false

# 編輯畫面持續請求重畫，讓虛線跟著訊號連接的變化即時更新；每隔一段時間重新檢查有沒有過關畫面
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	queue_redraw()
	_warning_timer += delta
	if _warning_timer >= _WARNING_REFRESH_SECONDS:
		_warning_timer = 0.0
		update_configuration_warnings()

# 編輯畫面用：幫這個零件自己發出的每個訊號的每條連接畫一條虛線到目標節點
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	SignalLines.draw(self, reached)
