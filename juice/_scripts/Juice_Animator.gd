@tool
extends JuiceBase

# 角色動畫：拖進 Player → Juice 底下就一直作用（持續型），依角色狀態自動切換動畫，轉向時角色圖跟著翻面。
# 播放器放在 Player → Visual 底下：先找 AnimationPlayer，沒有再找 AnimatedSprite2D。
# 動畫名稱照固定清單取：待機（必要）、跑步、跳起、落下、受傷、死亡、攻擊、特殊；缺的會用相近的代替或不播。
# 「特殊」要學員把訊號（例如二段跳卡的 air_jumped）連到 play_custom() 才會播。
# Juice 總開關關掉時停在待機、不翻面。

## 轉向時角色圖跟著翻面；圖朝左畫的，在 AnimatedSprite2D（或 Sprite2D）勾 Flip H 讓它朝右
@export var follow_facing: bool = true

const IDLE := "待機"
const RUN := "跑步"
const JUMP := "跳起"
const FALL := "落下"
const HURT := "受傷"
const DIE := "死亡"
const ATTACK := "攻擊"
const CUSTOM := "特殊"
const _NAMES := [IDLE, RUN, JUMP, FALL, HURT, DIE, ATTACK, CUSTOM]
# 跑步速度超過這個值（像素／秒）才算在跑，避免停下來前一點點滑動也播跑步
const _RUN_SPEED := 10.0
# AnimationPlayer 動畫改了這些屬性會跟 Juice（擠壓、閃色）打架
const _FIGHT_PROPERTIES := ["scale", "modulate"]
const _PLAYER_SCRIPT := "res://player/Player.gd"
# 編輯器裡每隔幾秒重新檢查黃色驚嘆號（學員一邊改動畫，驚嘆號一邊更新）
const _CHECK_SECONDS := 1.0

var _anim_player: AnimationPlayer = null
var _sprite: AnimatedSprite2D = null
var _flippers: Array = []  # 要跟著翻面的圖：[節點, 原本的 Flip H]
var _ok := false  # 找到播放器而且有「待機」
var _facing := 1
var _current := ""  # 現在播的動畫
var _oneshot := ""  # 正在播一次的動畫（受傷、攻擊、特殊），播完回到原本的狀態
var _oneshot_left := 0.0
var _dead := false
var _die_left := 0.0  # 死亡動畫還要播幾秒，播完停在最後一格
var _warned_custom := false
var _check_timer := 0.0

# 持續型：拖進來就一直作用
func _is_continuous() -> bool:
	return true

# 找播放器、檢查動畫名稱，接上受傷、死亡、重生、轉向與攻擊能力的 attacked
func _on_setup() -> void:
	_find_players(player.visual)
	var problem := _setup_problem(player.visual)
	if problem != "":
		_warn(problem)
	for w in _typo_warnings() + _fight_warnings():
		_warn(w)
	_ok = problem == ""
	_listen(player.hurt, func(): _play_once(HURT))
	_listen(player.died, _on_died)
	_listen(player.direction_changed, func(dir: int): _facing = dir)
	if player.has_node("Abilities"):
		for ability in player.get_node("Abilities").get_children():
			if ability.has_signal("attacked"):
				_listen(ability.attacked, func(): _play_once(ATTACK))
	_current = ""
	_update_state()

# 播一次「特殊」動畫，播完回到原本的狀態；把任何訊號（例如二段跳卡的 air_jumped）連到這裡（訊號帶的參數會被忽略）
func play_custom(..._args: Array) -> void:
	if not _ok or _dead or not _is_juice_on():
		return
	if not _has(CUSTOM):
		if not _warned_custom:
			_warned_custom = true
			_warn("有訊號連到 play_custom()，但沒有「特殊」動畫（名稱要一字不差），現在有的：%s" % NameCheck.list_text(_anim_names()))
		return
	_play_once(CUSTOM)

# 重生：清掉一次型動畫與死亡狀態，回到待機
func _on_reset() -> void:
	_dead = false
	_die_left = 0.0
	_oneshot = ""
	_oneshot_left = 0.0
	if _ok:
		_play(IDLE, true)

# 每一幀依角色狀態切換動畫、翻面；編輯器裡定時重新檢查黃色驚嘆號
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_check_timer += delta
		if _check_timer >= _CHECK_SECONDS:
			_check_timer = 0.0
			update_configuration_warnings()
		return
	if not _ok or not is_instance_valid(player):
		return
	if not _is_juice_on():
		_set_flip(false)
		if _current != IDLE:
			_play(IDLE, true)
		return
	_update_flip()
	if _dead:
		_update_die(delta)
		return
	if _oneshot != "":
		_oneshot_left -= delta
		if _oneshot_left > 0.0:
			return
		_oneshot = ""
	_update_state()

# 依角色在地上還是空中、往上還是往下、有沒有在跑，播對應的動畫（缺的用相近的代替）
func _update_state() -> void:
	if not _ok or not is_instance_valid(player):
		return
	var want := IDLE
	if not player.is_on_ground():
		want = JUMP if player.velocity.dot(player.up_direction) > 0.0 else FALL
	elif absf(player.velocity.x) > _RUN_SPEED:
		want = RUN
	_play(_fallback(want), false)

# 缺的動畫用哪一段代替：落下 → 跳起 → 待機，跑步、跳起 → 待機
func _fallback(anim_name: String) -> String:
	if _has(anim_name):
		return anim_name
	if anim_name == FALL and _has(JUMP):
		return JUMP
	return IDLE

# 播一次動畫（受傷、攻擊、特殊），播完回到原本的狀態；沒有這段就不播
func _play_once(anim_name: String) -> void:
	if not _ok or _dead or not _is_juice_on() or not _has(anim_name):
		return
	_oneshot = anim_name
	_oneshot_left = _length(anim_name)
	_play(anim_name, true)

# 死掉：有「死亡」動畫就播一次、停在最後一格；沒有就停在原本的樣子
func _on_died() -> void:
	_dead = true
	_oneshot = ""
	if _ok and _is_juice_on() and _has(DIE):
		_die_left = _length(DIE)
		_play(DIE, true)

# 死亡動畫播完停在最後一格（就算勾了循環也不再重播）
func _update_die(delta: float) -> void:
	if _die_left <= 0.0:
		return
	_die_left -= delta
	if _die_left > 0.0:
		return
	if _anim_player != null:
		_anim_player.seek(_length(DIE), true)
		_anim_player.pause()
	elif _sprite != null:
		_sprite.frame = _sprite.sprite_frames.get_frame_count(DIE) - 1
		_sprite.pause()

# 拔掉組件時把角色圖翻回原本的方向，再交給基底拔掉事件
func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		_set_flip(false)
	super()

# 依朝向翻面：自動奔跑卡用 Visual 左右翻的時候，已經翻過了就不再翻一次
func _update_flip() -> void:
	if not follow_facing:
		_set_flip(false)
		return
	var visual_flipped: bool = player.visual != null and player.visual.scale.x < 0.0
	_set_flip((_facing < 0) != visual_flipped)

# 把要翻面的圖翻過去（flipped）或回到原本的 Flip H
func _set_flip(flipped: bool) -> void:
	for pair in _flippers:
		if is_instance_valid(pair[0]):
			pair[0].flip_h = pair[1] != flipped

# 播一段動畫；已經在播同一段就不重播（restart 時從頭播）
func _play(anim_name: String, restart: bool) -> void:
	if anim_name == _current and not restart:
		return
	_current = anim_name
	if _anim_player != null:
		_anim_player.stop()
		_anim_player.play(anim_name)
	elif _sprite != null:
		_sprite.stop()
		_sprite.play(anim_name)

# 有沒有這段動畫
func _has(anim_name: String) -> bool:
	if _anim_player != null:
		return _anim_player.has_animation(anim_name)
	if _sprite != null and _sprite.sprite_frames != null:
		return _sprite.sprite_frames.has_animation(anim_name)
	return false

# 這段動畫播一次要幾秒
func _length(anim_name: String) -> float:
	if _anim_player != null and _anim_player.has_animation(anim_name):
		return _anim_player.get_animation(anim_name).length / maxf(absf(_anim_player.speed_scale), 0.01)
	if _sprite == null or _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(anim_name):
		return 0.0
	var frames := _sprite.sprite_frames
	var fps := frames.get_animation_speed(anim_name) * absf(_sprite.speed_scale)
	if fps <= 0.0:
		return 0.0
	var total := 0.0
	for i in frames.get_frame_count(anim_name):
		total += frames.get_frame_duration(anim_name, i)
	return total / fps

# 在 Visual 底下找播放器（先找 AnimationPlayer，沒有再找 AnimatedSprite2D），記下要翻面的圖
func _find_players(visual: Node) -> void:
	_anim_player = null
	_sprite = null
	_flippers.clear()
	if visual == null:
		return
	var players := visual.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim_player = players[0]
	else:
		var sprites := visual.find_children("*", "AnimatedSprite2D", true, false)
		if not sprites.is_empty():
			_sprite = sprites[0]
	for n in visual.find_children("*", "", true, false):
		if n is Sprite2D or n is AnimatedSprite2D:
			_flippers.append([n, n.flip_h])

# 現在有哪些動畫（AnimationPlayer 的 RESET 不算）
func _anim_names() -> Array:
	var names: Array = []
	if _anim_player != null:
		for n in _anim_player.get_animation_list():
			if n != "RESET":
				names.append(String(n))
	elif _sprite != null and _sprite.sprite_frames != null:
		for n in _sprite.sprite_frames.get_animation_names():
			names.append(String(n))
	return names

# 播放器與「待機」的問題（找不到 Visual、找不到播放器、缺待機），沒問題回傳空字串
func _setup_problem(visual: Node) -> String:
	if visual == null:
		return "找不到 Player 的 Visual 節點，角色動畫不會播"
	if _anim_player == null and _sprite == null:
		return "Player → Visual 底下沒有 AnimatedSprite2D 或 AnimationPlayer，角色動畫不會播：把 Visual 底下的 Sprite2D 換成 AnimatedSprite2D 再做動畫"
	if _sprite != null and _sprite.sprite_frames == null:
		return "AnimatedSprite2D 的 Sprite Frames 是空的：在 Inspector 的 Sprite Frames 選「新增 SpriteFrames」再做動畫"
	if _has(IDLE):
		return ""
	var names := _anim_names()
	var message := "缺少「待機」動畫（名稱要一字不差），角色動畫不會播；現在有的：%s" % NameCheck.list_text(names)
	var similar := _similar_name(IDLE, names)
	if similar != "":
		message += "。「%s」是不是要改名成「待機」？" % similar
	return message

# 名字打錯的動畫：不在固定清單裡、但跟清單裡某個名稱很像（例如「跑」→「跑步」），每個一行
func _typo_warnings() -> Array:
	var result: Array = []
	for n in _anim_names():
		if n in _NAMES:
			continue
		for wanted in _NAMES:
			if _has(wanted):
				continue
			if _similar_name(wanted, [n]) != "":
				result.append("動畫「%s」是不是要改名成「%s」？名稱不在清單裡的動畫不會自動播（清單：%s）" % [n, wanted, NameCheck.list_text(_NAMES)])
				break
	return result

# 找跟必要名稱很像的動畫名稱：差一個字，或是互相包含（「跑」→「跑步」）
func _similar_name(wanted: String, names: Array) -> String:
	var similar := NameCheck.find_similar(wanted, names)
	if similar != "":
		return similar
	for n in names:
		var clean := NameCheck.clean(str(n))
		if clean != "" and (wanted.contains(clean) or clean.contains(wanted)):
			return str(n)
	return ""

# AnimationPlayer 的動畫改了圖的大小或顏色：會跟擠壓、閃色這些 Juice 打架，每段動畫一行
func _fight_warnings() -> Array:
	var result: Array = []
	if _anim_player == null:
		return result
	for anim_name in _anim_names():
		var anim := _anim_player.get_animation(anim_name)
		for i in anim.get_track_count():
			var path := anim.track_get_path(i)
			if path.get_subname_count() > 0 and String(path.get_subname(0)) in _FIGHT_PROPERTIES:
				result.append("動畫「%s」改了「%s」：會跟擠壓、閃色這些 Juice 打架，動畫只改 frame（第幾格），不要改大小和顏色" % [anim_name, path.get_subname(0)])
				break
	return result

# 黃色驚嘆號：找不到播放器、缺待機、名稱打錯、動畫改了大小或顏色
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_inside_tree():
		return warnings
	var host := _editor_player()
	if host == null:
		warnings.append("要放在 Player → Juice 底下才會作用")
		return warnings
	var visual: Node = host.get_node_or_null("Visual")
	_find_players(visual)
	var problem := _setup_problem(visual)
	if problem != "":
		warnings.append(problem)
	warnings.append_array(_typo_warnings())
	warnings.append_array(_fight_warnings())
	return warnings

# 編輯器裡找包住自己的 Player（從場景最上層往下找，不往上爬）
func _editor_player() -> Node:
	var root := get_tree().edited_scene_root
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var node_script: Script = node.get_script()
		if node_script != null and node_script.resource_path == _PLAYER_SCRIPT and node.is_ancestor_of(self):
			return node
		stack.append_array(node.get_children())
	return null

# 印中文警告到輸出面板
func _warn(message: String) -> void:
	push_warning("[角色動畫] %s" % message)
	printerr("⚠ [角色動畫] %s" % message)
