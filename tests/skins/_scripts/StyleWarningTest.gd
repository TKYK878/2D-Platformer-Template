extends Node2D

# 驗證用：畫面風格的黃色驚嘆號（這個測試主要在編輯器裡看，不用按 F6）。
# 金幣的皮：4 個正常的、Filter 改成 Linear、縮放 1.5、縮放 0.25、縮放 2、一個問題很多但勾了 ignore_style_check；
# 底下一條拉伸蓋滿的平台；背景的 Filter 改成 Linear。

# 印出要在編輯器裡看什麼
func _ready() -> void:
	print("[測試] 這個測試在編輯器裡看：打開 tests/skins/StyleWarningTest.tscn，看場景樹上哪些 Skin 有黃色驚嘆號")
	print("[測試] ① 沒有驚嘆號：Coin_OK1～4、Coin_Ignored 的 Skin（勾了 ignore_style_check）、Platform_Stretch 的 Skin（拉伸蓋滿）")
	print("[測試] ② Coin_Linear：Texture → Filter 改成了「Linear」，像素圖會糊")
	print("[測試] ③ Coin_Scale1_5：縮放是 1.5 倍，不是整數倍")
	print("[測試] ④ Coin_Tiny：縮放 0.25 不是整數倍＋像素比多數的皮小 4 倍；Coin_Big2x：像素比多數的皮大 2 倍（整數倍，只有這一條）")
	print("[測試] ⑤ Background_Blurry：Filter 是 Linear")
	print("[測試] ⑥ 把 Coin_OK1 的 Skin 的 Scale 拉成 3：一秒內出現驚嘆號；改回 1 就消失。勾 Coin_Linear 的 ignore_style_check：驚嘆號消失")
	print("[測試] ⑦ 按 F6 跑起來：輸出面板不會多印風格的警告（只在編輯器裡提醒，不吵）")
