@tool
extends JuiceBase

# 角色動畫：拖進 Player → Juice 底下就一直作用（持續型），依角色狀態自動切換動畫，轉向時角色圖跟著翻面。
# 播放器放在 Player → Visual 底下：先找 AnimationPlayer，沒有再找 AnimatedSprite2D。
# 每個狀態播哪段動畫用下拉選（自動列出做好的動畫），動畫名稱隨便取；選「（自動）」會認常見的中英文名字（idle／待機、run／跑步…）。
# 一次型動畫（受傷、攻擊、落地、轉向…）播完回到原本的狀態；「特殊」要把訊號（例如二段跳卡的 air_jumped）連到 play_custom() 才會播。
# Juice 總開關關掉時停在待機、不翻面。

## 轉向時角色圖跟著翻面；圖朝左畫的，在 AnimatedSprite2D（或 Sprite2D）勾 Flip H 讓它朝右
@export var follow_facing: bool = true

@export_group("動畫")
## 站著不動時播哪段（一定要有）；（自動）會找 idle、待機、stand、default 這類名字
@export var idle_animation: String = AUTO
## 在地上跑的時候；沒有就播待機
@export var run_animation: String = AUTO
## 往上跳的時候；沒有就播待機
@export var jump_animation: String = AUTO
## 往下掉的時候；沒有就播跳起
@export var fall_animation: String = AUTO
## 受傷時播一次
@export var hurt_animation: String = AUTO
## 死掉時播一次，停在最後一格
@export var die_animation: String = AUTO
## 攻擊時播一次（Abilities 底下的近戰、遠程攻擊）
@export var attack_animation: String = AUTO
## 把訊號連到 play_custom() 時播一次（例如二段跳卡的 air_jumped）
@export var custom_animation: String = AUTO

@export_group("一次型動畫")
## 落地時播一次
@export var land_animation: String = NONE
## 轉向時播一次
@export var turn_animation: String = NONE
## 重生時播一次
@export var respawn_animation: String = NONE
## 撞牆時播一次
@export var wall_animation: String = NONE
## 撞天花板時播一次
@export var ceiling_animation: String = NONE
## 從站著開始跑的時候播一次
@export var start_move_animation: String = NONE
## 一次型動畫播到一半，又有別的一次型動畫（例如攻擊到一半受傷）時，要不要換過去；不勾就把正在播的播完
@export var can_interrupt: bool = true

@export_group("跑步")
## 跑多快才算在跑（像素／秒），太小的話停下來前一點點滑動也會播跑步
@export_range(0.0, 200.0, 1.0) var min_run_speed: float = 10.0
## 跑步動畫的播放速度跟著跑的速度：慢慢走播得慢、全速跑播原本的速度
@export var run_speed_follow: bool = false

const AUTO := "（自動）"
const NONE := "（沒有）"
# 每個狀態：[欄位名稱, （自動）時認得的名字（不分大小寫）]
const _STATES := {
	"idle": ["idle_animation", ["idle", "待機", "stand", "站立", "default", "平常"]],
	"run": ["run_animation", ["run", "跑步", "跑", "running", "walk", "走路", "move"]],
	"jump": ["jump_animation", ["jump", "跳起", "跳", "jumping"]],
	"fall": ["fall_animation", ["fall", "落下", "falling", "下落"]],
	"hurt": ["hurt_animation", ["hurt", "受傷", "hit", "damage"]],
	"die": ["die_animation", ["die", "死亡", "death", "dead"]],
	"attack": ["attack_animation", ["attack", "攻擊", "atk", "slash"]],
	"custom": ["custom_animation", ["custom", "特殊", "special"]],
	"land": ["land_animation", ["land", "落地", "landing"]],
	"turn": ["turn_animation", ["turn", "轉向"]],
	"respawn": ["respawn_animation", ["respawn", "重生", "spawn"]],
	"wall": ["wall_animation", ["wall", "撞牆"]],
	"ceiling": ["ceiling_animation", ["ceiling", "撞天花板"]],
	"start_move": ["start_move_animation", ["start", "起跑", "開始移動"]],
}
# 跑步動畫的播放速度最慢、最快幾倍（run_speed_follow 用）
const _RUN_FOLLOW_MIN := 0.3
const _RUN_FOLLOW_MAX := 1.5
# AnimationPlayer 動畫改了這些屬性會跟 Juice（擠壓、閃色）打架
const _FIGHT_PROPERTIES := ["scale", "modulate"]
const _PLAYER_SCRIPT := "res://player/Player.gd"
# 編輯器裡每隔幾秒重新檢查黃色驚嘆號（學員一邊改動畫，驚嘆號一邊更新）
const _CHECK_SECONDS := 1.0

var _anim_player: AnimationPlayer = null
var _sprite: AnimatedSprite2D = null
var _flippers: Array = []  # 要跟著翻面的圖：[節點, 原本的 Flip H]
var _ok := false  # 找到播放器而且有待機動畫
var _resolved := {}  # 狀態 -> 實際要播的動畫名稱（沒有就是空字串）
var _facing := 1
var _current := ""  # 現在播的動畫
var _oneshot := ""  # 正在播一次的動畫，播完回到原本的狀態
var _oneshot_left := 0.0
var _dead := false
var _die_left := 0.0  # 死亡動畫還要播幾秒，播完停在最後一格
var _warned_custom := false
var _check_timer := 0.0
var _last_names: Array = []  # 編輯器裡上次看到的動畫清單，變了才更新下拉選單

# 持續型：拖進來就一直作用
func _is_continuous() -> bool:
	return true

# 找播放器、決定每個狀態播哪段，接上受傷、死亡、重生、轉向、落地、撞牆、撞天花板、起跑與攻擊能力的 attacked
func _on_setup() -> void:
	_find_players(player.visual)
	_resolve_all()
	var problem := _setup_problem(player.visual)
	if problem != "":
		_warn(problem)
	for w in _missing_warnings() + _fight_warnings():
		_warn(w)
	_ok = problem == ""
	_listen(player.hurt, func(): _play_once("hurt"))
	_listen(player.died, _on_died)
	_listen(player.direction_changed, _on_direction_changed)
	_listen(player.landed, func(_force: float): _play_once("land"))
	_listen(player.wall_hit, func(): _play_once("wall"))
	_listen(player.ceiling_hit, func(): _play_once("ceiling"))
	_listen(player.started_moving, func(): _play_once("start_move"))
	_listen(Events.player_respawned, func(_p): _play_once("respawn"))
	if player.has_node("Abilities"):
		for ability in player.get_node("Abilities").get_children():
			if ability.has_signal("attacked"):
				_listen(ability.attacked, func(): _play_once("attack"))
	_current = ""
	_update_state()

# 播一次「特殊」動畫，播完回到原本的狀態；把任何訊號（例如二段跳卡的 air_jumped）連到這裡（訊號帶的參數會被忽略）
func play_custom(..._args: Array) -> void:
	if not _ok or _dead or not _is_juice_on():
		return
	if _anim("custom") == "":
		if not _warned_custom:
			_warned_custom = true
			_warn("有訊號連到 play_custom()，但 custom_animation 沒有選動畫；現在有的：%s" % NameCheck.list_text(_anim_names()))
		return
	_play_once("custom")

# 這個狀態（idle、run、jump…）實際會播哪段動畫，沒有就回傳空字串；練習關的告示牌用來檢查
func resolved_animation(state: String) -> String:
	return _anim(state)

# 重生：清掉一次型動畫與死亡狀態，回到待機
func _on_reset() -> void:
	_dead = false
	_die_left = 0.0
	_oneshot = ""
	_oneshot_left = 0.0
	_set_speed(1.0)
	if _ok:
		_play(_anim("idle"), true)

# 每一幀依角色狀態切換動畫、翻面；編輯器裡定時重新檢查黃色驚嘆號
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_check_timer += delta
		if _check_timer >= _CHECK_SECONDS:
			_check_timer = 0.0
			update_configuration_warnings()
			var names := _anim_names()
			if names != _last_names:
				_last_names = names
				notify_property_list_changed()
		return
	if not _ok or not is_instance_valid(player):
		return
	if not _is_juice_on():
		_set_flip(false)
		if _current != _anim("idle"):
			_play(_anim("idle"), true)
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
	var want := "idle"
	if not player.is_on_ground():
		want = "jump" if player.velocity.dot(player.up_direction) > 0.0 else "fall"
	elif absf(player.velocity.x) > min_run_speed:
		want = "run"
	var anim_name := _fallback(want)
	_play(anim_name, false)
	if want == "run" and run_speed_follow and anim_name == _anim("run"):
		_set_speed(clampf(absf(player.velocity.x) / maxf(player.move_speed, 1.0), _RUN_FOLLOW_MIN, _RUN_FOLLOW_MAX))
	else:
		_set_speed(1.0)

# 缺的動畫用哪一段代替：落下 → 跳起 → 待機，跑步、跳起 → 待機
func _fallback(state: String) -> String:
	if _anim(state) != "":
		return _anim(state)
	if state == "fall" and _anim("jump") != "":
		return _anim("jump")
	return _anim("idle")

# 轉向：記下朝向，有選轉向動畫就播一次
func _on_direction_changed(dir: int) -> void:
	_facing = dir
	_play_once("turn")

# 播一次這個狀態的動畫，播完回到原本的狀態；沒選動畫就不播；正在播別的一次型動畫、又不能打斷時不播
func _play_once(state: String) -> void:
	var anim_name := _anim(state)
	if not _ok or _dead or not _is_juice_on() or anim_name == "":
		return
	if _oneshot != "" and not can_interrupt:
		return
	_oneshot = anim_name
	_oneshot_left = _length(anim_name)
	_set_speed(1.0)
	_play(anim_name, true)

# 死掉：有死亡動畫就播一次、停在最後一格；沒有就停在原本的樣子
func _on_died() -> void:
	_dead = true
	_oneshot = ""
	_set_speed(1.0)
	if _ok and _is_juice_on() and _anim("die") != "":
		_die_left = _length(_anim("die"))
		_play(_anim("die"), true)

# 死亡動畫播完停在最後一格（就算勾了循環也不再重播）
func _update_die(delta: float) -> void:
	if _die_left <= 0.0:
		return
	_die_left -= delta
	if _die_left > 0.0:
		return
	var die_name := _anim("die")
	if _anim_player != null:
		_anim_player.seek(_length(die_name), true)
		_anim_player.pause()
	elif _sprite != null:
		_sprite.frame = _sprite.sprite_frames.get_frame_count(die_name) - 1
		_sprite.pause()

# 拔掉組件時把角色圖翻回原本的方向、播放速度回到原本的，再交給基底拔掉事件
func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		_set_flip(false)
		_set_speed(1.0)
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

# 播放速度（跑步跟著速度用）；AnimationPlayer、AnimatedSprite2D 都用 speed_scale
func _set_speed(value: float) -> void:
	if _anim_player != null and is_instance_valid(_anim_player):
		_anim_player.speed_scale = value
	elif _sprite != null and is_instance_valid(_sprite):
		_sprite.speed_scale = value

# 播一段動畫；已經在播同一段就不重播（restart 時從頭播）
func _play(anim_name: String, restart: bool) -> void:
	if anim_name == "" or (anim_name == _current and not restart):
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
	if anim_name == "":
		return false
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

# 這個狀態實際要播的動畫名稱（沒有就是空字串）
func _anim(state: String) -> String:
	return _resolved.get(state, "")

# 每個狀態決定播哪段：選了動畫就用選的（不見了就當沒有），（自動）就照常見名字找，（沒有）就不播
func _resolve_all() -> void:
	_resolved.clear()
	var names := _anim_names()
	for state in _STATES:
		var chosen: String = get(_STATES[state][0])
		if chosen == NONE:
			_resolved[state] = ""
		elif chosen == AUTO or chosen == "":
			_resolved[state] = _auto_pick(state, names)
		else:
			_resolved[state] = chosen if _has(chosen) else ""

# （自動）：從現有的動畫裡找名字是常見叫法的那一段（不分大小寫、去掉頭尾空白）
func _auto_pick(state: String, names: Array) -> String:
	var aliases: Array = _STATES[state][1]
	for n in names:
		if NameCheck.clean(str(n)).to_lower() in aliases:
			return str(n)
	return ""

# 狀態欄位的下拉選單：（自動）、（沒有），再列出現有的動畫
func _validate_property(property: Dictionary) -> void:
	super(property)
	if Engine.is_editor_hint() and _anim_player == null and _sprite == null and is_inside_tree():
		var host := _editor_player()
		if host != null:
			_find_players(host.get_node_or_null("Visual"))
	for state in _STATES:
		if property.name == _STATES[state][0]:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join([AUTO, NONE] + _anim_names())
			return

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

# 播放器與待機動畫的問題（找不到 Visual、找不到播放器、沒有待機），沒問題回傳空字串
func _setup_problem(visual: Node) -> String:
	if visual == null:
		return "找不到 Player 的 Visual 節點，角色動畫不會播"
	if _anim_player == null and _sprite == null:
		return "Player → Visual 底下沒有 AnimatedSprite2D 或 AnimationPlayer，角色動畫不會播：把 Visual 底下的 Sprite2D 換成 AnimatedSprite2D 再做動畫"
	if _sprite != null and _sprite.sprite_frames == null:
		return "AnimatedSprite2D 的 Sprite Frames 是空的：在 Inspector 的 Sprite Frames 選「新增 SpriteFrames」再做動畫"
	if _anim("idle") != "":
		return ""
	return "沒有待機動畫，角色動畫不會播：在 idle_animation 下拉選站著不動時播哪段；現在有的：%s" % NameCheck.list_text(_anim_names())

# 選了動畫、但那段動畫被刪掉或改名了：每個欄位一行
func _missing_warnings() -> Array:
	var result: Array = []
	for state in _STATES:
		var field: String = _STATES[state][0]
		var chosen: String = get(field)
		if chosen != AUTO and chosen != NONE and chosen != "" and not _has(chosen):
			result.append("%s 選的「%s」不見了（被刪掉或改名了），這個狀態不會播；請重新選" % [field, chosen])
	return result

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

# 黃色驚嘆號：找不到播放器、沒有待機、選的動畫不見了、動畫改了大小或顏色
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
	_resolve_all()
	var problem := _setup_problem(visual)
	if problem != "":
		warnings.append(problem)
	warnings.append_array(_missing_warnings())
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
