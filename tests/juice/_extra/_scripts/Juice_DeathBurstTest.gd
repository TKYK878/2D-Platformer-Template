extends Node2D

# 手動驗證用：死亡爆散（備品）。
# Juice_DeathBurst：預設值（碎塊 4 像素、力道 220、1.2 秒）。
# Juice_DeathBurst_Fine（一開始關著）：碎塊 2 像素（16x32 的角色會超過 64 塊，自動放大）、力道 500、2.5 秒。
# 另外掛了咕嚕眼、傾斜、重力翻轉（Q）；右邊一根即死尖刺。

@onready var _player: CharacterBody2D = $Player
@onready var _normal: Node = $Player/Juice/Juice_DeathBurst
@onready var _fine: Node = $Player/Juice/Juice_DeathBurst_Fine

# 印出操作說明
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳、Q 翻轉重力、T 切換兩種爆散、K 死亡、0 Juice 總開關")
	print("[測試] ① 碰尖刺或按 K：角色碎成一塊塊小方塊往外噴、往下掉、轉圈、淡掉；角色（含咕嚕眼）看不見")
	print("[測試] ② 重生後角色完整回來，畫面上沒有殘留碎塊")
	print("[測試] ③ Q 翻轉重力後再死：碎塊往天花板掉")
	print("[測試] ④ T 換成細碎版：碎塊比較細但不超過 64 塊、噴得比較遠")
	print("[測試] ⑤ 按 0 關掉 Juice 再死：不會爆散，角色照常消失重生的流程")

# 除錯按鍵：T 切換兩種爆散、K 死亡
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_T:
			_normal.enabled = not _normal.enabled
			_fine.enabled = not _fine.enabled
			print("[測試] 目前：%s" % ("一般" if _normal.enabled else "細碎版"))
		KEY_K:
			print("[測試] 模擬死亡")
			_player.kill()
