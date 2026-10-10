@tool
extends Button

# 選單按鈕：從下拉選單選這顆按鈕要做什麼，按下去就執行，不用連任何線。
# 按鈕上的字用原生的 Text 改；換動作時如果字還是預設的，會自動換成新動作的名字。
# 「整關重來」在關卡裡沒有 RespawnHandler 時自動藏起來，「離開遊戲」在網頁版自動藏起來。

## 按下去要做什麼
@export_enum("繼續遊戲", "整關重來", "離開遊戲") var action: int = ACTION_RESUME:
	set(value):
		if text == "" or text == _NAMES[action]:
			text = _NAMES[value]
		action = value

const ACTION_RESUME := 0
const ACTION_RESTART := 1
const ACTION_QUIT := 2

const _NAMES := ["繼續遊戲", "整關重來", "離開遊戲"]

# 按下去就執行選好的動作；暫停中也要按得到
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	pressed.connect(_on_pressed)
	refresh_menu_action()

# 依現在的狀況決定要不要出現：沒有 RespawnHandler 藏起「整關重來」，網頁版藏起「離開遊戲」。暫停選單打開時會呼叫
func refresh_menu_action() -> void:
	if action == ACTION_RESTART:
		visible = PauseMenu.can_restart()
	elif action == ACTION_QUIT:
		visible = not OS.has_feature("web")

# 執行選好的動作
func _on_pressed() -> void:
	match action:
		ACTION_RESUME:
			PauseMenu.close()
		ACTION_RESTART:
			PauseMenu.restart_level()
		ACTION_QUIT:
			PauseMenu.quit_game()
