extends Node2D

# 手動驗證用：Portal 傳送。下排 Portal_A、Portal_B 互相指定（雙向）；
# 上排只有 Portal_C_OneWay 指定 Portal_D_Exit（單向，D 只當出口，不會自動連回來）。

@onready var _portal_a: Area2D = $Portal_A
@onready var _portal_b: Area2D = $Portal_B
@onready var _portal_d: Area2D = $Portal_D_Exit

# 印出操作說明與配對結果
func _ready() -> void:
	print("[測試] 下排雙向：A 的 pair 指 B、B 的 pair 指 A")
	print("[測試] 上排單向：只有 C 的 pair 指 D，D 的 pair 空白")
	print("[測試] Portal_D_Exit 目前的目的地：%s（應該是 null，不會自動連回 C）" % (_portal_d._pair_portal.name if _portal_d._pair_portal else "null"))
	_portal_a.teleported.connect(func(_b): print("[測試] Portal_A：teleported"))
	_portal_b.teleported.connect(func(_b): print("[測試] Portal_B：teleported"))
	print("[測試] ① 走進下排左邊的 A：瞬移到右邊的 B，不會立刻被傳回去（0.3 秒內不重複觸發）；走開再走進 B：傳回 A")
	print("[測試] ② 跳上上排走進 C：傳到 D；走開再走進 D：不會傳回去，輸出面板提醒一次「沒有設定 pair，只當出口…」")
	print("[測試] ③ 編輯器裡：D 沒有黃色驚嘆號（有別座指到它，可以只當出口）")
