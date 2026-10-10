# 01c — W1：零件與攻擊能力

> 前置閱讀：`CLAUDE.md`、`documents/00_foundation.md`、`documents/01a_shared_systems.md`

這份規格定義 `blocks/`（互動零件）與 `abilities/`（攻擊能力）。零件跟機制卡不同——零件透過訊號連接
組合出關卡玩法，機制卡規格見 `documents/01b_mechanic_cards.md`。

---

## 1. 設計原則

- **零件是組合出來的**：每個零件在程式內部都是「身體 × 觸發 × 效果」的一組預設。組合只存在程式內部，
  學員永遠只看到包裝好的零件。
- **欄位數量不設上限**：同機制卡規則（講師決定）。變數名用簡單英文，每個欄位附中文 tooltip（`##` 文件註解），
  下拉選項用中文。
- **傳送門配對不算連動**：傳送門用節點欄位指定另一座，屬於設定而非函式呼叫，不算 `01a_shared_systems.md`
  §6 的訊號連接。
- **外觀交給 Modulate**：零件不額外提供顏色欄位。學員要把尖刺變成「熱平底鍋」，直接改 Visual 的
  `Modulate`（顏色選擇器，不用打字）。
- **死亡不重新載入場景**：有實體狀態的零件（箱子、敵人、道具、可破壞方塊、崩塌地板、移動平台位置、
  鑰匙／金幣門）各自實作 `reset()`，由 `RespawnHandler` 在重生時呼叫；被打倒、被撿走改成藏起來，不刪除節點。
  訊號控制的開關狀態（按鈕、訊號門、風扇、平台、彈射台、敵人射擊、尖刺、岩漿、傳送門的啟動開關）不重置。見 `00b_rooms_and_soft_respawn.md` §8。

零件之間怎麼用訊號連動、`Receiver` / `Hittable` 介面長怎樣、連線驗證器與視覺化怎麼運作，見
`01a_shared_systems.md` §6。

---

## 2. 零件清單 `blocks/`

全部為預製體，拖進場景即可使用。欄位名稱後的括號為中文 tooltip。

### 2.1 觸發類

| 零件 | 檔名 | 身體 | 欄位 | 訊號 |
|---|---|---|---|---|
| 按鈕 | `Button.tscn` | 感應 | `mode`（踩住才開／踩一下切換／踩一下永久開／被攻擊觸發）、`pressed_by`（玩家與箱子／只有玩家／只有箱子／指定群組）、`tag`（群組名稱，只在選「指定群組」時顯示）、`reset_on_death`（死亡重生時回到關著，預設不勾） | `turned_on`、`turned_off` |
| 按鍵觸發器 | `KeyTrigger.tscn` | 無 | `key_source`（自訂按鍵／滑鼠左鍵／滑鼠右鍵／滑鼠中鍵／跟基本操作同一顆鍵）、`key` 或 `same_key_as`（依來源顯示其一，選滑鼠按鍵時都不顯示）、`trigger`（按下時／放開時／按住時（每一幀）） | `triggered`（學員用）；進階：`pressed`、`released`、`hold_started`、`hold_ended`、`held(seconds)` |
| 傳送門 | `Portal.tscn` | 感應 | `pair`（目的地：另一座傳送門，或其他東西＝單向＋警告）、`keep_velocity`（保留速度，預設開）、`allow_boxes`（箱子也能傳）、`start_on`（一開始就開；關著時站進來不傳，但另一座傳過來照樣會出現）；可連接 `activate`、`deactivate`、`toggle` | `teleported` |
| 重生點 | `Checkpoint.tscn` | 感應 | 無 | `reached` |
| 終點 | `Goal.tscn` | 感應 | 無 | `reached` |
| 過關畫面 | `ClearScreen.tscn` | 無（畫面） | `show_time`（顯示用了幾秒）、`show_deaths`（顯示死了幾次）、`message`（最下面選填的一行字，可打字）；可連接 `activate`（顯示過關畫面） | 無 |
| 時間軸 | `Timeline.tscn` | 無 | `start_on`（開場就開始計時）、`on_death`（從 0 重來／繼續跑）、`loop`（跑完最後一個事件從頭再來）、`show_time`（畫面右上角顯示秒數）；可連接 `activate`（開始／繼續）、`deactivate`（暫停）、`toggle`、`restart`（從 0 重來） | 無（訊號在底下的事件） |
| 時間軸事件 | `TimelineEvent.tscn` | 無（放在 Timeline 底下） | `enabled`、`time`（從時間軸開始算起第幾秒觸發） | `triggered` |

- 按鈕的 `turned_on` / `turned_off` 依模式決定：踩住才開為壓下／離開；切換為每踩一次交替；永久為只發一次 `turned_on`。
- 按鈕的 `pressed_by` 選「指定群組」時，只有屬於 `tag` 群組的物體踩得動。群組由學員在「節點」面板 → 群組自己加在
  箱子、敵人等物體上（存在 `_my/` 的關卡場景裡）。`tag` 是打字欄位，依 `CLAUDE.md` 鐵律 4 做四點防呆：預設不選
  「指定群組」時完全看不到；`tag` 空白或場景裡沒有任何節點屬於這個群組時，編輯器顯示黃色警告；執行時印中文警告並
  列出場景中現有的群組、附近似名稱建議；比對前先整理名稱（`NameCheck`）。
- 按鍵觸發器的 `same_key_as` 與 `key` 用 `_validate_property` 依 `key_source` 顯示其中一個；選滑鼠按鍵時兩個都隱藏，改用 `InputRouter.bind_student_mouse()`。
- 傳送門：A 指定 B 後，B 自動連回 A；傳送後 0.3 秒內不會再次觸發，避免來回彈。
  `pair` 指定傳送門以外的 2D 節點時照樣傳到它的位置，但只能單向，編輯器黃色驚嘆號＋執行時中文警告；
  指定沒有位置的節點時不傳送並警告。編輯器裡從傳送門畫一條紫色細虛線到目的地。
- 終點踩到時變綠並 emit `Events.level_cleared`，整關重來時恢復（`reset()`）。W1 玩具箱不使用。
- 過關畫面拖進關卡就自動接 `Events.level_cleared`（終點、存活計時卡），不用連線；跳出時遊戲暫停，按 R（`restart` 動作）
  呼叫 `RespawnHandler.restart_level_now()` 整關重來（數值倒回、重生點清空），用了幾秒、死了幾次歸零。
  場景裡沒有過關畫面時：終點有黃色驚嘆號，過關當下 `RespawnMemory` 印中文提醒。沒有 RespawnHandler 時按 R 只關掉畫面並印提醒。
- 時間軸沿用「按鍵設定＋按鍵觸發器」的父子結構：`Timeline` 底下放 `TimelineEvent` 子節點，一個子節點一列，
  節點名稱＝這一列的名稱（例如「10秒開門」），要多一列就 Ctrl+D 複製。秒數一律是從時間軸開始算起的時間點
  （像影片時間刻度），不是等上一列之後幾秒，子節點上下順序不影響觸發時間（講師決定）。時間到時事件發出不帶參數的 `triggered`，
  學員照平常連按鈕的方式連到零件。編輯器裡在 Timeline 旁按秒數列出「秒數｜事件名稱」並畫訊號虛線。
  事件沒放在 Timeline 底下、Timeline 底下沒有事件或混進別的東西時有黃色驚嘆號＋中文警告；事件沒連線時印中文警告。
  `on_death` 聽 `Events.player_respawned`，不走 `reset()`（時間軸通常不在房間裡，不受房間與重生分組影響）。
  `loop` 的一輪長度＝啟用中事件的最大秒數，最大秒數是 0 時不重來。

### 2.2 接收類

| 零件 | 檔名 | 身體 | 欄位 | 可連接的函式 | 訊號 |
|---|---|---|---|---|---|
| 門 | `Door.tscn` | 實心 | `open_mode`（由訊號控制／鑰匙／金幣數量／自訂數值）、`custom_kind`（自訂的數值種類名稱，選「自訂數值」才出現，可打字）、`required_amount`（需要數量）、`consume`（打開時消耗）、`start_open`（一開始是開的） | `activate`、`deactivate`、`toggle` | `opened`、`closed` |
| 移動平台 | `MovingPlatform.tscn` | 會動 | `direction`（水平／垂直）、`distance_tiles`（移動格數）、`speed`（速度）、`start_active`（一開始就在動） | `activate`、`deactivate`、`toggle` | 無 |
| 風扇 | `Fan.tscn` | 感應 | `direction`（上／下／左／右）、`force`（力道）、`range_tiles`（範圍格數）、`start_on`（一開始就開） | `activate`、`deactivate`、`toggle` | 無 |
| 推力器（講師決定 U162） | `Pusher.tscn` | 無（範圍模式用感應區） | `target`（玩家／範圍內全部／範圍內的玩家／範圍內的箱子／範圍內的敵人）、`range_width`／`range_height`（範圍格數，選範圍才出現）、`direction`（八方向＋自訂）、`custom_x`／`custom_y`（-1～1 拉桿，選自訂才出現）、`strength`、`push_mode`（疊加在原本的速度上／先停住再推）、`on_gravity_flip`（跟著翻轉／不翻轉，只影響玩家） | `activate`（接任意參數） | `pushed(body)` |

- 門開啟時關閉碰撞、變半透明。鑰匙、金幣與自訂數值模式由玩家碰到門時檢查 `Stats`（見 `01a_shared_systems.md` §4）。
  自訂數值的名稱檢查同道具，但多一條：場景裡沒有道具或 ValueSettings 用這個名稱時也要警告（門會永遠打不開）。
- 推力器：玩家、敵人用 `add_impulse()`（敵人新增公開的 `add_impulse()`，推的 0.25 秒內不巡邏、不扣血），箱子這類 `RigidBody2D` 改
  `linear_velocity`，固定住的（蜘蛛殼）跳過。「先停住再推」＝把速度設成方向×力道。自訂方向兩個都是 0 時黃色驚嘆號＋中文警告、不推。
  不用「進階」的額外參數傳 Vector2：要打字、驗證器看不懂，違反鐵律 4。
- 移動平台 `activate` 為開始移動、`deactivate` 為停在原地；按鈕加移動平台即為電梯。

### 2.3 地形類

| 零件 | 檔名 | 身體 | 欄位 | 訊號 |
|---|---|---|---|---|
| 崩塌地板 | `CrumbleFloor.tscn` | 實心 | `break_delay`（碎裂延遲秒數）、`respawn_time`（重生秒數，0 為不重生）、`triggered_by`（只有玩家／任何物體） | `crumbled` |
| 單向平台 | `OneWayPlatform.tscn` | 實心（單向） | `width_tiles`（寬度格數） | 無 |
| 不反彈方塊 | `NoBounceBlock.tscn` | 實心 | `width_tiles`、`height_tiles`（寬高格數，編輯器即時顯示） | 無 |
| 岩漿 | `Lava.tscn` | 實心 | `damage_per_second`（每秒扣血）、`instant_kill`（即死）、`start_on`（一開始就開；關著時是普通地板）；可連接 `activate`、`deactivate`、`toggle` | 無 |
| 可破壞方塊 | `Breakable.tscn` | 實心 | `durability`（耐久次數）、`respawn_time`（重生秒數，0 為不重生）、`break_by_impact`（高速撞擊也能破壞）、`impact_speed`（撞擊速度門檻） | `broken` |
| 開關方塊 | `SwitchBlock.tscn` | 實心 | `color`（紅／藍） | 無 |

- 崩塌地板碎裂前要有抖動提示。
- 岩漿屬於 group `hazard` 與 `lava`（見 `01a_shared_systems.md` §2），站在上面持續扣血。
- 可破壞方塊實作受擊介面（`Hittable`）；`break_by_impact` 讓越跑越快、彈弓、後座力、彈珠台擊飛、
  落下的箱子都能撞破。
- 開關方塊由規則卡「開關世界」控制，規格見 `01b_mechanic_cards.md` #18。

### 2.4 物件類

| 零件 | 檔名 | 身體 | 欄位 | 訊號 |
|---|---|---|---|---|
| 箱子 | `Box.tscn` | 會動 | `weight`（輕／重）、`block_bullets`（會不會擋子彈，預設會） | 無 |
| 道具 | `Pickup.tscn` | 感應 | `kind`（金幣／鑰匙／血包／分數／自訂）、`custom_kind`（自訂的數值種類名稱，選「自訂」才出現，可打字）、`amount`（數量） | `collected` |
| 彈射台 | `Launcher.tscn` | 實心 | `mode`（彈簧／彈跳床）、`direction`（上／左／右）、`force`（力道）、`start_on`（一開始就開；關著時還是實心，只是不彈）；可連接 `activate`、`deactivate`、`toggle` | `launched` |
| 尖刺 | `Spike.tscn` | 感應 | `penalty`（扣血／即死）、`damage`（扣血量）、`knockback`（扣血時彈開玩家的力道，0 不彈開）、`start_on`（一開始就開；關著時碰到不會怎樣）；可連接 `activate`、`deactivate`、`toggle` | 無 |
| 笨敵人 | `Enemy.tscn` | 會動 | `speed`（速度）、`health`（血量）、`damage`（傷害）、`knockback`（碰到玩家時彈開的力道，0 不彈開）、`turn_at_ledge`（走到邊緣會轉身） | `defeated` |
| 敵人射擊 | `EnemyShooter.tscn` | 無（掛在 Enemy 底下） | 「射擊」組：`aim_type`（朝玩家／朝面向方向／固定往左右上下）、`cooldown`（射擊間隔）、`detect_range_tiles`（偵測格數，0 不限）、`stop_to_shoot`（開槍前停一下）、`start_on`（一開始就會開槍）；可連接 `activate`、`deactivate`、`toggle`；「子彈」組：`bullet_speed`、`use_gravity`、`damage`、`hit_objects`（會不會打壞物件） | `shot` |

- 箱子實作受擊介面，被攻擊時只受擊退。
- 道具：血包加血量，但不超過上限。種類選「自訂」時可以打數值種類名稱（`CLAUDE.md` 鐵律 4 的打字欄位，用 `NameCheck`）：
  名稱空白、或跟場景裡現有名稱很像但不一樣（疑似打錯字）時，場景樹出現黃色驚嘆號、執行時印中文警告並建議近似名稱；
  全新的名稱不算錯（撿到就出現在 HUD），執行時只印一行提示列出現有名稱。現有名稱 = 場景裡有 `get_value_kind()` 的節點
  （ValueSettings、道具…，用 `NameCheck.collect_value_kinds()` 收集）＋道具下拉選單內建的幾種。
- 彈射台：彈簧為固定力道；彈跳床為反彈落下速度，掉越高彈越高。
- 笨敵人撞牆轉身，實作受擊介面，血量歸零後消失（重生時照常復活）。
- 敵人射擊是笨敵人的攻擊組件：學員把它拖到關卡裡某個 Enemy 的底下（Enemy 實例的子節點，存在 `_my/` 的關卡場景，
  不動 `blocks/Enemy.tscn`）。Enemy 在 `_ready()` 掃子節點、之後新增的子節點也會掃，有 `setup()` 的就呼叫 `setup(self)`
  （零連線，比照 Player → Abilities）；`reset()` 時呼叫子節點的 `on_reset()`。Enemy 提供給組件的公開函式：
  `is_defeated()`、`get_facing()`、`hold_still(秒數)`（原地停下、不轉身）。
  射擊組件用 `Bullet.spawn()`（敵方陣營）從自己的位置射出，移動這個節點就是移動槍口；敵人被打倒時停火。
  「每個零件最多 4 個欄位」的例外：講師決定 8 個欄位全留，用 `@export_group` 分成「射擊」「子彈」兩組。
  沒放在 Enemy 底下：編輯器黃色驚嘆號＋執行時中文警告。編輯器裡畫出偵測範圍的圓與固定方向的箭頭。
  敵方子彈在玩家重生（`Events.player_respawned`）時全部消失。
- `collected`、`broken`、`defeated` 讓學員可以做出「打倒敵人就開門」「撿到道具就啟動平台」這類組合。

---

## 3. 攻擊能力 `abilities/`

不在卡池內，所有學員可自由使用。掛在 Player → `Abilities`（Player 節點結構新增的空節點，跟
`Mechanics`／`Juice` 平行，比照 `00_foundation.md` §3.1 的零連線發現機制註冊）。

| 能力 | 檔名 | 欄位 |
|---|---|---|
| 近戰 | `Ability_Melee.tscn` | `input_type`（鍵盤／滑鼠按鍵）、`key`（攻擊鍵，選鍵盤時才顯示）、`cooldown`（冷卻秒數）、`knockback`（擊退力道）、`damage`（傷害） |
| 遠程 | `Ability_Ranged.tscn` | `input_type`（鍵盤／滑鼠按鍵／只用訊號觸發）、`key`（攻擊鍵，選鍵盤時才顯示）、`bullet_speed`（子彈速度）、`cooldown`（冷卻秒數）、`lifetime`（存在秒數）、`max_range_tiles`（最大飛行格數，0 不限制）、`use_gravity`（受重力影響）、`aim_at_mouse`（朝滑鼠游標射）、`damage`（傷害）、`recoil_strength`（開槍後座力，0 代表沒有） |

不預先註冊共用的攻擊動作，`key: Key` 由學員在能力自己的 Inspector 選，透過
`InputRouter.bind_input(self, input_type, key, ...)` 綁定，`input_type` 可改選滑鼠左鍵／右鍵／中鍵（見 `01a_shared_systems.md` §3）。能力不算第 1 節「零件」，
不受「每個零件最多 4 個欄位」限制，5 個欄位是可接受的。

近戰的攻擊判定區跟遠程的子彈一樣是預製場景：`abilities/MeleeHitbox.tscn`（Area2D + CollisionShape2D + Visual），
畫成往右延伸，攻擊時由 `Ability_Melee` 生成、往左攻擊時 `scale.x = -1` 左右翻轉。攻擊範圍的大小與外觀
直接改這個場景，Inspector 不提供範圍拉桿。

- 近戰：按下 `key` 時在面向方向短暫生成判定區。
- 遠程：按下 `key` 時朝面向方向發射子彈，撞到地形或受擊物件即消失。`recoil_strength` 大於 0 時，開槍同時用
  `add_impulse()` 把玩家往射擊的反方向推。
- 遠程提供不帶參數的 `shoot()`，給學員從任何訊號連過來開槍（不看冷卻，節奏由發訊號的一方決定）。
  `input_type` 選「只用訊號觸發」時不綁按鍵；這時如果沒有任何訊號連到 `shoot()`，開場印中文警告。
  「只能靠開槍移動」＝後座力卡（滑鼠模式）的 `fired` 連到「只用訊號觸發」＋ `aim_at_mouse` 的遠程 `shoot()`，
  這時遠程的 `recoil_strength` 保持 0（推力由後座力卡負責，兩邊都推會推兩次）。
- 打到實作受擊介面（`Hittable`）的東西時呼叫 `take_hit()`。
- 子彈一律用 `Bullet.spawn(發射者, 方向, 速度, 陣營)` 產生（`abilities/_scripts/Bullet.gd`），遠程能力與敵人射擊共用。
  陣營 `Bullet.TEAM_PLAYER` 打敵人、箱子、物件；`Bullet.TEAM_ENEMY` 打玩家，不打其他敵人，
  可破壞方塊／按鈕這類物件只有 `hit_objects` 開啟時才會被打到（撞到仍會消失）。
- 瞄準方向一律用共用工具 `Aim`（`abilities/_base/Aim.gd`）：`toward_mouse()`、`toward_player()`、`toward_point()`、`facing()`，
  要新增瞄準方式只改這一份。
- 撞到的東西有 `block_bullets` 屬性且為 `false`（例如箱子關掉「會不會擋子彈」）時，子彈直接穿過去。
- 拖到錯誤位置時印中文警告，規則同機制卡。

---

## 4. 驗收條件

- [ ] `blocks/` 底下每個零件單獨拖進場景即可用，不用連線、不用填節點路徑
- [ ] 門、移動平台、風扇正確實作 `Receiver`（`activate`/`deactivate`/`toggle`），按鈕能透過訊號連接
      控制它們
- [ ] 可破壞方塊、笨敵人、按鈕（被攻擊觸發模式）、箱子正確實作 `Hittable`
- [ ] 崩塌地板碎裂前有抖動提示，`respawn_time` 為 0 時不重生
- [ ] 開關方塊在玩家重疊時延後實體化，不會把玩家卡進方塊
- [ ] 傳送門配對正確（A 指定 B 後 B 自動連回 A），傳送後 0.3 秒內不重複觸發
- [ ] 近戰、遠程能力打中 `Hittable` 物件時正確呼叫 `take_hit()`
- [ ] 把任一個零件或能力拖到錯誤位置，輸出面板有中文警告
- [ ] 任意零件與任意機制卡同時存在時不崩潰、不卡死；拔掉任一個零件遊戲仍能跑
- [ ] 煙霧測試涵蓋 `blocks/` 與 `abilities/` 底下所有 `.tscn`

---

## 5. 待討論

- [ ] 格子大小與角色尺寸（依 W4 素材包決定，會影響 `width_tiles`／`distance_tiles`／`range_tiles`
      等以「格」為單位的欄位怎麼定）
- [ ] 笨敵人是否可以被踩死
- [ ] 可破壞方塊的 `break_by_impact` 預設開或關
- [ ] 遠程攻擊是否只朝面向方向，或允許上下
