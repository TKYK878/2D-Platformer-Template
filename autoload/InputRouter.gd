extends Node

# 所有機制卡、能力、按鍵觸發器統一透過這裡收輸入（鍵盤與滑鼠按鍵都是），不要各自讀 Input。
# 同一個按鍵／動作、同一個時機被多邊綁定時，優先權高的先收到；它回傳 true 代表「處理掉了」，
# 優先權較低的這一輪就不會再收到。學員自己擺的按鍵觸發器例外：一律用 bind_student_key()／bind_student_mouse()，
# 一定收得到，但不會擋住任何其他綁定（見 _dispatch_group）。

# 按下的那一幀觸發一次，callback 不帶參數
const PRESSED := 0
# 按著的每個物理幀觸發，callback 帶「已按住秒數」(float)
const HELD := 1
# 放開的那一幀觸發一次，callback 帶「總共按住的秒數」(float)
const RELEASED := 2

# 組件下拉選單「滑鼠左鍵／滑鼠右鍵／滑鼠中鍵」依序對應的滑鼠按鍵
const MOUSE_BUTTONS: Array[MouseButton] = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]

# 學員按鍵觸發器專用的優先權：故意設到不可能有人蓋過去的低點
const STUDENT_PRIORITY := -2147483648

# 在網頁版會被瀏覽器攔截、觸發內建功能的按鍵（Ctrl、Tab、Esc、F 鍵）
const DANGEROUS_KEYS: Array[Key] = [
	KEY_CTRL, KEY_TAB, KEY_ESCAPE,
	KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6,
	KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12,
]

# 一條綁定紀錄
class Binding extends RefCounted:
	var owner: Node
	var trigger: StringName
	var phase: int
	var callback: Callable
	var priority: int
	var temp_action: StringName = &""   # 用 bind_key()/bind_mouse() 建立的臨時動作，一般 bind() 為空
	var is_student: bool = false

var _bindings: Array[Binding] = []
var _press_started_at: Dictionary = {}   # trigger(StringName) -> 按下當下的時間戳（秒）
var _temp_action_refs: Dictionary = {}   # 臨時動作(StringName) -> 有幾條綁定在用它
var _watched_owners: Dictionary = {}     # owner(Node) -> true，避免對同一個 owner 重複接 tree_exiting

# 用動作名稱綁定；機制卡、能力、資工生用這個，priority 越大越先收到
@warning_ignore("shadowed_variable_base_class")
func bind(owner: Node, action: StringName, phase: int, callback: Callable, priority: int = 0) -> void:
	_add_binding(owner, action, phase, callback, priority, &"", false)

# 直接用按鍵綁定，內部自動建立只在執行期存在的臨時動作，不會寫回專案設定
@warning_ignore("shadowed_variable_base_class")
func bind_key(owner: Node, key: Key, phase: int, callback: Callable, priority: int = 0) -> void:
	var action := _ensure_key_action(key)
	_add_binding(owner, action, phase, callback, priority, action, false)

# 直接用滑鼠按鍵綁定（左鍵、右鍵、中鍵），用法跟 bind_key() 一樣
@warning_ignore("shadowed_variable_base_class")
func bind_mouse(owner: Node, button: MouseButton, phase: int, callback: Callable, priority: int = 0) -> void:
	var action := _ensure_mouse_action(button)
	_add_binding(owner, action, phase, callback, priority, action, false)

# 依組件的「按鍵種類」下拉選單綁定：0 是鍵盤按鍵（用 key），1~3 是滑鼠左鍵／右鍵／中鍵，
# 能力跟機制卡的按鍵欄位用這個
@warning_ignore("shadowed_variable_base_class")
func bind_input(owner: Node, input_type: int, key: Key, phase: int, callback: Callable, priority: int = 0) -> void:
	if input_type == 0:
		bind_key(owner, key, phase, callback, priority)
	else:
		bind_mouse(owner, MOUSE_BUTTONS[input_type - 1], phase, callback, priority)

# 組件選到網頁版會出事的按鍵時印中文警告；label 是訊息開頭，例如「[近戰]」
func warn_if_dangerous_key(key: Key, label: String) -> void:
	if key not in DANGEROUS_KEYS:
		return
	var message := "%s 選到的按鍵「%s」在網頁版可能會觸發瀏覽器內建功能，建議換一個" % [label, OS.get_keycode_string(key)]
	push_warning(message)
	printerr("⚠ %s" % message)

# 學員自己擺的按鍵觸發器專用（KeyTrigger）：一定收得到輸入，但不會擋住任何其他綁定
@warning_ignore("shadowed_variable_base_class")
func bind_student_key(owner: Node, key: Key, phase: int, callback: Callable) -> void:
	var action := _ensure_key_action(key)
	_add_binding(owner, action, phase, callback, STUDENT_PRIORITY, action, true)

# 學員自己擺的按鍵觸發器選滑鼠按鍵時用這個：一定收得到輸入，但不會擋住任何其他綁定
@warning_ignore("shadowed_variable_base_class")
func bind_student_mouse(owner: Node, button: MouseButton, phase: int, callback: Callable) -> void:
	var action := _ensure_mouse_action(button)
	_add_binding(owner, action, phase, callback, STUDENT_PRIORITY, action, true)

# 學員自己擺的按鍵觸發器選「預設動作」時用這個：一定收得到輸入，但不會擋住任何其他綁定
@warning_ignore("shadowed_variable_base_class")
func bind_student(owner: Node, action: StringName, phase: int, callback: Callable) -> void:
	_add_binding(owner, action, phase, callback, STUDENT_PRIORITY, &"", true)

# 假裝這個動作「現在被按了一下」，依優先權重新派發一次按下（also_release 為 true 時接著派發一次放開，當作點一下就放開）。
# 預輸入（早一點按也能跳）落地時用這個，讓蓄力青蛙跳這類攔截跳躍的卡一樣先收到；學員的按鍵觸發器不會收到重播
func replay_press(action: StringName, also_release: bool) -> void:
	_replay_phase(action, PRESSED, null)
	if also_release:
		_replay_phase(action, RELEASED, 0.0)

# 依優先權派發某個動作某個時機的所有一般綁定（跳過學員綁定），重播用
func _replay_phase(action: StringName, phase: int, arg) -> void:
	var group: Array = _bindings.filter(func(b): return b.trigger == action and b.phase == phase and not b.is_student)
	group.sort_custom(func(a, b): return a.priority > b.priority)
	for binding in group:
		if _is_active(binding) and _call_binding(binding, arg):
			return

# 幫某個實體按鍵建立（或沿用）一個只在記憶體裡存在的臨時動作
func _ensure_key_action(key: Key) -> StringName:
	var event := InputEventKey.new()
	event.physical_keycode = key
	return _ensure_temp_action(StringName("_input_router_key_%d" % key), event)

# 幫某個滑鼠按鍵建立（或沿用）一個只在記憶體裡存在的臨時動作
func _ensure_mouse_action(button: MouseButton) -> StringName:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return _ensure_temp_action(StringName("_input_router_mouse_%d" % button), event)

# 臨時動作還不存在就建立，並把參照計數加一
func _ensure_temp_action(action: StringName, event: InputEvent) -> StringName:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		InputMap.action_add_event(action, event)
	_temp_action_refs[action] = _temp_action_refs.get(action, 0) + 1
	return action

# 建立一條綁定紀錄、加入清單、順便做衝突檢查與離場自動解除的掛勾
@warning_ignore("shadowed_variable_base_class")
func _add_binding(owner: Node, trigger: StringName, phase: int, callback: Callable, priority: int, temp_action: StringName, is_student: bool) -> void:
	var binding := Binding.new()
	binding.owner = owner
	binding.trigger = trigger
	binding.phase = phase
	binding.callback = callback
	binding.priority = priority
	binding.temp_action = temp_action
	binding.is_student = is_student
	_bindings.append(binding)
	_warn_if_conflict(binding)
	if not _watched_owners.has(owner):
		_watched_owners[owner] = true
		owner.tree_exiting.connect(_on_owner_exiting.bind(owner))

# owner 離開場景樹時，自動解除它在這裡註冊的所有綁定
@warning_ignore("shadowed_variable_base_class")
func _on_owner_exiting(owner: Node) -> void:
	_watched_owners.erase(owner)
	var remaining: Array[Binding] = []
	for binding in _bindings:
		if binding.owner == owner:
			if binding.temp_action != &"":
				_release_temp_action(binding.temp_action)
		else:
			remaining.append(binding)
	_bindings = remaining

# 減少臨時動作的參照計數，歸零時從 InputMap 移除，避免累積用不到的動作
func _release_temp_action(action: StringName) -> void:
	if not _temp_action_refs.has(action):
		return
	_temp_action_refs[action] -= 1
	if _temp_action_refs[action] <= 0:
		_temp_action_refs.erase(action)
		if InputMap.has_action(action):
			InputMap.erase_action(action)

# 把一個動作換算成實際的按鍵／滑鼠按鍵清單（例如 "key:32"、"mouse:1"），供衝突檢查比對用
func _resolve_inputs(trigger: StringName) -> Array[String]:
	var inputs: Array[String] = []
	for event in InputMap.action_get_events(trigger):
		if event is InputEventKey:
			inputs.append("key:%d" % (event as InputEventKey).physical_keycode)
		elif event is InputEventMouseButton:
			inputs.append("mouse:%d" % (event as InputEventMouseButton).button_index)
	return inputs

# 把衝突檢查用的輸入代號轉成看得懂的名稱，印在警告裡
func _input_label(input: String) -> String:
	var parts := input.split(":")
	var code := int(parts[1])
	if parts[0] == "mouse":
		match code:
			MOUSE_BUTTON_LEFT:
				return "滑鼠左鍵"
			MOUSE_BUTTON_RIGHT:
				return "滑鼠右鍵"
			MOUSE_BUTTON_MIDDLE:
				return "滑鼠中鍵"
		return "滑鼠按鍵 %d" % code
	return OS.get_keycode_string(code)

# 新綁定跟既有綁定的實體按鍵（含滑鼠按鍵）、時機重疊時，印中文警告提醒可能互相搶輸入
func _warn_if_conflict(new_binding: Binding) -> void:
	var new_inputs := _resolve_inputs(new_binding.trigger)
	if new_inputs.is_empty():
		return
	for existing in _bindings:
		if existing == new_binding or existing.phase != new_binding.phase:
			continue
		var existing_inputs := _resolve_inputs(existing.trigger)
		for input in new_inputs:
			if input in existing_inputs:
				push_warning("[InputRouter] %s 跟 %s 都綁定了同一個按鍵（%s），同一時機可能互相搶輸入" % [
					_owner_label(existing.owner), _owner_label(new_binding.owner), _input_label(input)
				])
				return

# 綁定紀錄裡的節點名稱，節點已經被釋放就給一個看得懂的替代字串
@warning_ignore("shadowed_variable_base_class")
func _owner_label(owner: Node) -> String:
	if is_instance_valid(owner):
		return owner.name
	return "（已釋放的節點）"

# 這條綁定現在算不算數：owner 已經不在場景樹裡，或它的「啟用」被關掉，都視為暫時不派發
func _is_active(binding: Binding) -> bool:
	if not is_instance_valid(binding.owner):
		return false
	if binding.owner.get("enabled") == false:
		return false
	return true

# 每個物理幀依優先權派發所有綁定的事件
func _physics_process(_delta: float) -> void:
	if _bindings.is_empty():
		return

	var triggers: Dictionary = {}
	for binding in _bindings:
		triggers[binding.trigger] = true
	for trigger in triggers:
		if Input.is_action_just_pressed(trigger):
			_press_started_at[trigger] = Time.get_ticks_msec() / 1000.0

	var groups: Dictionary = {}
	for binding in _bindings:
		var group_key := "%s|%d" % [binding.trigger, binding.phase]
		if not groups.has(group_key):
			groups[group_key] = []
		groups[group_key].append(binding)
	for group_key in groups:
		var group: Array = groups[group_key]
		group.sort_custom(func(a, b): return a.priority > b.priority)
		_dispatch_group(group)

	for trigger in triggers:
		if Input.is_action_just_released(trigger):
			_press_started_at.erase(trigger)

# 對同一個觸發來源＋時機的所有綁定派發事件：一般綁定依優先權互相擋，學員綁定一律收得到、不擋人
func _dispatch_group(group: Array) -> void:
	var trigger: StringName = group[0].trigger
	var phase: int = group[0].phase
	var fired := false
	match phase:
		PRESSED:
			fired = Input.is_action_just_pressed(trigger)
		HELD:
			fired = Input.is_action_pressed(trigger)
		RELEASED:
			fired = Input.is_action_just_released(trigger)
	if not fired:
		return

	var now := Time.get_ticks_msec() / 1000.0
	var arg = (now - _press_started_at.get(trigger, now)) if phase != PRESSED else null

	var handled := false
	for binding in group:
		if not _is_active(binding):
			continue
		if binding.is_student:
			_call_binding(binding, arg)
			continue
		if handled:
			continue
		if _call_binding(binding, arg):
			handled = true

# 呼叫綁定的 callback，依時機決定要不要帶參數
func _call_binding(binding: Binding, arg) -> Variant:
	if arg == null:
		return binding.callback.call()
	return binding.callback.call(arg)
