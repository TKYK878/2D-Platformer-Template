extends Node2D

# 手動驗證用：背景音樂。專案裡沒有音樂檔，所以這裡用程式合成兩段循環的旋律塞進 BGM_Calm／BGM_Tense／BGM_Second。
# BGM_Calm 開場播（死掉暫停、過關淡出）；BGM_Tense 受傷時換成它（死掉重生從頭播、過關馬上停）；
# BGM_Second 也勾了開場播，應該被擋下來並印警告；BGM_Empty 沒放音樂，應該有警告。

const _RATE := 22050
const _NOTE_SEC := 0.25
const _CALM_NOTES := [60, 64, 67, 72, 67, 64]           # Do Mi Sol Do Sol Mi，慢慢的
const _TENSE_NOTES := [69, 70, 69, 76, 69, 70, 69, 75]  # 高一點、半音晃來晃去

@onready var _player: CharacterBody2D = $Player
@onready var _calm: Node = $Player/Juice/BGM_Calm
@onready var _tense: Node = $Player/Juice/BGM_Tense
@onready var _empty: Node = $Player/Juice/BGM_Empty

# 在 Player 幫 Juice setup 之前把合成的旋律放進去，開場播放才拿得到音樂
func _enter_tree() -> void:
	$Player/Juice/BGM_Calm.music = _make_loop(_CALM_NOTES, 0.5)
	$Player/Juice/BGM_Tense.music = _make_loop(_TENSE_NOTES, 1.0)
	$Player/Juice/BGM_Second.music = _make_loop(_TENSE_NOTES, 2.0)

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳、H 受傷、K 死亡、C 假裝過關、1 播 Calm、2 播 Tense、3 全部停、4 播 BGM_Empty、0 Juice 總開關")
	print("[測試] ⓪ 開場：聽到慢慢的 Do Mi Sol（BGM_Calm）；輸出面板有 BGM_Second 被擋下、BGM_Empty 沒放音樂兩則警告")
	print("[測試] ① 按 H：淡出 Calm、淡入比較高的 Tense（timing 受傷時）；按 1／2 來回切換，3 全部淡出停掉")
	print("[測試] ② 播 Calm 時按 K：死掉時音樂停住，重生後接著播；播 Tense 時按 K：死掉照播，重生時從頭播")
	print("[測試] ③ 播 Calm 時按 C：音樂淡出；播 Tense 時按 C：馬上停；之後按 K 死一次（假裝再玩一次），重生時播回 Calm")
	print("[測試] ④ 按 0：音樂淡出靜音，再按 0 淡回來接著播；按 4：印 music 空白警告，原本的照播")
	print("[測試] ⑤ 下方「音訊」面板：聲音只跑在 BGM 和 Master 上；編輯器裡 BGM_Empty 有黃色驚嘆號，看不到 follow_impact")

# 除錯按鍵：H 受傷、K 死亡、C 過關、1～4 直接叫 BGM
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
			print("[測試] 假裝過關")
			Events.level_cleared.emit()
		KEY_1: _calm.play()
		KEY_2: _tense.play()
		KEY_3:
			_calm.stop()
			_tense.stop()
		KEY_4: _empty.play()

# 用方波合成一段會循環的旋律，pitch 是整段音高倍率
func _make_loop(notes: Array, pitch: float) -> AudioStreamWAV:
	var frames_per_note := int(_RATE * _NOTE_SEC)
	var data := PackedByteArray()
	data.resize(notes.size() * frames_per_note * 2)
	var i := 0
	for n in notes:
		var freq := 440.0 * pow(2.0, (n - 69) / 12.0) * pitch
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
