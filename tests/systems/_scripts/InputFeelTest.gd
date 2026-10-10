extends Node2D

# 手動驗證用：按鍵手感（晚一點按、早一點按也能跳、短按小跳、頂頭修正、起跑加速），做在 Player 裡（Inspector「按鍵手感」）。
# 左邊有一個高台（從右緣走出去測土狼時間），右邊一個更高的台子（從它左緣正下方跳，測頂頭修正）；掛了跳躍音效，每跳一次都聽得到。
# 二段跳、蓄力青蛙跳、蹬牆跳一開始都關著，用按鍵打開，確認跟按鍵手感一起用不打架。

@onready var _player: CharacterBody2D = $Player
@onready var _double: Node = $Player/Mechanics/Extra_DoubleJump
@onready var _charge: Node = $Player/Mechanics/Mechanic_ChargeJump
@onready var _wall: Node = $Player/Mechanics/Extra_WallJump

var _left_floor_ms: int = 0
var _was_on_floor: bool = true

# 印出操作說明，接上跳躍訊號，跳的時候印出離開地面多久了
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳、1 晚一點按也能跳、2 早一點按也能跳、3 短按小跳、4 頂頭修正、5 起跑加速（都是開／關）、D 二段跳、C 蓄力青蛙跳、W 蹬牆跳、K 死亡")
	print("[測試] ① 從左邊高台往右走出邊緣，掉下去之後馬上按空白：還跳得起來，輸出面板印「離開地面 0.0X 秒後起跳」（0.1 秒內）")
	print("[測試] ② 按 1 關掉再做一次：一走出邊緣就跳不起來")
	print("[測試] ③ 從高台跳下來，快落地前按空白（放開也沒關係）：落地的瞬間自動跳起來；按住不放的話一樣是滿高度")
	print("[測試] ④ 按 2 關掉再做一次：太早按就被吃掉，落地後不會跳")
	print("[測試] ⑤ 按 D 開二段跳：走出邊緣馬上按空白是普通跳（印出「空中跳次數 1」沒被扣），再按一次才是空中跳")
	print("[測試] ⑥ 按 C 開蓄力青蛙跳：快落地前按住空白，落地後開始蓄力、放開才跳；快落地前點一下就放開，落地後小跳一下，不會變成一般的全力跳")
	print("[測試] ⑦ 按 W 開蹬牆跳：在高台上貼著最左邊的牆按空白，是普通的往上跳，不會被當成蹬牆跳往右彈出去")
	print("[測試] ⑧ 在地上點一下空白：只跳一點點高；按住不放：跳滿高度；按 3 關掉後點一下也是滿高度。開二段跳時空中那一跳一樣是點一下就矮")
	print("[測試] ⑨ 走到右邊高台左緣的正下方（角色身體右邊剛好比高台左緣多一點點），往上跳：頭不會卡在邊角，被往左推一點點直接跳上去高度；按 4 關掉再試：頭撞到邊角停住")
	print("[測試] ⑩ 按 5 開起跑加速：一開始走會慢慢加速到全速、左右轉向會先減速；關掉時一按就是全速")
	_player.jumped.connect(_on_jumped)
	_print_state()

# 每個物理幀記下最後一次站在地上的時間
func _physics_process(_delta: float) -> void:
	var on_floor := _player.is_on_floor()
	if _was_on_floor and not on_floor:
		_left_floor_ms = Time.get_ticks_msec()
	_was_on_floor = on_floor

# 跳起來的時候印出是站在地上跳的，還是離開地面幾秒後跳的
func _on_jumped() -> void:
	if _player.is_on_floor():
		print("[測試] 起跳：站在地上")
	else:
		print("[測試] 起跳：離開地面 %.2f 秒後起跳%s" % [(Time.get_ticks_msec() - _left_floor_ms) / 1000.0,
			"（空中跳次數 %d）" % _double._jumps_left if _double.enabled else ""])

# 印出現在按鍵手感與卡片的開關
func _print_state() -> void:
	print("[測試] 晚一點按：%s ｜ 早一點按：%s ｜ 短按小跳：%s ｜ 頂頭修正：%s ｜ 起跑加速：%s ｜ 二段跳：%s ｜ 蓄力青蛙跳：%s ｜ 蹬牆跳：%s" % [
		_on_off(_player.late_jump_enabled), _on_off(_player.early_jump_enabled),
		_on_off(_player.short_jump_enabled), _on_off(_player.corner_fix_enabled), _on_off(_player.smooth_start_enabled),
		_on_off(_double.enabled), _on_off(_charge.enabled), _on_off(_wall.enabled)])

# 把開關狀態變成「開」「關」
func _on_off(on: bool) -> String:
	return "開" if on else "關"

# 除錯按鍵：1～5 開關按鍵手感、D／C／W 開關卡片、K 死亡
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1: _player.late_jump_enabled = not _player.late_jump_enabled
		KEY_2: _player.early_jump_enabled = not _player.early_jump_enabled
		KEY_3: _player.short_jump_enabled = not _player.short_jump_enabled
		KEY_4: _player.corner_fix_enabled = not _player.corner_fix_enabled
		KEY_5: _player.smooth_start_enabled = not _player.smooth_start_enabled
		KEY_D: _double.enabled = not _double.enabled
		KEY_C: _charge.enabled = not _charge.enabled
		KEY_W: _wall.enabled = not _wall.enabled
		KEY_K:
			print("[測試] 模擬死亡")
			_player.kill()
			return
		_:
			return
	_print_state()
