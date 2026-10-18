extends MechanicBase

# 磁力吸附：把範圍內的箱子往玩家的方向拉過來，離開範圍就放開。
# 箱子是 RigidBody2D，站在地上時重量會讓摩擦力遠大於合理範圍內的 apply_central_force()
# 施力（試過最高到 2000 都推不動一個沒在空中的箱子），所以改成直接在磁力範圍內把箱子
# 的 global_position 往玩家方向拉、順便把 linear_velocity 歸零，繞過摩擦力，玩起來
# 才會真的有「被吸過去」的感覺。
# 備品庫卡，不在抽卡池裡，學員許願才拖給他。拖進 Player → Mechanics 底下就能用，
# 不用連任何線。

## 磁力的吸附範圍半徑
@export_range(30.0, 200.0) var radius: float = 100.0

## 箱子被吸過來的速度
@export_range(20.0, 300.0) var pull_speed: float = 120.0

## 箱子離多近就不再拉，避免貼著玩家抖動
@export_range(10.0, 40.0) var min_distance: float = 20.0

# 掃場上所有箱子（推不動、固定住的箱子和殼跳過），範圍內、還沒貼太近的直接拉近水平位置，不透過施力（摩擦力太大推
# 不動）。只動 x 軸，垂直方向留給箱子自己的重力／落地邏輯處理，不會被磁力吸到跟
# 玩家同一個高度
func apply(ctx: MoveContext) -> void:
	for box in get_tree().get_nodes_in_group("box"):
		if not (box is RigidBody2D) or (box as RigidBody2D).freeze:
			continue
		var target: RigidBody2D = box
		var dx: float = player.global_position.x - target.global_position.x
		var dist: float = absf(dx)
		if dist > radius or dist <= min_distance:
			continue
		target.linear_velocity.x = 0.0
		target.global_position.x = move_toward(target.global_position.x, player.global_position.x, pull_speed * ctx.delta)
