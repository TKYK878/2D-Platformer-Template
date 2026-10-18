extends Node

# 連線驗證器：遊戲開始時掃描目前場景裡所有 signal_source 零件的訊號連接，
# 抓出訊號連接對話框本身擋不住的錯誤，用中文警告印在輸出面板。
# 見 documents/01a_shared_systems.md §6.5：這是零連線鐵律唯一例外
#（零件之間的訊號連接）的第二道防線。

const _DANGEROUS_METHODS := ["queue_free", "free", "set_script"]

var _checked_scene_id: int = 0   # 已經檢查過的場景，同一個場景不檢查兩次

# 等一幀讓所有 signal_source 零件都進場，再開始掃描；之後換場景（標題 → 關卡）也檢查新場景
func _ready() -> void:
	get_tree().scene_changed.connect(_check_scene)
	_check_scene()

# 等一幀讓場景裡的零件都進場，目前場景還沒檢查過就檢查一次
func _check_scene() -> void:
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null or scene.get_instance_id() == _checked_scene_id:
		return
	_checked_scene_id = scene.get_instance_id()
	_check_missing_targets()
	_check_live_connections()

# 找開場自己移進 CanvasLayer 的節點（UI 畫面、手機按鈕會在原本的位置多一層「名字Layer」），
# 場景檔裡存的路徑少了這一層，所以每一層都試試看插進「名字Layer」
func _find_moved_to_layer(scene: Node, path: NodePath) -> Node:
	var names := String(path).split("/")
	for i in names.size():
		var tried := names.duplicate()
		tried.insert(i, names[i] + "Layer")
		var found := scene.get_node_or_null(NodePath("/".join(tried)))
		if found != null:
			return found
	return null

# 第一關：比對場景檔裡存的連接清單，抓連到的目標節點已經不存在的情況。
# 這種連接在場景載入時就會失敗、不會真的建立起來，所以要對場景檔本身檢查，
# 不能只看場景裡目前活著的連接。
func _check_missing_targets() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path.is_empty():
		return
	var packed: PackedScene = load(scene.scene_file_path)
	if packed == null:
		return
	var state := packed.get_state()
	for i in state.get_connection_count():
		var target_path: NodePath = state.get_connection_target(i)
		if scene.get_node_or_null(target_path) != null or _find_moved_to_layer(scene, target_path) != null:
			continue
		var source_name: String = String(state.get_connection_source(i)).get_file()
		var signal_name: String = state.get_connection_signal(i)
		_warn("「%s」的 %s 訊號連到的目標節點已經不存在了，請重新連一次" % [source_name, signal_name])

# 第二關：掃描所有 signal_source 零件實際生效的訊號連接，檢查方法存不存在、
# 參數數量對不對、有沒有連到危險的內建方法
func _check_live_connections() -> void:
	for node in get_tree().get_nodes_in_group("signal_source"):
		_scan_node(node)

# 檢查單一節點身上每個訊號的每一條連接。只看零件腳本自己宣告的訊號
#（例如按鈕的 turned_on），不管繼承自 Node/CanvasItem 的內建訊號——
# 那些是引擎內部自己在用的原生方法綁定，不會出現在 get_method_list() 反射結果裡，
# 拿去檢查只會誤判成「方法不存在」。
func _scan_node(node: Node) -> void:
	var script: Script = node.get_script()
	if script == null:
		return
	for signal_info in script.get_script_signal_list():
		var signal_name: String = signal_info["name"]
		var arg_count: int = signal_info["args"].size()
		for connection in node.get_signal_connection_list(signal_name):
			_check_connection(node, signal_name, arg_count, connection["callable"])

# 檢查一條連接：方法存不存在、參數數量對不對、有沒有連到危險的內建方法。
# 連到匿名函式（lambda）的連接跳過不檢查：lambda 沒有名字，get_method() 只會給一個
# 「<anonymous lambda>」的預留字串，get_method_list() 反射不出來，硬查只會誤判成
# 「方法不存在」。這種連接不是本來要防的對象（學員只會用「連接訊號」對話框接到
# 具名函式，不會寫 lambda）。
func _check_connection(source: Node, signal_name: String, arg_count: int, callable: Callable) -> void:
	var method_name := callable.get_method()
	if String(method_name).begins_with("<"):
		return
	var target := callable.get_object()
	if target == null or not is_instance_valid(target):
		return
	var target_name := _describe(target)
	if method_name in _DANGEROUS_METHODS:
		_warn("「%s」的 %s 訊號連到「%s」的內建方法 %s()，這個方法會直接刪掉節點，請確認這是故意的" % [source.name, signal_name, target_name, method_name])
	var arity := _method_arity(target, method_name)
	if not arity["found"]:
		_warn("「%s」的 %s 訊號連到「%s」的 %s()，但這個方法不存在，是不是改名或打錯字了？" % [source.name, signal_name, target_name, method_name])
		return
	if arg_count < arity["min"] or arg_count > arity["max"]:
		_warn("「%s」的 %s 訊號帶 %d 個參數，但「%s」的 %s() 需要 %d 個，數量對不上" % [source.name, signal_name, arg_count, target_name, method_name, arity["min"]])

# 查詢某個方法需要幾個參數（含預設值的算進 max，min 是扣掉預設值後最少要給幾個；
# 可以接任意數量參數的方法，例如 Juice 的 play()，max 沒有上限），找不到這個方法就回傳 found = false
func _method_arity(target: Object, method_name: String) -> Dictionary:
	for m in target.get_method_list():
		if m["name"] == method_name:
			var total: int = m["args"].size()
			var optional: int = m["default_args"].size()
			var max_count: int = 1 << 30 if m["flags"] & METHOD_FLAG_VARARG else total
			return {"found": true, "min": total - optional, "max": max_count}
	return {"found": false, "min": 0, "max": 0}

# 取得一個物件用來顯示在警告訊息裡的名字。連接的目標不一定是 Node
#（例如接到沒有捕捉外部變數的匿名函式，繫結對象會是 GDScript 本身，沒有 name 屬性）
func _describe(obj: Object) -> String:
	if obj is Node:
		return obj.name
	return obj.get_class()

# 印出一則連線警告：push_warning() 讓偵錯器記錄下來，同時 printerr() 讓輸出面板也看得見
# （push_warning 本身不會出現在輸出面板，見 CLAUDE.md 鐵律 3）
func _warn(message: String) -> void:
	push_warning("[連線驗證] %s" % message)
	printerr("⚠ [連線驗證] %s" % message)
