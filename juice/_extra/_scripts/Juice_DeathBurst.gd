@tool
extends JuiceBase

# 死亡爆散：角色死掉時，角色圖切成一塊一塊的小方塊往外噴開、慢慢淡掉，角色本身隱形，重生時恢復。
# 拖進 Player → Juice 底下就能用，不用選觸發時機；把別的訊號連到 play() 也會爆開（一樣要重生才會恢復）。
# 碎塊是角色圖真的切下來的樣子（Sprite2D、AnimatedSprite2D 當下那一格），不受物理影響、不會撞到東西。

## 碎塊有多大（像素），數值越小碎得越細
@export_range(2, 16) var piece_size: int = 4
## 碎塊噴開的力道
@export_range(50.0, 600.0) var strength: float = 220.0
## 碎塊多久淡掉（秒）
@export_range(0.3, 3.0) var duration: float = 1.2

# 一次最多幾塊，太多會卡；超過就自動把碎塊切大一點
const _MAX_PIECES := 64
const _SPIN := 12.0

var _pieces: Array = []   # { node, velocity, spin }
var _time: float = 0.0
var _warned: bool = false

# 不用選觸發時機：自己聽玩家死亡
func _is_continuous() -> bool:
	return true

# 聽玩家死亡；平常不用每幀更新
func _on_setup() -> void:
	_listen(player.died, func(): _trigger(player.global_position, 1.0))
	set_process(false)

# 把角色圖切成碎塊噴出去，角色本身隱形（重生時 JuiceBase 會撤掉，角色就回來了）
func _on_play() -> void:
	if player.visual == null:
		return
	_clear_pieces()
	var level := get_tree().current_scene
	if level == null:
		return
	var sources := []
	for child in player.visual.get_children():
		if _source_texture(child) != null:
			sources.append(child)
	if sources.is_empty():
		if not _warned:
			_warned = true
			push_warning("[%s] Visual 底下沒有 Sprite2D／AnimatedSprite2D，角色圖碎不開" % name)
			print("[%s] Visual 底下沒有 Sprite2D／AnimatedSprite2D，角色圖碎不開" % name)
		return
	var cell := _cell_size(sources)
	for source in sources:
		_shatter(source, cell, level)
	player.set_juice_tint(self, Color(1.0, 1.0, 1.0, 0.0))
	_time = 0.0
	set_process(true)

# 依碎塊上限算出實際的碎塊大小：總塊數超過上限就把碎塊放大
func _cell_size(sources: Array) -> int:
	var cell := piece_size
	while true:
		var total := 0
		for source in sources:
			var rect := _source_rect(source)
			total += ceili(rect.size.x / cell) * ceili(rect.size.y / cell)
		if total <= _MAX_PIECES:
			return cell
		cell += 1
	return cell

# 把一張角色圖切成方塊，每塊放在它原本在畫面上的位置，給一個往外噴的速度
func _shatter(source: Node2D, cell: int, level: Node) -> void:
	var texture: Texture2D = _source_texture(source)
	var rect := _source_rect(source)
	var top_left: Vector2 = source.offset - (rect.size * 0.5 if source.centered else Vector2.ZERO)
	var t := source.get_global_transform()
	var center: Vector2 = player.global_position
	var y := 0.0
	while y < rect.size.y:
		var x := 0.0
		while x < rect.size.x:
			var size := Vector2(minf(cell, rect.size.x - x), minf(cell, rect.size.y - y))
			var local := top_left + Vector2(x, y) + size * 0.5
			if source.flip_h:
				local.x = 2.0 * source.offset.x - local.x
			if source.flip_v:
				local.y = 2.0 * source.offset.y - local.y
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(rect.position + Vector2(x, y), size)
			var piece := Sprite2D.new()
			piece.texture = atlas
			piece.flip_h = source.flip_h
			piece.flip_v = source.flip_v
			piece.modulate = source.modulate * player.visual.modulate
			piece.z_index = 10
			level.add_child(piece)
			piece.global_transform = Transform2D(t.x, t.y, t * local)
			var away: Vector2 = piece.global_position - center
			var dir: Vector2 = away.normalized() if away.length() > 0.5 else Vector2.from_angle(randf() * TAU)
			var velocity: Vector2 = dir * strength * randf_range(0.6, 1.2) + player.up_direction * strength * 0.5
			_pieces.append({ "node": piece, "velocity": velocity, "spin": randf_range(-_SPIN, _SPIN) })
			x += cell
		y += cell

# 每幀讓碎塊飛、受重力往下掉、轉圈、慢慢淡掉；時間到就全部刪掉
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var down: Vector2 = -player.up_direction if is_instance_valid(player) else Vector2.DOWN
	var gravity: float = player.gravity if is_instance_valid(player) else 980.0
	var alpha := clampf(1.0 - _time / duration, 0.0, 1.0)
	for p in _pieces:
		var node: Node2D = p.node
		if not is_instance_valid(node):
			continue
		p.velocity += down * gravity * delta
		node.global_position += p.velocity * delta
		node.rotation += p.spin * delta
		node.modulate.a = alpha
	if _time >= duration:
		_clear_pieces()
		set_process(false)

# 回傳角色圖現在顯示的那張圖，不是圖片節點（或沒有圖）就回傳 null
func _source_texture(source: Node) -> Texture2D:
	if source is Sprite2D and source.visible:
		return source.texture
	if source is AnimatedSprite2D and source.visible and source.sprite_frames:
		return source.sprite_frames.get_frame_texture(source.animation, source.frame)
	return null

# 回傳角色圖現在顯示的範圍（圖片上的像素位置）：有 region 用 region，有切格子用那一格
func _source_rect(source: Node) -> Rect2:
	var texture := _source_texture(source)
	if source is Sprite2D:
		if source.region_enabled:
			return source.region_rect
		var frame_size: Vector2 = texture.get_size() / Vector2(source.hframes, source.vframes)
		return Rect2(Vector2(source.frame % source.hframes, floori(float(source.frame) / source.hframes)) * frame_size, frame_size)
	return Rect2(Vector2.ZERO, texture.get_size())

# 刪掉場上所有碎塊
func _clear_pieces() -> void:
	for p in _pieces:
		if is_instance_valid(p.node):
			p.node.queue_free()
	_pieces.clear()

# 重生：碎塊清掉（角色由 JuiceBase 撤掉隱形後回來）
func _on_reset() -> void:
	_clear_pieces()
	set_process(false)

# 拔掉組件時碎塊一起清掉
func _exit_tree() -> void:
	super()
	if not Engine.is_editor_hint():
		_clear_pieces()
