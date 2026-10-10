@tool
extends JuiceBase

# 音效：觸發時播放一個音效。拖進 Player → Juice 底下就能用，預設是跳躍時播跳躍聲。
# 想用自己的音檔：sound 選「自訂」，把音檔（.wav／.ogg／.mp3，建議放在 _my/ 底下）從檔案系統拖進 custom_sound。
# 音效不受頓幀影響，頓幀時照常播完；遊戲暫停時要不要播完由 play_when_paused 決定。

## 要播哪一種內建音效；選「自訂」可以放自己的音檔
@export_enum("跳躍", "落地", "受傷", "爆炸", "撿東西", "金幣", "雷射", "嗶", "自訂") var sound: int = 0:
	set(value):
		sound = value
		notify_property_list_changed()
		update_configuration_warnings()
## 自己的音檔：從檔案系統把 .wav／.ogg／.mp3 拖進來
@export var custom_sound: AudioStream = null:
	set(value):
		custom_sound = value
		update_configuration_warnings()
## 音量，1 是原本的大小
@export_range(0.0, 1.0) var volume: float = 0.8
## 音高怎麼變：隨機＝每次高一點低一點；固定＝每次都一樣；由低到高＝連續觸發時一聲比一聲高（像連續吃金幣），停一下就從頭開始
@export_enum("隨機", "固定", "由低到高") var pitch_mode: int = 0:
	set(value):
		pitch_mode = value
		notify_property_list_changed()
## 每次播放時音高隨機變化的程度，0 是每次都一樣；有一點變化連續播才不會覺得很機械
@export_range(0.0, 0.5) var pitch_random: float = 0.1
## 由低到高要照哪一種音階爬：五聲音階最和諧、怎麼疊都好聽；大調音階是 Do Re Mi；半音是一小格一小格爬；琶音是 Do Mi Sol 跳著爬
@export_enum("五聲音階", "大調音階", "半音", "琶音") var notes: int = 0
## 爬幾聲到最高（第一聲是原本的音高）
@export_range(2, 12) var steps: int = 8
## 爬到最高之後：停在最高一直播最高音，或從最低的再爬一次
@export_enum("停在最高", "從頭再來") var at_top: int = 0
## 多久沒觸發就回到最低的音（秒）
@export_range(0.1, 2.0) var reset_delay: float = 0.6
## 勾選時遊戲暫停（過關畫面、暫停選單）也會把聲音播完；不勾的話暫停時聲音停住，等遊戲繼續才接著播。觸發時機選「過關時」一律播完
@export var play_when_paused: bool = true:
	set(value):
		play_when_paused = value
		_apply_pause_mode()

const _SOUND_CUSTOM := 8
const _PITCH_RANDOM := 0
const _PITCH_RISING := 2
const _AT_TOP_STAY := 0
# 每種音階一個八度裡的音（跟第一聲差幾個半音），超過一個八度就整組往上疊 12
const _NOTE_TABLES := [
	[0, 2, 4, 7, 9],
	[0, 2, 4, 5, 7, 9, 11],
	[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
	[0, 4, 7],
]
# 最高只爬到比原本高兩個八度，再高聲音會變得很尖
const _MAX_SEMITONES := 24
const _SOUNDS := [
	preload("res://sfx/jump.wav"),
	preload("res://sfx/land.wav"),
	preload("res://sfx/hurt.wav"),
	preload("res://sfx/explosion.wav"),
	preload("res://sfx/pickup.wav"),
	preload("res://sfx/coin.wav"),
	preload("res://sfx/laser.wav"),
	preload("res://sfx/beep.wav"),
]
# 同一個組件最多同時疊幾個聲音（連續觸發時前一個還沒播完）
const _MAX_OVERLAP := 4

var _audio: AudioStreamPlayer = null
var _step: int = 0          # 由低到高：下一聲是第幾聲（從 0 開始）
var _last_play_sec: float = -100.0

# 建立播放器、設定暫停時要不要照樣播、決定要播哪個音效；選「自訂」卻沒放音檔就警告並改播跳躍聲
func _on_setup() -> void:
	if _audio == null:
		_audio = AudioStreamPlayer.new()
		_audio.max_polyphony = _MAX_OVERLAP
		_audio.bus = &"SFX"
		add_child(_audio)
	_apply_pause_mode()
	if sound == _SOUND_CUSTOM and custom_sound == null:
		push_warning("[%s] sound 選了「自訂」，但 custom_sound 是空的，請把音檔拖進來；先改播跳躍聲" % name)
		printerr("⚠ [%s] sound 選了「自訂」，但 custom_sound 是空的，請把音檔拖進來；先改播跳躍聲" % name)
	_audio.stream = _get_stream()

# 播放一次，音量照設定、音高照 pitch_mode 決定
func _on_play() -> void:
	_audio.volume_db = linear_to_db(maxf(volume * minf(_trigger_power, 1.5), 0.0001))
	_audio.pitch_scale = _next_pitch()
	_audio.play()

# 算出這一聲的音高倍率：隨機在 1 附近亂跳；固定是 1；由低到高照音階一聲一聲往上（用真實時間判斷多久沒觸發）
func _next_pitch() -> float:
	match pitch_mode:
		_PITCH_RANDOM:
			return 1.0 + randf_range(-pitch_random, pitch_random)
		_PITCH_RISING:
			var now := Time.get_ticks_msec() / 1000.0
			if now - _last_play_sec > reset_delay:
				_step = 0
			_last_play_sec = now
			var semitones := _semitones_at(_step)
			_step += 1
			if _step >= steps or _semitones_at(_step) > _MAX_SEMITONES:
				_step = _step - 1 if at_top == _AT_TOP_STAY else 0
			return pow(2.0, semitones / 12.0)
	return 1.0

# 回傳音階上第 index 聲比第一聲高幾個半音
func _semitones_at(index: int) -> int:
	var table: Array = _NOTE_TABLES[notes]
	return table[index % table.size()] + 12 * floori(float(index) / table.size())

# 停掉還在播的聲音，由低到高回到最低的音
func _on_reset() -> void:
	_step = 0
	if _audio:
		_audio.stop()

# 回傳要播的音效：自訂而且有放音檔就用學員的，否則用內建的（自訂但空白時用跳躍聲）
func _get_stream() -> AudioStream:
	if sound == _SOUND_CUSTOM:
		return custom_sound if custom_sound else _SOUNDS[0]
	return _SOUNDS[sound]

# 依 play_when_paused 決定播放器暫停時要不要照樣播；「過關時」一律照樣播，不然過關畫面一暫停，過關音效就發不出來
func _apply_pause_mode() -> void:
	if _audio == null:
		return
	var keep_playing := play_when_paused or timing == TIMING_LEVEL_CLEARED
	_audio.process_mode = Node.PROCESS_MODE_ALWAYS if keep_playing else Node.PROCESS_MODE_INHERIT

# 只顯示用得到的欄位：「過關時」不顯示 play_when_paused；選「自訂」才有 custom_sound；隨機才有 pitch_random；由低到高才有音階那幾個
func _validate_property(property: Dictionary) -> void:
	super(property)
	var should_hide := false
	match property.name:
		"custom_sound": should_hide = sound != _SOUND_CUSTOM
		"pitch_random": should_hide = pitch_mode != _PITCH_RANDOM
		"notes", "steps", "at_top", "reset_delay": should_hide = pitch_mode != _PITCH_RISING
		"play_when_paused": should_hide = timing == TIMING_LEVEL_CLEARED
	if should_hide:
		property.usage &= ~PROPERTY_USAGE_EDITOR

# 編輯器裡就看得到設定錯誤：選了「自訂」卻沒放音檔
func _get_configuration_warnings() -> PackedStringArray:
	if sound == _SOUND_CUSTOM and custom_sound == null:
		return PackedStringArray(["sound 選了「自訂」，但 custom_sound 是空的，請把音檔從檔案系統拖進來；沒放之前先播跳躍聲"])
	return PackedStringArray()
