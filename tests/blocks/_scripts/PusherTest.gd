extends Node2D

# 手動驗證用：推力器。Pickup_PushLeft 的 collected 連到 Pusher_PlayerLeft（推玩家、自訂方向往左上）；
# Button_PushRange 的 turned_on 連到 Pusher_RangeUp（範圍內全部、往右上、先停住再推），範圍裡有箱子和敵人。

@onready var _player: CharacterBody2D = $Player
@onready var _left: Node = $Pusher_PlayerLeft
@onready var _range: Node = $Pusher_RangeUp

const _DIR_NAMES := ["上", "下", "左", "右", "左上", "右上", "左下", "右下", "自訂"]

# 印出操作說明與預期結果
func _ready() -> void:
	print("[測試] 方向鍵移動、空白跳。P＝直接叫 Pusher_PlayerLeft 推玩家一下")
	print("[測試] ① 往右撿道具：玩家往左上飛（自訂方向 x=-1、y=-0.5）")
	print("[測試] ② 往右踩按鈕：範圍方框裡的箱子、敵人（站在框裡的話玩家也是）往右上飛；敵人飛的時候不巡邏、不扣血")
	print("[測試] D＝切換 Pusher_PlayerLeft 的方向（8 個方向＋自訂）、M＝切換疊加／先停住再推、G＝翻轉玩家重力、F＝切換跟著翻轉／不翻轉")
	print("[測試] ③ 往右跑的時候按 P：疊加＝往左的力被抵銷一些；先停住再推＝每次飛一樣遠")
	print("[測試] ④ 方向選上、按 G 翻轉重力再按 P：跟著翻轉＝往角色頭頂（畫面下方）推；不翻轉＝往畫面上方推")
	print("[測試] ⑤ 編輯器裡：推力器有橘色箭頭（strength 越大越長）、Pusher_RangeUp 有範圍方框；direction 選自訂才看得到 custom_x、custom_y")

# 除錯按鍵
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_P:
			_left.activate()
		KEY_D:
			_left.direction = (_left.direction + 1) % _DIR_NAMES.size()
			print("[測試] 方向：%s" % _DIR_NAMES[_left.direction])
		KEY_M:
			_left.push_mode = 1 - _left.push_mode
			print("[測試] 推法：%s" % ("疊加" if _left.push_mode == 0 else "先停住再推"))
		KEY_G:
			_player.flip_gravity()
			print("[測試] 翻轉重力")
		KEY_F:
			_left.on_gravity_flip = 1 - _left.on_gravity_flip
			print("[測試] 重力翻轉時：%s" % ("跟著翻轉" if _left.on_gravity_flip == 0 else "不翻轉"))
