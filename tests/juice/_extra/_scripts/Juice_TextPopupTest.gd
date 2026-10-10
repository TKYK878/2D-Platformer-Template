extends Node2D

# 手動驗證用：跳字（持續型，備品）。
# Juice_TextPopup：預設值（全部數值、加綠減紅、大小 11、0.8 秒）。
# Juice_TextPopup_Star（一開始關著）：自訂「  星星 」（頭尾空白會自動去掉）、黃色、大小 16、1.5 秒。
# Juice_TextPopup_Typo（一直關著）：自訂「星心」，故意打錯字，開場就要有中文警告。
# 地上一排 5 個金幣、1 顆星星（自訂種類）、右邊 1 根尖刺。

@onready var _player: CharacterBody2D = $Player
@onready var _all: Node = $Player/Juice/Juice_TextPopup
@onready var _star: Node = $Player/Juice/Juice_TextPopup_Star

# 印出操作說明
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳、C +1 金幣、V 一次 +5 金幣（分 5 次加）、H 扣 1 血、T 切換兩種跳字、K 死亡、0 Juice 總開關")
	print("[測試] ① 開場：輸出面板有「[跳字] Juice_TextPopup_Typo：場景裡找不到數值種類「星心」，是不是想打「星星」？」；編輯器裡這個節點有黃色驚嘆號")
	print("[測試] ② 往右走撿金幣：頭上跳出綠色「+1 金幣」往上飄、淡掉；連著撿會合併成「+2 金幣」「+3 金幣」")
	print("[測試] ③ 撿星星：跳出「+1 星星」；按 V：只跳一個「+5 金幣」")
	print("[測試] ④ 碰尖刺或按 H：跳出紅色「-1 血量」，字一律往畫面上方飄")
	print("[測試] ⑤ 按 K 死亡：重生時補血、退回金幣都不跳字，飄到一半的字消失")
	print("[測試] ⑥ 按 T 換成只跳「星星」：撿金幣、扣血不跳字，撿星星跳出黃色大字；編輯器裡把 kind 改回「全部數值」，custom_kind 欄位要消失")

# 除錯按鍵：C／V 加金幣、H 扣血、T 切換兩種跳字、K 死亡
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_C:
			Stats.add("金幣", 1)
		KEY_V:
			for i in 5:
				Stats.add("金幣", 1)
		KEY_H:
			_player.take_damage(1)
		KEY_T:
			_all.enabled = not _all.enabled
			_star.enabled = not _star.enabled
			print("[測試] 目前：%s" % ("全部數值" if _all.enabled else "只有星星"))
		KEY_K:
			print("[測試] 模擬死亡")
			_player.kill()
