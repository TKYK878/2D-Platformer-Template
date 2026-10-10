@tool
extends JuiceBase

# 背景音樂：拖進 Player → Juice 底下，把音樂檔拖進 music，勾 play_on_start 就一開場播放。
# 想換歌：多放幾個 Juice_BGM，各放一首。timing 選某個時機（例如受傷時），那件事發生時就換成這一首；
# 也可以把任何訊號連到 play()／stop()。同一時間只會有一首在播，換歌時淡出淡入。
# 音樂走 BGM 匯流排，不受頓幀、過關畫面暫停影響；Juice 總開關關掉時淡出靜音，打開時淡回來接著播。

## 要播的音樂：從檔案系統把 .ogg／.mp3／.wav 拖進來（建議放在 _my/ 底下）
@export var music: AudioStream = null:
	set(value):
		music = value
		update_configuration_warnings()
## 勾選時一開場就播；不勾的話要等 timing 選的時機發生，或把訊號連到 play() 才會播
@export var play_on_start: bool = true
## 音量，1 是原本的大小
@export_range(0.0, 1.0) var volume: float = 0.6
## 淡入淡出要幾秒，0 是直接切換
@export_range(0.0, 3.0) var fade_time: float = 1.0
## 玩家死掉時音樂怎麼辦
@export_enum("繼續播", "暫停，重生後接著播", "重生時從頭播") var on_died: int = 0
## 過關時音樂怎麼辦
@export_enum("繼續播", "淡出", "馬上停") var on_cleared: int = 1

const _DIED_PAUSE := 1
const _DIED_RESTART := 2
const _CLEARED_FADE := 1
const _CLEARED_STOP := 2
# 淡到這個音量就算聽不到（線性音量）
const _SILENT := 0.0001

# 現在正在播的 BGM，所有 Juice_BGM 共用，用來保證同一時間只有一首
static var _current: Node = null
# 開場自動播的那一首，過關停掉音樂後再玩一次（重生）時播回這首
static var _start_bgm: Node = null
# 音樂是不是因為過關才停的，再玩一次時要播回開場那首
static var _stopped_by_clear: bool = false

var _audio: AudioStreamPlayer = null
var _fade: float = 0.0          # 淡入淡出進度，0 是無聲、1 是 volume 的音量
var _tween: Tween = null

# 停止播放這一首（淡出），可以把任何訊號連到這裡（訊號帶的參數會被忽略）
func stop(..._args: Array) -> void:
	if _audio == null:
		return
	if _current == self:
		_current = null
	_fade_to(0.0, true)

# 建立播放器、接上死亡／過關／總開關事件；勾了 play_on_start 就開始播
func _on_setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _audio == null:
		_audio = AudioStreamPlayer.new()
		_audio.bus = &"BGM"
		_audio.finished.connect(_on_finished)
		add_child(_audio)
	_listen(Events.player_died, _on_player_died)
	_listen(Events.level_cleared, _on_level_cleared)
	_listen(JuiceSwitch.toggled, _on_switch_toggled)
	if music == null:
		_warn("music 是空的，請把音樂檔從檔案系統拖進來；沒放之前不會播放")
		return
	if not play_on_start or not enabled or _current == self:
		return
	if _current != null and is_instance_valid(_current):
		_warn("「%s」已經勾了 play_on_start，同一時間只能播一首，這一首不會開場播放；想換歌請用 timing 或訊號連到 play()" % _current.name)
		return
	_start_bgm = self
	_stopped_by_clear = false
	_start()

# timing 選的時機發生、或有訊號連到 play() 時：換成這一首
func _on_play() -> void:
	_start()

# 播放這一首：原本在播的那首淡出，這首淡入；總開關關著的話先無聲地播
func _start() -> void:
	if music == null:
		_warn("music 是空的，請把音樂檔從檔案系統拖進來；這次不會播放")
		return
	if _current == self and _audio.playing:
		return
	if _current != null and is_instance_valid(_current) and _current != self:
		_current.stop()
	_current = self
	_audio.stream = music
	_audio.stream_paused = false
	_audio.play()
	_fade_to(_target_fade(), false)
	print("[%s] 開始播放背景音樂" % name)

# 關掉這個 Juice：正在播的話淡出靜音（音樂照樣往下走），turn_on 時淡回來
func turn_off(..._args: Array) -> void:
	super()
	if _current == self:
		_fade_to(_target_fade(), false)

# 打開這個 Juice：正在播的話淡回原本的音量
func turn_on(..._args: Array) -> void:
	super()
	if _current == self:
		_fade_to(_target_fade(), false)

# 拔掉組件或離開場景時放掉「正在播的 BGM」的位置，換別首或下一個關卡才能播
func _exit_tree() -> void:
	super()
	if _current == self:
		_current = null
	if _start_bgm == self:
		_start_bgm = null

# 音樂檔沒設定成循環的話，播完自己從頭再播
func _on_finished() -> void:
	if _current == self:
		_audio.play()

# 玩家死掉：依 on_died 決定暫停或照播
func _on_player_died() -> void:
	if _current == self and on_died == _DIED_PAUSE:
		_audio.stream_paused = true

# 玩家重生：過關後再玩一次就播回開場那首；暫停的接著播，選「重生時從頭播」的從頭淡入
func _on_player_respawned(p: Node) -> void:
	super(p)
	if _stopped_by_clear and _start_bgm == self:
		_stopped_by_clear = false
		_start()
		return
	if _current != self:
		return
	match on_died:
		_DIED_PAUSE:
			_audio.stream_paused = false
		_DIED_RESTART:
			_audio.stream_paused = false
			_audio.play()
			_fade = 0.0
			_fade_to(_target_fade(), false)

# 過關：依 on_cleared 決定淡出、馬上停或照播
func _on_level_cleared() -> void:
	if _current != self:
		return
	match on_cleared:
		_CLEARED_FADE:
			_stopped_by_clear = true
			stop()
		_CLEARED_STOP:
			_stopped_by_clear = true
			_current = null
			_kill_tween()
			_audio.stop()

# Juice 總開關切換：關掉淡出靜音（音樂照樣往下走），打開淡回原本的音量
func _on_switch_toggled(_on: bool) -> void:
	if _current == self:
		_fade_to(_target_fade(), false)

# 現在該有的音量進度：組件開著、總開關也開著才有聲音
func _target_fade() -> float:
	return 1.0 if _is_juice_on() else 0.0

# 把音量淡到 target（0～1），stop_after 為 true 時淡完就停掉；用真實時間，頓幀不會拖慢
func _fade_to(target: float, stop_after: bool) -> void:
	_kill_tween()
	if fade_time <= 0.0:
		_set_fade(target)
		if stop_after:
			_audio.stop()
		return
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_method(_set_fade, _fade, target, fade_time * absf(target - _fade))
	if stop_after:
		_tween.tween_callback(_audio.stop)

# 套用淡入淡出進度到播放器音量
func _set_fade(value: float) -> void:
	_fade = value
	_audio.volume_db = linear_to_db(maxf(volume * _fade, _SILENT))

# 停掉進行中的淡入淡出
func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

# 印出中文警告：push_warning 給偵錯器，printerr 讓輸出面板看得見
func _warn(message: String) -> void:
	push_warning("[%s] %s" % [name, message])
	printerr("⚠ [%s] %s" % [name, message])

# 落地力道對音樂沒有意義，follow_impact 一律藏起來
func _validate_property(property: Dictionary) -> void:
	super(property)
	if property.name == "follow_impact":
		property.usage &= ~PROPERTY_USAGE_EDITOR

# 編輯器裡就看得到設定錯誤：沒放音樂檔
func _get_configuration_warnings() -> PackedStringArray:
	if music == null:
		return PackedStringArray(["music 是空的，請把音樂檔（.ogg／.mp3／.wav）從檔案系統拖進來"])
	return PackedStringArray()
