# 00 — 地基

> 前置閱讀：`CLAUDE.md`
> 這份規格是所有週次的前提，必須先完成並通過驗收才進行 W1 規格（`documents/01a_shared_systems.md` 起）。

---

## 1. 資料夾結構

```
res://
├── _my/                      # 學員的全部身家，唯一可寫區
│   ├── MyGym.tscn            # W1：從 Gym.tscn 另存
│   └── art/                  # W4：學員自己下載的素材
│       └── .gdkeep
├── _help/                    # 操作速查表與 FAQ（放圖文，非程式）
├── _tests/
│   └── SmokeTest.tscn        # 自動化煙霧測試
├── tests/                    # 開發用的手動測試場景，分類跟組件資料夾一樣（.gd 放各分類的 _scripts/）
│   ├── systems/              # 共用系統（autoload、Player 生命週期、連線驗證器…）
│   ├── mechanics/            # 機制卡（備品卡放 mechanics/_extra/）
│   ├── blocks/               # 零件
│   └── abilities/            # 攻擊能力
├── autoload/
│   └── Events.gd             # 全域事件匯流排
├── player/
│   ├── Player.tscn
│   ├── Player.gd             # 唯一的物理腳本，學員禁區
│   └── MoveContext.gd
├── mechanics/                # W1：一張卡 = 一個 .tscn（這層只放學員要拖的 .tscn）
│   ├── _base/
│   │   └── MechanicBase.gd
│   ├── _scripts/             # 每張卡的 .gd，學員不用打開
│   └── _extra/               # 備品庫，平常不介紹（一樣把 .gd 放在 _extra/_scripts/）
├── juice/                    # W3（.gd 放 juice/_scripts/）
│   └── _base/
│       └── JuiceBase.gd
├── blocks/                   # W2：平台、機關、敵人（.gd 放 blocks/_scripts/）
├── abilities/                # 攻擊能力（.gd 放 abilities/_scripts/）
├── levels/
│   ├── _shared/
│   │   └── CameraRig.gd      # 重生改由 blocks/RespawnHandler.tscn 負責（見 00b）
│   ├── Gym.tscn              # W1 通用測試場，含地板，供學員參考佈置
│   ├── _Template.tscn        # W2 已框好的關卡起點，同樣附上基本地板（避免重生掉出畫面）與一個對齊畫面的 Room1
│   ├── _starts/              # 中途加入者的起始場景
│   │   └── .gdkeep
│   └── examples/             # W2 臨摹範例
├── art/                      # 講師提供的素材自助餐
└── sfx/
```

**`.gd` 一律放在同層的 `_scripts/` 資料夾**：`mechanics/`、`juice/`、`blocks/`、`abilities/`（含 `_extra/`）
這一層只放學員要拖的 `.tscn`。把 `.gd` 拖到場景樹的節點上會直接替換那個節點的腳本（例如把 `Mechanics`
容器變成一張卡），分開放可以避免學員拉錯。新增組件時 `.tscn` 放外層、`.gd` 放 `_scripts/`。

`.gdkeep` 是空檔案，用來讓 Godot 保留空資料夾。

---

## 2. Autoload：Events

`autoload/Events.gd`，在 Project Settings 註冊為 Autoload，名稱 `Events`。

```gdscript
extends Node

# 玩家事件（由 Player 轉發，方便跨場景組件接收）
signal player_jumped
signal player_landed(impact_force: float)
signal player_hurt
signal player_died

# 世界事件
signal enemy_died(pos: Vector2)
signal item_collected(pos: Vector2)
signal level_cleared
signal level_restarted
signal level_started            # U155 加入：關卡開場發一次
signal whole_level_restarted    # U155 加入：整關重來時才發

# 表現層請求（W3 Juice 用，讓組件不必知道攝影機在哪）
signal shake_requested(strength: float, duration: float)
signal hitstop_requested(duration: float)
signal zoom_requested(strength: float, duration: float, focus: Variant, focus_style: int)   # W3 加入：鏡頭放大到 1 + strength 倍再回到原本大小，往 focus 偏
```

**設計理由**：ScreenShake 組件掛在 Player 底下，但攝影機在關卡場景裡。透過匯流排，組件只負責 emit，實際執行由關卡裡的接收器負責，學員完全不需要連線。

---

## 3. Player

### 3.1 節點結構

`player/Player.tscn`（唯讀區，出廠就這樣，學員不會編輯它）：

```
Player (CharacterBody2D)  [script: Player.gd]
└── CollisionShape2D
```

**注意：`Sprite2D` 不放在這裡。** 視覺節點住在關卡場景裡（見 3.5），這樣 W4 換皮改的是學員自己的檔案。

關卡場景裡的 Player 實例長這樣（由 `Gym.tscn` / `_Template.tscn` 出廠附好）：

```
Player (player/Player.tscn 的實例)
├── Visual (Node2D)      [group: "player_visual"]
│   └── Sprite2D
├── Mechanics (Node2D)   ← W1：機制卡拖進來
└── Juice (Node2D)       ← W3：手感組件拖進來
```

這三個子節點存在**關卡場景檔**裡，所以學員的所有操作都寫進 `_my/`。

### 3.2 訊號

```gdscript
signal jumped
signal landed(impact_force: float)   # impact_force = 落地瞬間的 velocity.y 絕對值
signal hurt
signal died
signal direction_changed(dir: int)   # -1 左, 1 右
signal wall_hit
signal started_moving
signal stopped_moving
```

每個訊號 emit 時，同步轉發對應的 `Events.player_*`。

### 3.3 匯出參數

```gdscript
@export_group("移動參數")
## 水平移動速度，數值愈大角色跑得愈快。
@export_range(50.0, 500.0) var move_speed: float = 200.0
## 跳躍瞬間的初始速度，數值愈大跳得愈高。
@export_range(100.0, 800.0) var jump_force: float = 400.0
## 重力加速度，數值愈大角色下墜（或重力翻轉後上升）愈快。
@export_range(200.0, 2000.0) var gravity: float = 980.0
## 地面摩擦係數：0 = 像冰面一樣滑不停，1 = 放開方向鍵立刻煞停。
@export_range(0.0, 1.0) var ground_friction: float = 0.8
## 速度上限（像素／秒）：所有東西推出來的速度加起來都不會超過這個值，太快會穿牆。
## 一格是 16 像素；速度到 960 差不多每幀走一整格
@export_range(400.0, 2000.0) var max_speed: float = 1200.0
```

這是課程規則，不是物件身分的一部分，所以群組名稱用平實的「移動參數」，預設展開，不用警示圖示——紅色禁止圖示對新手來說容易被誤認成錯誤訊息。W1 一開始就要讓學員自己調跳躍／移動手感，每個變數上方用 `##` 寫中文說明，滑鼠停在 Inspector 欄位上會顯示成 tooltip。

**機制卡的參數一律不放在這裡**，放在各自的機制節點上（見 `documents/01b_mechanic_cards.md`）。

### 3.4 零連線的發現機制

Player 在 `_ready()` 自己找子節點並主動註冊，組件完全不需要知道 Player 在哪：

```gdscript
func _ready() -> void:
    _register_children($Mechanics if has_node("Mechanics") else null)
    _register_children($Juice if has_node("Juice") else null)

func _register_children(container: Node) -> void:
    if container == null:
        return
    for child in container.get_children():
        if child.has_method("setup"):
            child.setup(self)
        else:
            push_warning("[Player] %s 沒有 setup()，可能不是合法的組件" % child.name)
    # 學員在執行中拖入節點時也要生效
    container.child_entered_tree.connect(func(n):
        if n.has_method("setup"):
            n.setup(self)
    )
```

**這是整份架構的核心，不要改成讓組件自己往上找 Player。**

### 3.5 視覺節點

Player 用群組找視覺節點，不用路徑：

```gdscript
var visual: Node2D = null

func _ready() -> void:
    for n in get_tree().get_nodes_in_group("player_visual"):
        if is_ancestor_of(n):
            visual = n
            break
```

W3 的 SquashStretch 等組件透過 `player.visual` 操作，所以換皮後仍然有效。

### 3.6 提供給機制卡的公開 API

機制卡**不得直接寫 `velocity`**，只能呼叫這些方法：

```gdscript
func flip_gravity() -> void          # 重力翻轉
func add_impulse(v: Vector2) -> void # 施加瞬間衝量（後座力、彈跳）
func set_size_factor(f: float) -> void
func take_damage(amount: float = 1.0) -> void
func kill() -> void
func force_jump(power_scale: float = 1.0) -> void
func is_on_ground() -> bool
func can_ground_jump() -> bool       # 現在按跳躍能不能從地面起跳（含「晚一點按也能跳」的時間），跟跳躍有關的卡判斷「在不在地上」用這個
func get_move_input() -> float       # -1 ~ 1
```

### 3.7 MoveContext：每幀的修改管線

`player/MoveContext.gd`，是一個 `RefCounted`：

```gdscript
extends RefCounted
class_name MoveContext

var speed_scale: float = 1.0
var jump_scale: float = 1.0
var gravity_scale: float = 1.0
var friction_scale: float = 1.0
var auto_run_dir: int = 0        # 0 = 不強制，-1/1 = 強制方向
var input_locked: bool = false
var delta: float = 0.0
```

Player 的 `_physics_process` 流程固定為：

1. 建立 `MoveContext`，填入 `delta`
2. 依序呼叫每張機制卡的 `apply(ctx)`（有實作才呼叫）
3. 用 ctx 裡的倍率計算最終 velocity
4. `move_and_slide()`
5. 偵測狀態變化並 emit 訊號

**好處**：機制卡只能調整倍率與旗標，物理計算的權責完全留在 Player，所以學員掛任何組合都不會把物理弄壞。

**機制卡寫 `MoveContext` 的規則**（多張卡同時掛時才不會互相蓋掉）：

- 倍率（`*_scale`）一律**乘上去**：`ctx.speed_scale *= 1.5`，不要寫 `=`。要「完全不能跑」就乘 0。
  這樣越跑越快（×3）＋體力耗盡（×0）＝不能跑，跟卡片在場景樹的順序無關。
- 旗標（`input_locked`、`movement_frozen`）只設成 `true`，不要設回 `false`（別張卡可能要鎖）。
- `auto_run_dir` 只能有一個值：多張卡同時設時，**場景樹裡排在後面的蓋過前面的**（例如只能往前＋衝刺，衝刺中以衝刺方向為準）。

---

## 4. 組件基底類別

### 4.1 MechanicBase

`mechanics/_base/MechanicBase.gd`：

```gdscript
extends Node2D
class_name MechanicBase

## 關閉時這張機制卡不會生效，但仍會顯示在場景裡。
@export var enabled: bool = true

var player: Node = null

# Player 呼叫，註冊自己並執行子類別初始化
func setup(p: Node) -> void:
    player = p
    _on_setup()
    print("[%s] 已啟用" % name)

# 機制卡在這裡做初始化，例如接訊號、設定初始狀態
func _on_setup() -> void:
    pass

# 機制卡在這裡影響每個物理幀的移動參數
func apply(_ctx: MoveContext) -> void:
    pass

# 檢查有沒有被正確掛在 Mechanics 底下，沒有就發警告
func _ready() -> void:
    # 沒有被 setup 就是掛錯位置了，要看得見
    await get_tree().process_frame
    if player == null:
        push_warning("[%s] 沒有掛在 Player 的 Mechanics 底下，不會生效" % name)
        printerr("⚠ [%s] 請把這個節點拖進 Player → Mechanics 底下" % name)
```

### 4.2 JuiceBase

`juice/_base/JuiceBase.gd`，同樣的 `setup()` / `player` / `_ready()` 警告結構，加上：

```gdscript
@export_enum("跳躍時", "落地時", "受傷時", "死亡時", "撞牆時", "不自動觸發")
var timing: int = 1

# 依「觸發時機」把 callback 接到對應的 Player 訊號，Juice 組件用這個省去自己判斷要接哪個訊號
func _connect_trigger(callback: Callable) -> void:
    match timing:
        0: player.jumped.connect(callback)
        1: player.landed.connect(func(_f): callback.call())
        2: player.hurt.connect(callback)
        3: player.died.connect(callback)
        4: player.wall_hit.connect(callback)
        5: pass
```

---

## 5. 關卡場景

### 5.1 共用元件

`Gym.tscn` 與 `_Template.tscn` 是兩個各自獨立、內容完整的普通場景（**不是**繼承場景，
兩者都可以直接打開看到全部節點，不需要理解 Godot 的場景繼承機制）。兩者都內建
（學員不會碰到）：

- `TileMapLayer`，`tile_set` 指向共用資源 `art/default_tile.tres`（基於 `art/blocks.png`
  的 16x16 tile，含 `physics_layer_0` 碰撞多邊形）。兩個場景各自畫自己的
  `tile_map_data`，只是共用同一份 tile 素材，改素材時兩邊都會拿到最新版本，但地形佈置
  本身互不影響。
- `Player`（`player/Player.tscn` 的實例），底下附好 `Visual/Sprite2D`、`Mechanics`、`Juice`
  三個容器節點（見 3.1 節）。
- `Camera2D`，掛 `CameraRig.gd`：接 `Events.shake_requested`，執行螢幕震動；接 `Events.room_entered`，
  依鏡頭模式處理換房間（見 `00b_rooms_and_soft_respawn.md` §3）。
  - **預設不做平滑跟隨**（「瞬切」：每個房間一個固定畫面）。`Camera2D` 是關卡場景根節點底下的獨立節點，
    **不掛在 Player 實例底下**，跟 Player 之間沒有父子關係。
  - 鏡頭模式下拉選單：瞬切（預設）／房間內跟隨（跟著玩家但不超出目前房間）／自由跟隨（忽略房間，例如 Showroom）。
  - 螢幕震動照樣透過 `Events.shake_requested` 接收，是疊加在鏡頭位置上的偏移，不影響零連線設計。
    同時有好幾個震動請求時取比較強的那個（剩餘強度 vs 新強度），不直接覆蓋。
  - 鏡頭推近（W3）透過 `Events.zoom_requested` 接收：放大到 `1 + strength` 倍再回到原本大小，放大時畫面往請求指定的放大中心偏（偏一點／定在原地／拉到正中央）；
    房間內跟隨模式用放大後的畫面大小計算限制範圍。Juice 總開關關掉、玩家重生時，進行中的震動與推近立刻停止。
- `RespawnHandler`（`blocks/RespawnHandler.tscn` 的實例）：玩家死亡後等 `delay` 秒軟重生，不重新載入
  場景（見 `00b_rooms_and_soft_respawn.md` §4）。**兩個場景都要有地板**，否則學員重生後會直接掉出畫面外。

`HitStopManager`（Autoload，見第 2 節）：接 `Events.hitstop_requested`
  - **`Engine.time_scale` 是全域的，必須有單例保護**
  - 時長上限鎖 `0.3` 秒
  - 已在頓幀中時，新請求直接忽略，不得疊加
  - 結束後必須保證 `Engine.time_scale = 1.0`

### 5.2 `Gym.tscn` 與 `_Template.tscn` 的差別

兩者現階段場景內容幾乎一樣（都有同一排基本地板），差別在角色定位：

- `Gym.tscn`：**參考範例／展示櫃。** 之後每週的機制卡／Juice 組件示範佈置，會疊加在
  這個檔案裡（佈置內容見對應週次的規格文件，例如 `documents/01_week1 mechanics.md`）。
- `_Template.tscn`：**複製基準。** W2 開始，學員複製這個檔案到 `_my/` 底下，在既有地板
  的基礎上繼續畫地形、蓋自己的關卡。

### 5.3 `_my/MyGym.tscn`

W1 開場時學員做的第一件事是把 `levels/Gym.tscn` 另存為 `_my/MyGym.tscn`。
Gym 的內容規格見 `documents/01_week1 mechanics.md`。

---

## 6. 匯出設定

`export_presets.cfg` **必須隨包發出，不得列入 .gitignore**。

預先建立兩個 preset：

| 名稱 | 平台 | 輸出路徑 |
|---|---|---|
| `Web` | Web | `build/web/index.html` |
| `Windows` | Windows Desktop | `build/windows/game.exe` |

Web preset 要求：
- `Head Include` 留空即可，SharedArrayBuffer 由 itch.io 端設定
- 確認 `Export With Debug` 關閉

學員每週的上傳流程必須是：**Project → Export → 選 Web → Export Project → 按一個按鈕**，不做任何設定。

### .gitignore

```gitignore
# Godot 4
.godot/
/android/

# 匯出產物
build/

# 保留匯出設定（學員需要它才能一鍵打包）
!export_presets.cfg
```

---

## 7. 煙霧測試

`_tests/SmokeTest.tscn` + `SmokeTest.gd`，用 `--headless` 執行，要求：

1. 載入 Player，逐一實例化 `mechanics/` 底下**每一個**機制卡 `.tscn`（根節點是 `MechanicBase` 的；殼、殼的特性這類放在 `mechanics/` 底下但不是卡的場景跳過），各自掛上跑 60 幀
2. 隨機組合 3 個機制卡同時掛載，跑 60 幀
3. 逐一實例化 `juice/` 底下每一個組件，跑 60 幀
4. 同時掛 6 個 Juice 組件，跑 60 幀
5. 觸發 `Events.hitstop_requested` 10 次，確認結束後 `Engine.time_scale == 1.0`
6. 掛重力翻轉、忽大忽小、越跑越快，連續 `kill()` / `revive()` 10 次，每次重生後位置、重力、角色圖方向、
   體型、血量、`is_dead()` 都要正確歸零（見 `00b_rooms_and_soft_respawn.md` §8）
7. 放兩隻掛了 `blocks/EnemyShooter` 的敵人朝玩家連射 3 秒（玩家死掉就復活，中途打倒一隻），確認有射出子彈、不會崩潰
8. 每個階段結束後拔掉所有組件，確認 Player 仍能正常移動
9. 任何一項失敗：`printerr` 說明 + `get_tree().quit(1)`
10. 全部通過：`print("SMOKE TEST PASSED")` + `quit(0)`

**新增任何機制卡或 Juice 組件時，測試會自動掃資料夾，不需要手動維護清單。**

---

## 8. 驗收條件

全部通過才算地基完成：

- [ ] `godot --headless --check-only --path .` 無錯誤
- [ ] `godot --headless --path . res://_tests/SmokeTest.tscn` 印出 `SMOKE TEST PASSED`
- [ ] 把任一 `MechanicBase` 子類別拖進 Player → Mechanics 底下，**不連任何線**即生效
- [ ] 把同一個組件拖到**錯誤位置**（例如直接拖到關卡根節點），輸出面板出現中文警告，遊戲不崩潰
- [ ] 刪掉 Mechanics 與 Juice 兩個容器節點，遊戲仍能跑
- [ ] `player/Player.gd` 裡沒有任何具名機制卡的邏輯
- [ ] 存檔關卡後，`git status` 只顯示 `_my/` 底下的檔案有變更
- [ ] Web 與 Windows 兩個 preset 都能成功匯出