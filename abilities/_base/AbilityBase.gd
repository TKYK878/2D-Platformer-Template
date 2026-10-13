extends Node2D
class_name AbilityBase

## 關閉時這個攻擊能力不會生效，但仍會顯示在場景裡。
@export var enabled: bool = true

## 攻擊的那一下發出（近戰揮擊、遠程射擊；冷卻中按了沒反應的不算），給角色動畫、學員自己接特效／音效用
signal attacked

var player: Node = null

# Player 呼叫，註冊自己並執行子類別初始化
func setup(p: Node) -> void:
	player = p
	_on_setup()
	print("[%s] 已啟用" % name)

# 攻擊能力在這裡做初始化，例如綁定按鍵、接訊號
func _on_setup() -> void:
	pass

# 檢查有沒有被正確掛在 Player 的 Abilities 底下，沒有就發警告
func _ready() -> void:
	# 沒有被 setup 就是掛錯位置了，要看得見
	await get_tree().process_frame
	if player == null:
		push_warning("[%s] 沒有掛在 Player 的 Abilities 底下，不會生效" % name)
		printerr("⚠ [%s] 請把這個節點拖進 Player → Abilities 底下" % name)
