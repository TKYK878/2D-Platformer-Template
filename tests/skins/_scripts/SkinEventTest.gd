extends Node2D

# 手動驗證用：SkinEvent（零件發生事件時播一段動畫，U180b）。
# 按鈕（踩一下切換）已經在場景裡連到門的 activate／deactivate。

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 編輯器：選任一個 SkinEvent，「when」「animation」都是下拉，選項是這個零件的事件、上面 SkinAnimated 的動畫")
	print("[測試] 　黃色驚嘆號：Launcher2 的 SkinEvent「沒有「彈」動畫…是不是要選「彈跳」？」；")
	print("[測試] 　Box 的 SkinEvent「這個零件沒有可以播動畫的事件」；Goal 的 SkinEvent 放在靜態 Skin 底下「要放在 SkinAnimated 底下」")
	print("[測試] 　新拖一個 SkinEvent 到 Launcher1 的 SkinAnimated 底下：兩個下拉自動選好「彈出時」「彈跳」")
	print("[測試] F6 往右走：")
	print("[測試] 　踩按鈕：按鈕先快速上下動幾下（閃），閃完照動但變色（沒有「啟動」動畫，用原本效果）；同時門播開門中，播完停在開著的門")
	print("[測試] 　再踩一次按鈕：按鈕回到原本的顏色、門關上（關掉時沒有設事件，直接換回平常）")
	print("[測試] 　踩 Launcher1：彈簧壓下彈起的動畫播一次，回到平常；Launcher2 一樣會彈，但不播動畫，輸出面板有中文警告")
	print("[測試] 　輸出面板也有 Box、Goal 的 SkinEvent 中文警告")
