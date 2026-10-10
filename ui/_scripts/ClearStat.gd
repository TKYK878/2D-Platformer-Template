@tool
extends Label

# 過關畫面專用的一行字：從下拉選單選要顯示什麼（用了幾秒／死了幾次／製作者的話）。
# 要不要顯示照關卡裡 ClearScreen 的勾選（show_time、show_deaths），製作者的話寫在 ClearScreen 的 message，空白就不顯示。
# 字的樣子（大小、顏色、對齊）用原生的屬性改。編輯器裡先用假資料顯示，擺位置時看得出大小。

## 要顯示什麼
@export_enum("用了幾秒", "死了幾次", "製作者的話") var stat: int = STAT_TIME:
	set(value):
		stat = value
		if Engine.is_editor_hint():
			text = _PREVIEW[stat]

const STAT_TIME := 0
const STAT_DEATHS := 1
const STAT_MESSAGE := 2

const _PREVIEW := ["用了 12.3 秒", "死了 2 次", "（製作者的話）"]

# 照過關畫面的欄位更新內容、決定要不要出現；過關畫面跳出來時呼叫
func refresh_clear_stat(screen: Node) -> void:
	match stat:
		STAT_TIME:
			visible = screen.show_time
			text = "用了 %.1f 秒" % screen.get_time()
		STAT_DEATHS:
			visible = screen.show_deaths
			text = "死了 %d 次" % screen.get_deaths()
		STAT_MESSAGE:
			text = screen.get_message()
			visible = text != ""
