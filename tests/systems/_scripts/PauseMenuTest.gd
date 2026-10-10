extends Node2D

# 手動驗證用：暫停選單（自動載入，每一關都有）。BGM 放一段合成的循環旋律、Juice_Sound 跳躍時播跳躍聲，
# 方便聽音量拉桿的效果；右邊有終點跟過關畫面，用來確認過關畫面顯示時不會叫出暫停選單。

const _RATE := 22050
const _NOTE_SEC := 0.25
const _NOTES := [60, 64, 67, 72, 67, 64]

# 在 Player 幫 Juice setup 之前把合成的旋律放進去
func _enter_tree() -> void:
	$Player/Juice/BGM.music = _make_loop(_NOTES)

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] ① 按 Esc 或 P：遊戲停住、跳出暫停選單（主音量／音效／音樂三條拉桿、繼續遊戲、整關重來、離開遊戲）")
	print("[測試] ② 拉「音樂」到 0：旋律消失；拉「音效」時會聽到試聽音效跟著變大變小（拖著拉不會疊成一團），拉到 0：沒有聲音、跳躍聲也消失；「主音量」兩個一起變")
	print("[測試] ③ 鍵盤也能操作：上下選、左右拉拉桿、Enter 按按鈕；再按一次 Esc／P 或「繼續遊戲」回到遊戲")
	print("[測試] ④ 「整關重來」：玩家回到起點；「離開遊戲」：關掉遊戲")
	print("[測試] ⑤ 調完音量關掉遊戲再按 F6：拉桿位置跟音量跟上次一樣")
	print("[測試] ⑥ 走到右邊終點：過關畫面出現後按 Esc／P 不會跳出暫停選單；按 R 再玩一次照常")

# 用方波合成一段會循環的旋律
func _make_loop(notes: Array) -> AudioStreamWAV:
	var frames_per_note := int(_RATE * _NOTE_SEC)
	var data := PackedByteArray()
	data.resize(notes.size() * frames_per_note * 2)
	var i := 0
	for n in notes:
		var freq := 440.0 * pow(2.0, (n - 69) / 12.0) * 0.5
		for f in frames_per_note:
			var t := float(f) / _RATE
			var env := 1.0 - float(f) / frames_per_note
			var wave := 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
			data.encode_s16(i, int(wave * env * 6000.0))
			i += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = _RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = notes.size() * frames_per_note
	return wav
