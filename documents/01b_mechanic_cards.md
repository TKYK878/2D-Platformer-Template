# 01b — W1：機制卡

> 前置閱讀：`CLAUDE.md`、`documents/00_foundation.md`、`documents/01a_shared_systems.md`

W1 的課堂活動是：學員線上抽一張**主限制卡** → 把對應的 `.tscn` 拖進 Player → Mechanics →
拿著這張卡去體驗各種情境，觀察會發生什麼，寫成 3-5 條實驗清單（實際練習場景見
`documents/01d_showroom_and_toybox.md`）。

卡牌分成兩種用途：

- **主限制卡（操作類 5 張、物理類 5 張）**：每人選一張，作為整個遊戲的核心玩法。
- **規則卡（8 張）**：W2 關卡設計時用在第三螢幕「轉」，打破玩家前兩個螢幕建立的習慣。W1 有餘力的學員
  可以先抽一張掛上來試。

抽卡順序：先選主限制卡，再從**相容的**規則卡裡抽（衝突組合見第 4 節）。

---

## 1. 卡牌總表

全部繼承 `MechanicBase`，全部放在 `mechanics/`，檔名即節點名。
難度維持 ⭐~⭐⭐，**不做地獄難度的卡**。

### 主限制卡

| # | 檔名 | 中文卡名 | 類別 | 實作方式 | 重生時（`on_respawn()`） |
|---|---|---|---|---|---|
| 1 | `Mechanic_NoFriction` | 煞車失靈 | 操作 | `ctx.friction_scale` | — |
| 2 | `Mechanic_AutoRun` | 只能往前 | 操作 | `ctx.auto_run_dir`，撞牆反轉 | 方向回到一開始設定的方向 |
| 3 | `Mechanic_ChargeJump` | 蓄力青蛙跳 | 操作 | `InputRouter` 高優先攔截跳躍鍵，`force_jump()` | 取消蓄力中的狀態 |
| 4 | `Mechanic_Slingshot` | 只能用滑鼠控制 | 操作 | `ctx.input_locked` + 拖曳放開 `add_impulse()` | 取消拖曳、藏起瞄準線 |
| 5 | `Mechanic_RecoilMove` | 只用後座力移動 | 操作 | `ctx.input_locked` + 方向鍵（或滑鼠鍵朝游標）反向 `add_impulse()` | 噴射次數補滿、冷卻歸零、顏色還原 |
| 6 | `Mechanic_PinballBody` | 彈珠台體質 | 物理 | `ctx.damage_scale = 0` + 碰撞擊飛 | 無敵時間歸零 |
| 7 | `Mechanic_GravityFlip` | 重力翻轉 | 物理 | `flip_gravity()` | 角色圖轉回正的、冷卻歸零（重力由 `revive()` 復位） |
| 8 | `Mechanic_BouncyWorld` | 彈性宇宙 | 物理 | 撞擊時反向 `add_impulse()` | 清掉速度記錄與輸入鎖 |
| 9 | `Mechanic_SpeedRamp` | 越跑越快 | 物理 | `ctx.speed_scale` + `ctx.jump_scale` 隨移動累加 | 速度倍率歸 1、顏色還原 |
| 10 | `Mechanic_SizeShift` | 忽大忽小 | 物理 | `set_size_factor()` | 回到一開始的小體型（`small_scale`）、取消待套用的變大 |

### 規則卡

| # | 檔名 | 中文卡名 | 實作方式 | 重生時（`on_respawn()`） |
|---|---|---|---|---|
| 11 | `Mechanic_StickyBody` | 黏黏身體 | 碰撞時 `ctx.gravity_scale = 0` + 鎖住速度 | 從黏住的表面脫落（不噴出去） |
| 12 | `Mechanic_Stamina` | 移動會扣血 | 體力條，耗盡時 `ctx.speed_scale` 降低 | 體力補滿、解除耗盡懲罰 |
| 13 | `Mechanic_TouchDeath` | 碰觸即死 | 任何碰撞 → `kill()` | — |
| 14 | `Mechanic_SurvivalTimer` | 存活計時 | 計時 → `Events.level_cleared` | 計時歸零重新開始 |
| 15 | `Mechanic_StopDeath` | 停下即死 | 靜止逾時 → `kill()` | 靜止計時歸零、顏色還原 |
| 16 | `Mechanic_HealthDrain` | 血量流失 | `Stats` 血量持續下降，吃金幣回復 | 扣血計時歸零（血量由 `revive()` 補滿） |
| 17 | `Mechanic_FloorIsLava` | 地板是岩漿 | 特定地板接觸 → `take_damage()` | 扣血計時歸零（血量由 `revive()` 補滿） |
| 18 | `Mechanic_SwitchWorld` | 開關世界 | 計時切換 group `switch_red` / `switch_blue` 方塊 | 紅藍方塊回到一開始的顏色、切換倒數重新開始 |

---

## 2. 本規格新增使用的欄位

以下是本規格用到、需要確認地基有沒有的東西。

| 項目 | 用途 | 預設值 | 定義位置 |
|---|---|---|---|
| `ctx.damage_scale` | 彈珠台體質把傷害歸零 | `1.0` | 本規格新增，需加進 `player/MoveContext.gd` |
| `ctx.knockback_scale` | 忽大忽小調整被擊退的程度 | `1.0` | 本規格新增 |
| `ctx.push_scale` | 忽大忽小調整推箱子的力道 | `1.0` | 本規格新增 |
| `ctx.jump_scale` / `ctx.gravity_scale` | 越跑越快、黏黏身體等調整跳躍力／重力 | `1.0` | 地基已實作，沿用 |
| 輸入動作 `move_up` / `move_down` | 後座力上下噴射 | — | 見 `01a_shared_systems.md` §3.1 |
| `Events.mechanic_event(card, event)` | 主限制卡的關鍵瞬間，為 W3 果汁組件預留 | — | 見 `01a_shared_systems.md` §7 |

`kill()` 必須**繞過** `ctx.damage_scale`，直接死亡。

---

## 3. 各卡規格

每張卡的 Inspector **欄位數量不設上限**（講師決定：學員程度不錯，盡量讓學員做出想要的效果；欄位多時用 `@export_group` 分組、只在某個選項下才有意義的用 `_validate_property()` 隱藏），全部英文變數名 + 中文 `##` tooltip，全部是拉桿或下拉或勾選。
`enabled` 由基底提供，不需重複宣告。

**`enabled` 必須可以在執行中切換**：關閉時乾淨還原它對 `ctx` 的所有修改、移除它生成的 UI。W2 會用
觸發區在第三螢幕才打開規則卡。

每張主限制卡附一行「事件」，在該瞬間 emit `Events.mechanic_event`。W1 不需要有任何東西訂閱它。

**卡片訊號（給學員連線）**：除了 `Events.mechanic_event`，卡片在同一個瞬間也 emit 自己宣告的訊號，讓學員在
「節點」面板把它連到 Player 的動作函式（`stop_motion`、`freeze`…，見 `01a_shared_systems.md` §6.7）或任何零件
的函式，自己組合出卡片沒內建的行為。規則：

- 訊號**一律不帶參數**，上方加 `##` 中文說明「什麼時候發出」。
- **會推玩家的訊號在推力施加之前發出**（射出、噴射、衝刺、各種跳、反彈、踩怪、擊飛）。訊號是同步呼叫，連到
  `stop_motion` 時效果是「先歸零、再推」，連到 `unfreeze` 時推力不會被凍住吃掉。其他訊號在事情發生之後發出。
- `MechanicBase` 自動加入 `signal_source`，連線驗證器會檢查卡片訊號的連線（函式不存在、參數數量不對）。
- `enabled` 關閉時卡片不動作，自然也不發訊號。
- 持續性效果、沒有明確「發生那一刻」的卡（磁力、黏黏地板）不加訊號。

| 卡片 | 訊號 | 什麼時候發出 |
|---|---|---|
| `Mechanic_NoFriction` | `slide_started` | 放開方向鍵開始滑行 |
| `Mechanic_AutoRun` | `turned_around` | 撞牆自動轉向 |
| `Mechanic_ChargeJump` | `charge_started`、`jumped` | 開始蓄力；放開起跳（推之前） |
| `Mechanic_Slingshot` | `drag_started`、`launched` | 開始拉；放開射出（推之前；拉的距離是 0 也發，避免凍住後解不開） |
| `Mechanic_RecoilMove` | `fired`、`out_of_charges` | 噴射（推之前）；空中次數用完還按 |
| `Mechanic_PinballBody` | `bounced_off` | 碰到敵人／尖刺被彈開（推之前） |
| `Mechanic_GravityFlip` | `flipped` | 重力翻轉之後 |
| `Mechanic_BouncyWorld` | `bounced` | 撞到表面反彈（推之前） |
| `Mechanic_SpeedRamp` | `reached_max`、`speed_reset` | 加到最高速；倍率歸零 |
| `Mechanic_SizeShift` | `grew`、`shrank`、`grow_canceled` | 變大之後；變小之後；還在等空間變大時又按一次、取消變大（可接「無效」提示） |
| `Mechanic_Stamina` | `exhausted`、`recovered` | 體力歸零；解除懲罰 |
| `Mechanic_FloorIsLava` | `burn_started`、`burn_stopped` | 開始站在會扣血的地板上；離開 |
| `Mechanic_HealthDrain` | `healed` | 撿到金幣補血 |
| `Mechanic_StickyBody` | `stuck`、`released` | 黏住；脫離（按跳躍或時間到都算，噴出去之前） |
| `Mechanic_StopDeath` | `punished` | 靜止太久開始懲罰（直接死亡之前／開始扣血），只發一次，重新移動後才會再發 |
| `Mechanic_SurvivalTimer` | `cleared` | 存活時間到 |
| `Mechanic_SwitchWorld` | `switched` | 紅藍方塊互換之後 |
| `Mechanic_TouchDeath` | `touched` | 碰到會死的東西（死亡之前） |
| `Extra_Dash` | `dashed`、`dash_ended` | 衝出去（推之前）；衝刺時間到、恢復一般移動 |
| `Extra_DoubleJump` | `air_jumped` | 空中再跳（推之前） |
| `Extra_StompOnly` | `stomped` | 踩中敵人反彈（推之前） |
| `Extra_TimeSlow` | `started`、`ended` | 世界變慢；恢復 |
| `Extra_WallJump` | `wall_jumped` | 蹬牆（推之前） |
| `Extra_Molt` | `shell_created`、`shell_changed`、`molt_blocked` | 脫出一顆殼之後（推之前）；用切換鍵換了一種殼；想脫殼但脫不了（次數用完、數量滿了又不能再脫） |

**有狀態的卡必須覆寫 `on_respawn()`**：玩家重生時 `Player.revive()` 會逐一呼叫，卡片在這裡把自己的狀態
（翻轉、計時、倍率、蓄力中…）歸零，回到剛掛上去時的樣子。各卡要重置什麼見第 1 節總表的「重生時」欄，
`—` 表示沒有要歸零的狀態、不用覆寫。規格見 `00b_rooms_and_soft_respawn.md` §7。

### 主限制卡

#### 1. 煞車失靈 `Mechanic_NoFriction`
```gdscript
## 放開方向鍵後還剩多少摩擦力，0 表示完全不減速
@export_range(0.0, 1.0) var remaining_friction: float = 0.0
```
`apply()`：`ctx.friction_scale = remaining_friction`
事件：`slide_start`（放開按鍵後仍在滑動的第一幀）

#### 2. 只能往前 `Mechanic_AutoRun`
```gdscript
## 遊戲開始時、重生時往哪個方向跑
@export_enum("向右", "向左") var start_direction: int = 0
## 撞到牆壁或箱子時要不要自動轉向
@export var turn_at_wall: bool = true
## 轉向後多久內不能再轉向，避免卡在角落抖動
@export_range(0.05, 0.5) var turn_cooldown: float = 0.15
```
設定 `ctx.auto_run_dir`，玩家只能按跳躍。
`turn_at_wall` 開啟時，`is_on_wall()` 且牆面法線與前進方向相反 → 反轉方向，`visual.scale.x` 同步翻轉。
可推箱子也算牆（箱子是轉向工具）。
重生後第一幀不檢查撞牆（死掉期間 `is_on_wall()` 停在死掉那一刻，貼著牆死會一重生就轉向）。
可以被連的函式：`run_left()`、`run_right()`、`turn_around()`（接任意參數；不發 `turned_around`，避免連回自己變無限迴圈）。
事件：`wall_turned`

#### 3. 蓄力青蛙跳 `Mechanic_ChargeJump`
```gdscript
## 最多可以蓄力幾秒
@export_range(0.2, 2.0) var max_charge_seconds: float = 1.0
## 完全沒蓄力時，跳躍力是滿力的多少倍
@export_range(0.3, 1.0) var min_jump_ratio: float = 0.4
## 蓄力的時候要不要禁止左右移動
@export var lock_move_while_charging: bool = true
```
用 `InputRouter.bind(self, "jump", ...)` 以較高優先攔截跳躍鍵：按住累積，放開時
`player.force_jump(比例)`，Player 自己的低優先跳躍綁定不會再收到這次按鍵。手感參考 Jump King。
`lock_move_while_charging` 只影響移動，不用 `ctx.input_locked`（那會連跳躍鍵一起鎖住）。
**對外公開 `is_charging: bool`**，停下即死會讀取它（見第 4 節）。
事件：`charge_start`、`charge_release`

#### 4. 只能用滑鼠控制 `Mechanic_Slingshot`
```gdscript
## 用哪一種按鍵拖曳；選鍵盤按鍵時，按住那顆鍵移動滑鼠瞄準，放開發射
@export_enum("鍵盤按鍵", "滑鼠左鍵", "滑鼠右鍵", "滑鼠中鍵") var input_type: int = 1
## 拖曳鍵（「按鍵種類」選鍵盤按鍵時才會顯示這一欄）
@export var key: Key = KEY_E
## 拖到最遠時發射的力道上限
@export_range(200.0, 1200.0) var max_launch_force: float = 700.0
## 拖曳超過這個距離，力道就不會再增加
@export_range(50.0, 300.0) var max_drag_distance: float = 150.0
## 開啟後只有站在地面上才能開始拖曳瞄準
@export var ground_only: bool = true
## 拖曳時要不要畫出瞄準線
@export var show_aim_line: bool = true
```
`ctx.input_locked = true`。用 `InputRouter.bind_input(self, input_type, key, ...)` 以較高優先綁定拖曳鍵的
按下／放開（預設滑鼠左鍵，Inspector 可比照近戰改選其他滑鼠按鍵或鍵盤按鍵；瞄準一律看滑鼠位置），
跟其他綁同一顆鍵的組件同時存在時會印衝突警告。按住往後拖，放開時
往拖曳的**反方向** `add_impulse()`，力道 = 拖曳距離比例 × `max_launch_force`。
`ground_only` 開啟時，離地期間無法開始拖曳。
瞄準線由組件自己生成 `Line2D`，學員不用擺。
事件：`launched`

#### 5. 只用後座力移動 `Mechanic_RecoilMove`
```gdscript
## 用方向鍵噴，還是按滑鼠鍵往游標的「反方向」噴
@export_enum("方向鍵", "滑鼠左鍵", "滑鼠右鍵", "滑鼠中鍵") var input_type: int = 0
## 每次噴射的力道大小
@export_range(100.0, 800.0) var recoil_strength: float = 350.0
## 落地前最多能噴射幾次
@export_range(1, 5) var air_charges: int = 3
## 著地時要不要把噴射次數補滿
@export var refill_on_land: bool = true
## 每次噴射之後，多久才能再噴一次
@export_range(0.1, 1.0) var cooldown: float = 0.3
```
`ctx.input_locked = true`。按下方向鍵（上下左右）→ 往**反方向** `add_impulse()`。
`input_type` 選滑鼠按鍵時，改成按下該滑鼠鍵 → 往**游標的反方向** `add_impulse()`（方向用 `Aim.toward_mouse()`），
游標剛好在角色身上不噴。方向鍵與滑鼠鍵都透過 `InputRouter` 綁定；同一幀按下的方向先疊加，`apply()` 裡只噴一次（保留斜角）。
每次噴射消耗一次，`refill_on_land` 開啟時著地即補滿。次數用完時 `visual` 短暫閃灰提示。
**遊玩空間必須夠開闊**，否則這張卡玩不動。
事件：`recoil_fired`、`recoil_empty`

#### 6. 彈珠台體質 `Mechanic_PinballBody`
```gdscript
## 碰到敵人或尖刺時被彈開的力道
@export_range(300.0, 1500.0) var knock_force: float = 800.0
## 碰到敵人時要不要被擊飛
@export var enemy_knocks: bool = true
## 碰到尖刺、岩漿時要不要被擊飛
@export var hazard_knocks: bool = true
## 被擊飛後幾秒內不會被同一次碰撞連續觸發
@export_range(0.1, 1.0) var invincible_seconds: float = 0.3
```
`ctx.damage_scale = 0`。碰到 group `enemy` / `hazard` 時，沿碰撞法線加一點向上偏移
`add_impulse()`。擊飛後的無敵時間避免同一次碰撞連續觸發（見 `01a_shared_systems.md` §2 的
group 定義）。
掉進深坑仍然照常重生。
事件：`knocked`

#### 7. 重力翻轉 `Mechanic_GravityFlip`
```gdscript
## 什麼時候會翻轉重力
@export_enum("按下按鍵", "落地時", "撞牆時") var trigger_timing: int = 0
## 按下按鍵時要按哪一鍵翻轉（只有「觸發時機」選按下按鍵時才會顯示這一欄）
@export var key: Key = KEY_SHIFT
## 翻轉之後多久內不能再翻轉
@export_range(0.1, 1.0) var cooldown: float = 0.3
```
`trigger_timing` 為「按下按鍵」時，用 `InputRouter.bind_input(self, input_type, key, ...)` 綁定學員自選的按鍵（`input_type` 可選滑鼠按鍵，見 `01a_shared_systems.md` §3.1）；
`key` 欄位用 `_validate_property` 依 `trigger_timing` 決定要不要顯示，同 `01c_blocks_and_abilities.md`
的 `KeyTrigger` 手法。呼叫 `player.flip_gravity()`。翻轉時 `visual` 要同步上下翻（`scale.y *= -1`）。
事件：`flipped`

#### 8. 彈性宇宙 `Mechanic_BouncyWorld`
```gdscript
## 碰撞後反彈的速度保留比例，數值越大彈越高
@export_range(0.3, 1.5) var bounciness: float = 0.9
## 站在地板上時要不要也會彈起來
@export var floor_bounces: bool = true
```
碰撞時取法線反彈（`velocity.bounce(normal)`，CharacterBody2D 不吃 PhysicsMaterial）。
**必須設下限**：速度低於閾值就停止彈跳，否則會永遠抖動。
撞到 group `no_bounce` 的東西（`blocks/NoBounceBlock.tscn`）不彈，照一般碰撞停下來。
事件：`bounced`

#### 9. 越跑越快 `Mechanic_SpeedRamp`
```gdscript
## 速度最多可以加到原本的幾倍
@export_range(1.0, 5.0) var max_multiplier: float = 3.0
## 從最低速加到最高倍率要花幾秒
@export_range(1.0, 20.0) var ramp_seconds: float = 10.0
## 目前的速度倍率會讓跳躍力增加多少，0 表示跳躍不受影響
@export_range(0.0, 1.0) var speed_affects_jump: float = 0.5
## 停下來時倍率要不要歸零重新累積
@export var reset_on_stop: bool = true
```
持續移動時倍率累加，`ctx.speed_scale = 當前倍率`。
`ctx.jump_scale = 1 + (當前倍率 - 1) × speed_affects_jump`，設為 0 時跳躍不受影響。
`reset_on_stop` 開啟時，水平速度接近 0 即歸零。
事件：`speed_max`（第一次達到最高倍率）、`speed_reset`

#### 10. 忽大忽小 `Mechanic_SizeShift`
```gdscript
## 什麼時候切換大小
@export_enum("按下按鍵", "隨時間") var trigger_timing: int = 0
## 按下按鍵時要按哪一鍵切換（只有「觸發時機」選按下按鍵時才會顯示這一欄）
@export var key: Key = KEY_SHIFT
## 變小時的體型倍率
@export_range(0.3, 1.0) var small_scale: float = 0.5
## 變大時的體型倍率
@export_range(1.0, 2.5) var big_scale: float = 1.8
## 體型是否連動推力、擊退、跳躍力
@export var size_affects_stats: bool = true
```
`trigger_timing` 為「按下按鍵」時用 `InputRouter.bind_input(self, input_type, key, ...)` 綁定學員自選的按鍵，
`key` 欄位同重力翻轉卡用 `_validate_property` 依 `trigger_timing` 決定要不要顯示；「隨時間」則每 3 秒
自動切換，不顯示 `key`。**這張卡「按下按鍵」模式下同時顯示 5 個欄位（超出其餘卡片的 4 欄慣例）**，
是本規格唯一的例外，因為要同時保留既有的雙觸發模式與可自訂按鍵，兩者都不宜拿掉。
呼叫 `player.set_size_factor()`。**必須改 CollisionShape2D 的尺寸，不要縮放整個物理節點**；
變大、變小都是腳底不動、往頭頂伸縮（重力翻轉後一樣往頭頂），站在地上也能直接變大；
變大時若會與地形重疊，延後到空間足夠時才套用；等待中再按一次＝取消變大（發 `grow_canceled`，不算變小、不發 `shrank`）。

`size_affects_stats` 開啟時：

- 大隻：`ctx.push_scale` 提高（推得動箱子）、`ctx.knockback_scale` 降低、`ctx.jump_scale` 降低
- 小隻：`ctx.jump_scale` 提高、`ctx.knockback_scale` 提高（容易被敵人撞飛）

事件：`grew`、`shrank`、`grow_canceled`

### 規則卡

#### 11. 黏黏身體 `Mechanic_StickyBody`
```gdscript
## 最多可以黏著幾秒，0 表示不限時間
@export_range(0.0, 5.0) var max_stick_seconds: float = 0.0
## 按跳躍脫離黏著時的力道
@export_range(200.0, 1000.0) var release_force: float = 500.0
## 天花板要不要也能黏住
@export var ceiling_sticks: bool = true
```
碰到任何表面 → 記下法線、速度歸零、`ctx.gravity_scale = 0`、`ctx.input_locked = true`。
按跳躍 → 往法線方向加一點向上偏移 `add_impulse()`，並給 0.2 秒不可再黏的冷卻。
`max_stick_seconds` 為 0 代表不限；逾時自動脫落。
黏在移動平台上時要跟著平台移動（記錄碰撞物與相對位置）。

#### 12. 移動會扣血 `Mechanic_Stamina`
```gdscript
## 體力可以支撐移動幾秒
@export_range(1.0, 10.0) var stamina_seconds: float = 3.0
## 停下來時體力回復的速度倍率
@export_range(0.5, 3.0) var regen_rate: float = 1.0
## 體力耗盡時的懲罰方式
@export_enum("走不動", "變很慢") var penalty_mode: int = 0
## 要不要在畫面上顯示體力條
@export var show_stamina_bar: bool = true
```
以水平速度判斷是否在移動（而不是讀輸入），這樣搭配任何主限制卡都成立。
移動時扣體力，停下時回復。耗盡時 `ctx.speed_scale` 降到 0 或 0.3，回復到 30% 才解除。
體力條由組件自己生成 `CanvasLayer`。

#### 13. 碰觸即死 `Mechanic_TouchDeath`
```gdscript
## 碰到 group enemy 的物件會不會死
@export var die_on_enemy: bool = true
## 碰到 group box 的物件會不會死
@export var die_on_box: bool = true
## 碰到 group wall 的物件會不會死
@export var die_on_wall: bool = false
```
用 group 判定（`enemy` / `box` / `wall`，定義見 `01a_shared_systems.md` §2），不綁特定物件。
`hazard` 一律致死。
直接呼叫 `kill()`，因此不受彈珠台體質的傷害歸零影響。

#### 14. 存活計時 `Mechanic_SurvivalTimer`
```gdscript
## 存活幾秒後算過關
@export_range(5.0, 60.0) var target_seconds: float = 10.0
## 要不要在畫面上顯示倒數計時
@export var show_timer: bool = true
```
達標 emit `Events.level_cleared`。計時器 UI 由組件自己生成 `CanvasLayer`，學員不用擺。

#### 15. 停下即死 `Mechanic_StopDeath`
```gdscript
## 最多可以靜止不動幾秒
@export_range(0.5, 5.0) var max_idle_seconds: float = 1.5
## 超過時間之後的懲罰方式
@export_enum("直接死亡", "持續扣血") var penalty_mode: int = 0
## 快要超過時間時角色要不要閃紅警告
@export var show_warning: bool = true
```
`show_warning` 開啟時，接近逾時讓 `visual` 閃紅。
同一個 Player 上有蓄力青蛙跳且 `is_charging == true` 時，暫停計時。

#### 16. 血量流失 `Mechanic_HealthDrain`
```gdscript
## 每秒自動扣多少血
@export_range(0.5, 10.0) var damage_per_second: float = 1.0
## 撿到一枚金幣補多少血
@export_range(0.5, 10.0) var heal_per_coin: float = 2.0
## 要不要在畫面上顯示血條
@export var show_health_bar: bool = true
```
持續呼叫 `player.take_damage(damage_per_second * delta)`，血量走 `01a_shared_systems.md` §4.5
的 `Stats` 流程，本卡**不自帶血量上限**（血量上限由場景的 `ValueSettings` 設定）。
歸零時走既有的 `kill()` 流程。
碰到 group `coin` 的物件時補血（若地基已有 `Events.item_collected` 則直接訂閱）。

#### 17. 地板是岩漿 `Mechanic_FloorIsLava`
```gdscript
## 站在扣血地板上時每秒扣多少血
@export_range(0.5, 10.0) var damage_per_second: float = 2.0
## 扣血地板的判定範圍
@export_enum("只有岩漿地板", "所有地板") var scope: int = 0
## 要不要在畫面上顯示血條
@export var show_health_bar: bool = true
```
- `只有岩漿地板`：接觸 group `lava` 的地形才扣血。
- `所有地板`：站在任何地面上都扣血，group `safe` 的平台除外。

同樣透過 `player.take_damage()` 走 `Stats` 的血量，**不自帶血量上限**。

#### 18. 開關世界 `Mechanic_SwitchWorld`
```gdscript
## 紅藍方塊多久切換一次
@export_range(0.5, 5.0) var switch_seconds: float = 2.0
## 遊戲開始時哪個顏色是實體
@export_enum("紅色先", "藍色先") var start_color: int = 0
## 切換前方塊要不要先閃爍提示
@export var blink_before_switch: bool = true
```
控制場景中所有 `blocks/SwitchBlock.tscn`（Inspector 用下拉選紅或藍，自動加入 group `switch_red` /
`switch_blue`，見 `01c_blocks_and_abilities.md`）。
未啟用的顏色：關閉碰撞、透明度降到 0.3。
**方塊實體化時若與玩家重疊，該方塊延後到玩家離開才實體化**，避免把玩家卡進去。
場景中找不到任何 SwitchBlock 時，輸出中文警告。

---

## 4. 組合衝突處理

原則：**任意組合都不崩潰**；會互相抵銷的組合必須在輸出面板印中文警告，不准靜默失效。
兩者行為衝突時，**規則卡優先**（它是關卡的「轉」）。

| 組合 | 處理方式 |
|---|---|
| 蓄力青蛙跳 × 停下即死 | 自動處理：蓄力中暫停計時 |
| 只能往前 × 移動會扣血 | 自動處理：改為每次跳躍扣固定體力，並印提示 |
| 只能往前 × 停下即死 | 警告：「自動奔跑不會停下，停下即死不會觸發」 |
| 只能往前 × 黏黏身體 | 警告；黏住期間暫停自動奔跑 |
| 彈性宇宙 × 黏黏身體 | 警告；黏黏身體優先，彈性暫停 |
| 彈珠台體質 × 碰觸即死 | 自動處理：`kill()` 繞過傷害歸零，碰觸即死生效 |

線上抽卡工具請直接排除會印警告的組合。
抽卡場景：主限制卡用 `levels/CardDraw.tscn`；規則卡用 `levels/RuleCardDraw.tscn`（先選主限制卡，衝突的規則卡不會抽到），
衝突清單寫在 `data/rule_cards.tres` 每張卡的 `conflicts_with`。

---

## 5. 備品庫 `mechanics/_extra/`

學員最常許願的東西，先做好藏著，課堂上有人問就當場拖給他（30 秒解決，不用坐下來寫程式）。
**不列在抽卡池裡，不在課堂上主動介紹。**

| 檔名 | 說明 |
|---|---|
| `Extra_DoubleJump` | 二段跳 |
| `Extra_Dash` | 衝刺 |
| `Extra_WallJump` | 蹬牆跳 |
| `Extra_StickyFloor` | 黏黏地板（踩上去變慢／黏住） |
| `Extra_Magnet` | 磁力吸附附近箱子 |
| `Extra_TimeSlow` | 按鍵子彈時間 |
| `Extra_StompOnly` | 純靠踩怪起飛（基礎跳躍力為 0，只能踩怪反彈），給想挑戰的老手 |
| `Extra_Molt` | 脫殼：縮小（或按鍵）時在原地留下一顆殼，Q／E 切換殼的種類（見 §5.1） |

規格與正式卡相同（繼承 `MechanicBase`、中文 tooltip、英文變數名，欄位數量不設上限）。
例外：脫殼卡欄位較多（觸發、脫出方向、切換殼、死亡處理），用 `@export_group` 分組，依選項隱藏用不到的欄位。

### 5.1 脫殼卡 `Extra_Molt`

社員提案「放大縮小（脫殼）」：縮小的那一刻在原地留下一顆跟大隻一樣大的殼，玩家依方向鍵往某個方向脫出去。
分三層，學員都不用連線、不用填路徑：

| 層 | 誰負責 | 內容 |
|---|---|---|
| 觸發 | 脫殼卡 | 什麼時候脫殼、往哪個方向脫出 |
| 管理 | 脫殼卡 | 選哪種殼、數量限制、玩家死掉時怎麼處理 |
| 殼的特性 | 殼（`Shell`）＋特性組件（`Trait_*`） | 會不會掉、能不能推、碰到會怎樣、長什麼樣子 |

**脫殼卡的欄位**

| 欄位 | 說明 |
|---|---|
| `trigger_timing` | 縮小時（聽 `Events.mechanic_event("Mechanic_SizeShift", "shrank")`，不直接引用忽大忽小卡）／按下按鍵（預設 C，可改滑鼠鍵）。選縮小時但場景裡沒有忽大忽小卡 → 黃色驚嘆號＋中文警告 |
| `direction_order` | 同時按著好幾個方向鍵時先看哪個方向（預設 上 > 左右 > 下） |
| `strength` | 脫出去的力道，0＝留在原地 |
| `start_inside` | 勾＝脫殼那一刻窩在殼裡慢慢鑽出來（預設）；不勾＝直接擠到殼外面，脫出方向被地形擋住時退回窩在殼裡 |
| `default_direction` | 擠到殼外面又沒按方向鍵時往哪邊（上／面向的方向／背對的方向／下），`start_inside` 不勾才出現 |
| `prev_key`、`next_key` | 切換殼（預設 Q／E），順序＝卡片底下殼的順序 |
| `show_selected` | 選中的殼怎麼顯示：玩家頭上（預設，只有一種殼又不限次數時不顯示）／畫面右上角／兩個都要／不顯示 |
| `on_death` | 玩家死掉時：重生時清掉（預設）／死掉時馬上清掉／保留。清掉時可脫次數一起恢復 |

公開函式 `clear_shells()`：把殼全部碎掉、次數恢復，可以被其他零件的訊號呼叫。

**殼的種類＝脫殼卡底下的 `Shell` 子節點**，脫殼時複製一份放進關卡。卡片底下沒有殼時用內建的三種
（`mechanics/_extra/_molt/`）：

| 殼 | 設定 |
|---|---|
| `Shell_Cicada` 蟬殼 | 什麼都不加（會掉、推得動、可以站上去） |
| `Shell_Plastic` 塑膠殼 | 加 `Trait_Bouncy`：玩家、箱子、其他殼從上面落下來會被彈起，比一般跳躍高 |
| `Shell_Spider` 蜘蛛殼 | `use_gravity`、`can_push` 都關：停在脫下來的地方、推不動、可以站上去 |

**殼 `Shell` 的欄位**：`use_gravity` 會不會掉、`can_push` 推不推得動；`max_count` 同種殼最多幾顆、
`count_scope` 每個房間／整個關卡（房間＝脫殼當下殼所在的房間）、`when_full` 最舊的碎掉／不能再脫、
`max_uses` 總共可以脫幾次（0＝不限）；`color` 預設方框顏色（選「自訂」出現 `custom_color` 調色盤，可以貼色碼）。
訊號 `broken`（碎掉時，碎掉就是直接消失，特效由學員之後自己接）。

**自己做一種殼（學員操作）**

1. 把 `mechanics/_extra/_molt/Shell.tscn`（或內建的三種殼）拖到 Player → Mechanics → `Extra_Molt` **底下**。
   放幾顆就有幾種，上下順序就是 Q／E 切換的順序。
2. 點選這顆殼，在 Inspector 調物理、數量限制、顏色。
3. 想要特殊效果：把 `mechanics/_extra/_molt/` 裡的特性（`Trait_Bouncy`…）拖到這顆殼**底下**。
4. 想換外觀：在殼底下加一個 `Sprite2D` 放自己的圖，預設方框就不會畫。
5. 卡片底下放了不是殼的東西 → 場景樹上卡片有黃色驚嘆號、執行時輸出面板有中文警告。

**自己做一種特性（程式作者）**：新增 `mechanics/_extra/_molt/_scripts/Trait_Xxx.gd` 繼承 `ShellTrait`，
在 `_on_setup()` 做初始化，用 `shell` 拿到所在的殼（`get_body_size()`、`is_ignoring(body)`、`break_shell()`），
再做一個根節點掛這個腳本的 `Trait_Xxx.tscn` 放外層給學員拖。不要在程式裡寫 `if 殼種類 == …`。
特性放錯位置（不在殼底下）會印中文警告。煙霧測試掃 `mechanics/` 時會跳過根節點不是機制卡的場景（殼、特性）。

---

## 6. 驗收條件

- [ ] 18 張卡各自單獨掛上，跑滿 60 幀不報錯（煙霧測試會自動掃 `mechanics/` 底下所有 `.tscn`）
- [ ] 任選 1 張主限制卡 + 1 張規則卡同時掛上，遊戲不崩潰
- [ ] 第 4 節的衝突組合：自動處理的有正確行為，需要警告的有中文警告
- [ ] 每張卡的 `enabled` 在執行中關閉，`ctx` 完全還原、生成的 UI 被移除
- [ ] 每張卡的 Inspector 都是英文變數名 + 中文 tooltip、都不需要打字（欄位數量不設上限）
- [ ] 把任一張卡拖到錯誤位置，輸出面板有中文警告
- [ ] 彈性宇宙不會無限抖動；忽大忽小不會把角色卡進地形；開關世界不會把角色卡進方塊
- [ ] 黏黏身體黏在移動平台上會跟著移動
- [ ] 主限制卡在指定瞬間 emit `Events.mechanic_event`
- [ ] 血量流失、地板是岩漿正確讀寫 `Stats` 的血量，不自帶「總血量」欄位
- [ ] 蓄力青蛙跳只攔截跳躍鍵、不影響移動（除非 `lock_move_while_charging` 開啟）
- [ ] 重力翻轉、忽大忽小在「按下按鍵」模式下，`key` 欄位可以正常切換按鍵並生效；改成其他觸發時機時
      `key` 欄位正確隱藏
- [ ] 整包能成功 Web export
- [ ] 每張主限制卡至少能跟三個以上不同情境產生可觀察的不同結果 —— **實際練習場景待
      `01d_showroom_and_toybox.md` 的 Gym/Showroom 定位討論後才能定出具體驗收方式，此項暫列為待驗證**

---

## 7. 待討論

（本規格未新增獨立的待討論項目；跟卡牌相關的開放問題已併入第 6 節最後一條，實際場景定位見
`01d_showroom_and_toybox.md` 的待討論清單。）
