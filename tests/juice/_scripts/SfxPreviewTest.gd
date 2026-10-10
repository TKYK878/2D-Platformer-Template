extends Node

# 手動驗證用：試聽 sfx/ 底下的 8 種內建音效，按 1～8 播放。

const _SOUNDS := [
	["跳躍", preload("res://sfx/jump.wav")],
	["落地", preload("res://sfx/land.wav")],
	["受傷", preload("res://sfx/hurt.wav")],
	["爆炸", preload("res://sfx/explosion.wav")],
	["撿東西", preload("res://sfx/pickup.wav")],
	["金幣", preload("res://sfx/coin.wav")],
	["雷射", preload("res://sfx/laser.wav")],
	["嗶", preload("res://sfx/beep.wav")],
]

var _player := AudioStreamPlayer.new()

# 建立播放器，印出操作說明
func _ready() -> void:
	_player.bus = &"SFX"
	add_child(_player)
	var names := []
	for i in _SOUNDS.size():
		names.append("%d＝%s" % [i + 1, _SOUNDS[i][0]])
	print("[測試] 按數字鍵試聽：%s" % "　".join(names))
	print("[測試] 每一種都要聽得出是什麼動作，音量差不多、沒有爆音或喀一聲")

# 數字鍵 1～8 播放對應的音效
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index: int = event.physical_keycode - KEY_1
	if index >= 0 and index < _SOUNDS.size():
		_player.stream = _SOUNDS[index][1]
		_player.play()
		print("[測試] 播放：%s" % _SOUNDS[index][0])
