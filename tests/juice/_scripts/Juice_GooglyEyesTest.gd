extends Node2D

# 手動驗證用：咕嚕眼（持續型）。
# Juice_GooglyEyes：預設值（跟著移動方向轉頭、兩隻、大小 5、眼珠 0.45、晃動 0.6），節點拖到角色上半身。
# Juice_GooglyEyes_One（一開始關著）：一隻大眼睛、眼珠小、晃動 1，節點拖到肚子上。
# 另外掛了重力翻轉（Q）、忽大忽小（Shift）、擠壓拉伸（落地時）。

@onready var _player: CharacterBody2D = $Player
@onready var _two_eyes: Node = $Player/Juice/Juice_GooglyEyes
@onready var _one_eye: Node = $Player/Juice/Juice_GooglyEyes_One

# 印出操作說明
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳、Q 翻轉重力、Shift 忽大忽小、R 左右翻面、L 切換轉頭／擺正、T 切換兩種眼睛、K 死亡、0 Juice 總開關")
	print("[測試] ① 編輯器裡：場景樹點 Juice_GooglyEyes，角色上看得到兩隻眼睛；拖動節點眼睛跟著走；改 eye_count／eye_size／pupil_size 馬上看到變化")
	print("[測試] ② 往右起跑：眼珠留在原地、看起來甩到左邊；急停：眼珠往右衝、撞到眼眶彈回來；跳起來：眼珠往下沉、落地時往下撞；停下來慢慢回到中間（稍微偏下）")
	print("[測試] ②b 轉頭：往右走兩隻眼睛滑到臉的右邊，往左走滑到左邊，停下來留在最後那一側；按 L 換成擺正中間：眼睛一直待在節點的位置")
	print("[測試] ③ Q 翻轉重力：眼睛跟著角色倒過來，眼珠改往天花板那一側垂")
	print("[測試] ④ Shift 變大變小：眼睛跟著變大變小、位置還在臉上；落地壓扁時眼睛跟著一起扁")
	print("[測試] ⑤ R 左右翻面（模擬自動奔跑的轉向）：眼睛的位置左右對調，跑起來眼珠還是往畫面上正確的方向甩")
	print("[測試] ⑥ T 換成一隻大眼睛（晃動 1）：晃得比較久；K 死亡重生後眼珠回到中間；按 0 眼睛消失／出現")

# 除錯按鍵：R 左右翻面、L 切換轉頭／擺正、T 切換兩種眼睛、K 死亡
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_R:
			_player.visual.scale.x *= -1.0
			print("[測試] 角色朝向：%s" % ("左" if _player.visual.scale.x < 0.0 else "右"))
		KEY_L:
			_two_eyes.look = 1 - _two_eyes.look
			_one_eye.look = _two_eyes.look
			print("[測試] 眼睛：%s" % ("跟著移動方向轉頭" if _two_eyes.look == 0 else "擺正中間"))
		KEY_T:
			_two_eyes.enabled = not _two_eyes.enabled
			_one_eye.enabled = not _one_eye.enabled
			print("[測試] 目前：%s" % ("兩隻眼睛" if _two_eyes.enabled else "一隻大眼睛"))
		KEY_K:
			print("[測試] 模擬死亡")
			_player.kill()
