extends Node2D

# 手動驗證用：音效。Juice_Sound 用預設值（跳躍時播跳躍聲），其他：落地聲、受傷聲（同時頓幀 0.3 秒）、
# 撿金幣聲（音高由低到高，地上一排 9 個金幣）、撞牆時播「自訂」音檔（這裡拿爆炸聲假裝是學員的檔案）、
# Juice_Sound_Broken 死亡時選「自訂」但沒放音檔（故意設錯）。

@onready var _player: CharacterBody2D = $Player
@onready var _coin: Node = $Player/Juice/Juice_Sound_Coin

const _MODES := ["隨機", "固定", "由低到高"]
const _NOTES := ["五聲音階", "大調音階", "半音", "琶音"]

# 印出操作說明
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳、H 受傷、K 死亡、C 手動播金幣聲、P 換金幣聲的音高模式、N 換音階、M 換爬到最高之後、0 Juice 總開關")
	print("[測試] ⓪ 開場：輸出面板有 Juice_Sound_Broken「custom_sound 是空的」警告；編輯器場景樹上它有黃色驚嘆號")
	print("[測試] ① 跳：跳躍聲，連跳幾次音高每次有一點點不一樣；落地：落地聲（從高處掉下來比較大聲）")
	print("[測試] ② 按 H：受傷聲，畫面頓 0.3 秒，但聲音照常播完、不會變慢變低")
	print("[測試] ③ 往右撿金幣：金幣聲一聲比一聲高（五聲音階），聲音會疊在一起不會互相切斷；撿完停一下再按 C，從最低音重來")
	print("[測試] ③b 連按 C：爬 8 聲到最高後一直播最高音；按 M 換成從頭再來、按 N 換音階聽差別；P 換成隨機／固定比較")
	print("[測試] ④ 往左撞牆：爆炸聲（自訂音檔）")
	print("[測試] ⑤ 按 K：播跳躍聲（自訂沒放音檔，改播預設）")
	print("[測試] ⑥ 編輯器裡點 Juice_Sound：看不到 custom_sound；sound 改成「自訂」就出現；pitch_mode 選「由低到高」才看得到 notes／steps／at_top／reset_delay，選「隨機」才看得到 pitch_random")

# 除錯按鍵：H 受傷、K 死亡、C 播金幣聲、P／N／M 換金幣聲的音高設定
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_H:
			print("[測試] 模擬受傷")
			_player.take_damage(1)
		KEY_K:
			print("[測試] 模擬死亡")
			_player.kill()
		KEY_C:
			_coin.play()
		KEY_P:
			_coin.pitch_mode = (_coin.pitch_mode + 1) % _MODES.size()
			print("[測試] 金幣聲音高模式：%s" % _MODES[_coin.pitch_mode])
		KEY_N:
			_coin.notes = (_coin.notes + 1) % _NOTES.size()
			print("[測試] 音階：%s" % _NOTES[_coin.notes])
		KEY_M:
			_coin.at_top = 1 - _coin.at_top
			print("[測試] 爬到最高之後：%s" % ("停在最高" if _coin.at_top == 0 else "從頭再來"))
