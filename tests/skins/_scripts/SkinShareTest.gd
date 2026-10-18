extends Node2D

# 手動驗證用：共用皮 SkinShare，關卡裡沒掛皮的同種零件全部套同一個皮（U222）。

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 編輯器：五塊岩漿（Lava_1x1、Lava_4x1、Lava_2x2、Lava_Toggle）都沒有自己的皮，卻都顯示 SkinShare_Lava 的岩漿圖，而且重複鋪滿整塊")
	print("[測試] 　Lava_OwnSkin 自己掛了皮（尖刺圖），照舊用自己的；兩個尖刺套 SkinShare_Spike 的圖")
	print("[測試] 　SkinShare_Duplicate：黃色驚嘆號「岩漿已經有共用皮了」；SkinShare_NoDoor：黃色驚嘆號「關卡裡沒有門」「底下還沒有皮」")
	print("[測試] 　點 SkinShare_Lava → target 下拉只列出關卡裡有的零件（岩漿、按鈕、尖刺）")
	print("[測試] 　換 SkinShare_Lava/Skin 的圖、改 fill_style：所有岩漿半秒內跟著變；試完 Ctrl+Z 還原")
	print("[測試] 　選一塊岩漿 → 場景樹上看不到多出來的皮；存檔後場景檔裡也不會有（預覽不存檔）")
	print("[測試] F6：遊戲中看到的跟編輯器一樣；SkinShare 底下的模板圖不會出現在畫面上")
	print("[測試] 　踩按鈕 → Lava_Toggle 變暗、不扣血；再踩一次恢復")
	print("[測試] 　輸出面板有 SkinShare_Duplicate、SkinShare_NoDoor 的「[共用皮]」中文警告")
