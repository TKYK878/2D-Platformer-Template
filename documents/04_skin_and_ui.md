# 04 — W4：套皮與 UI（Skin & UI）

> 前置閱讀：`CLAUDE.md`、`documents/01a_shared_systems.md`（§4 數值、§4.4 HUD）、`documents/03_game_feel_juice.md`（§2.1 表現層 API）

這份規格讓學員把原型「換成自己的樣子」：畫面上的 UI（HUD、暫停選單、過關畫面）、零件與敵人的外觀、
角色動畫、地形圖塊。玩法完全不變。

---

## 1. 設計原則

- **不套皮也能玩**：所有新接口空白的時候，畫面跟 W3 一模一樣。沒參加 W4 的學員、中途加入的學員不受影響。
- **學員改的東西都在 `_my/`**：範本放在唯讀區，學員在檔案系統對範本按右鍵 →「再製」，存到 `_my/` 底下再改
  （講師決定：用「再製」，不用「新增繼承場景」）。改好的場景用「拖」接上去，不打路徑。
- **通用零件＋自己綁數值**（講師決定）：不幫每一種 UI 做好成品，而是提供幾種通用的顯示零件（條、數字、圖示排、文字），
  學員選要顯示哪個數值，自己組出想要的畫面。之後新增的機制卡只要「公開」自己的數值，不用另外做 UI。
- **零連線**：顯示零件靠名稱／下拉選單找到資料，不連訊號、不填路徑。按鈕的功能用下拉選，不連 `pressed`。
- **改壞看得見**：接上去的場景不對（類型錯、缺東西）時黃色驚嘆號＋中文警告，並改用預設照常運作。
- **外觀用 Godot 原生屬性改**：位置用滑鼠在 2D 畫面拖、大小拉、圖片和字型從檔案系統拖進欄位。
  不另外發明一套設定，學員學到的就是 Godot 本身的操作。
- **一套程式**（講師決定）：現在程式生出來的舊版 UI，改由 `ui/templates/` 的範本場景實作，長相跟現在一模一樣。
  沒接自訂 UI 時系統自動用範本；學員再製出來的版本跟預設的行為保證一樣，修 bug 只要修一次。
- **弱電腦與 Web**：不用 shader；圖片建議用 PNG、像素圖，字型照專案規則（Cubic_11 用 12 的倍數）。

---

## 2. 公開數值（地基）

### 2.1 顯示來源 `HudData`

現在能顯示的資料散在各處：`Stats` 的數值、`ClearScreen` 自己算的時間與死亡次數、體力卡的體力、
存活計時卡的倒數、脫殼卡的剩餘次數。W4 統一成「顯示來源」，顯示零件只認這一個入口。

新增自動載入 `HudData`：

```gdscript
# 公開一個可以被 HUD 顯示的數值（機制卡、零件用這個），max_value 0 代表沒有上限
func publish(source_name: String, value: float, max_value: float = 0.0) -> void:

# 讀取某個顯示來源目前的值與上限，HUD 零件用這個
func get_value(source_name: String) -> float:
func get_max_value(source_name: String) -> float:

# 拿掉一個顯示來源（公開它的卡片、零件被拔掉時呼叫）
func remove_source(source_name: String) -> void:

# 這個顯示來源有沒有人公開過（拿來提示「找不到這個名稱」）
func has_source(source_name: String) -> bool:
# 目前所有顯示來源的名稱，找不到名稱時列出來給學員看
func get_source_names() -> Array:

# 學員的 HUD 零件認領一個來源（零件離開場景時自動放掉）；預設 UI 顯示前先問有沒有被認領
func claim(source_name: String, by: Node) -> void:
func is_claimed(source_name: String) -> bool:

# 這一輪重新開始：遊玩時間、死亡次數歸零（過關畫面按 R 再玩一次時呼叫）
func reset_run() -> void:

signal source_changed(source_name: String)
const PLAY_TIME := "遊玩時間"
const DEATHS := "死亡次數"
const STAMINA := "體力"
const SURVIVAL := "存活倒數"
const MOLT := "脫殼次數"
const TIMELINE := "時間軸"
```

- `Stats` 的所有數值種類自動算顯示來源（名稱就是 `kind`，顯示名稱用 `ValueSettings.display_name`）。
- 內建來源（固定名稱，學員從下拉選，不用打字）：

  | 來源 | 誰公開 | 值／上限 |
  |---|---|---|
  | 遊玩時間 | `HudData` 自己算（暫停中不算，`ClearScreen` 按 R 再玩一次時歸零；暫停選單的「整關重來」、死掉整關重來不歸零，同 W3） | 秒／無 |
  | 死亡次數 | `HudData` 聽 `Events.player_died`（歸零時機同上） | 次／無 |
  | 體力 | `Mechanic_Stamina` | 剩餘秒數／`stamina_seconds` |
  | 存活倒數 | `Mechanic_SurvivalTimer` | 剩餘秒數／`target_seconds` |
  | 脫殼次數 | `Extra_Molt` | 剩餘次數／上限 |
  | 時間軸 | `Timeline` | 目前秒數／無 |

- `ClearScreen` 改成讀 `HudData` 的遊玩時間與死亡次數，不再自己算（避免兩邊數字不一樣）。
- 之後新增機制卡要顯示數值時，只要 `HudData.publish()`，並把名稱加進內建來源的下拉清單。
- 卡片沒掛（例如沒有體力卡）時，那個來源不存在，綁它的零件照 §4.1 的「找不到來源」處理；卡片在遊戲中被拔掉時 `remove_source()`。
- 脫殼次數是「目前選中的殼」還能脫幾次，不限次數時是 0／0。時間軸只公開場景裡第一個時間軸的秒數（有好幾個時間軸時，其他的看不到）。

### 2.2 舊版 UI 一個一個讓位（講師決定）

學員的 HUD 有顯示某個來源時，那個來源的預設 UI 藏起來，不然會出現兩條血條：
- 學員的 HUD 有綁「體力」→ 藏起體力卡自己的體力條；沒綁的照舊顯示。學員不會因為漏放某個零件而「東西不見」。
- 判斷方式：自訂 HUD 開場時把自己底下所有顯示零件的來源登記到 `HudData`，預設 UI 顯示前先問 `HudData.is_claimed(source_name)`。
- 機制卡原本的「要不要顯示」勾選（`show_stamina_bar`、`show_timer`）照舊有效：不勾就是不顯示預設的，跟自訂 HUD 無關。
- 機制卡、零件的預設 UI 一律放進 `StatsHud.get_corner()` 的共用容器（右上角／左下角），好幾個同時出現時自動上下排。
  容器裡的東西不跟著卡片刪除，卡片被拔掉時自己 `queue_free()`。

---

## 3. 接上自訂 UI

### 3.1 兩種接法（講師決定：兩種都做）

| 接法 | 怎麼做 | 適合 |
|---|---|---|
| A. 欄位 | 關卡裡放一個 `UISettings`（`blocks/UISettings.tscn`），把改好的場景從檔案系統拖進 `hud_scene`／`pause_menu_scene`／`clear_screen_scene` | 快，關卡場景樹乾淨；暫停選單、過關畫面這種平常看不到的 |
| B. 直接放 | 把改好的場景直接拖進關卡的場景樹 | HUD：在編輯器裡就看得到疊在關卡上的樣子，可以直接擺位置 |

- 兩種同時接同一種 UI（例如 `UISettings` 有接 HUD，場景樹裡也放了一個 HUD）：用場景樹裡的那個，
  `UISettings` 出現黃色驚嘆號說明「已經有直接放進來的 HUD，這個欄位不會用到」。
- 欄位屬於「資源欄位例外」，規則同 `Juice_Particles.custom_particles`：拖錯類型的場景（例如把 HUD 拖進暫停選單欄位、
  拖進來的場景根節點不是 `UIRoot`）→ 黃色驚嘆號＋中文警告，改用預設範本。
- 一個關卡只能有一個自訂 HUD、一個暫停選單、一個過關畫面，多放的黃色驚嘆號、只用第一個。`UISettings` 也只能放一個。
- `UISettings` 等場景裡其他節點都準備好之後（下一幀）才把欄位的場景生出來，放在自己底下（`UIRoot` 會再自己移進 CanvasLayer）。
- 暫停選單、過關畫面的 `UIRoot` 遊戲開始時先藏起來，由暫停、過關的流程叫出來（U175、U176）。
- 暫停選單、過關畫面用接法 B 直接放的話，編輯器裡會一直蓋在關卡上面：`UIRoot` 在編輯器裡顯示，
  遊戲開始時自動藏起來，等到暫停／過關才出現。學員可以點場景樹上的眼睛圖示暫時藏起來編輯關卡。

### 3.2 過關畫面的欄位

`ClearScreen` 零件（關卡裡現有的那個）繼續負責過關的流程：暫停遊戲、R 鍵重來、`show_time`／`show_deaths`／`message` 欄位。
自訂過關畫面只管「長什麼樣子」，裡面的 `ClearStat` 零件讀 `ClearScreen` 的欄位決定要不要顯示。
所以 `message` 這些欄位留在 `ClearScreen`，不搬家；學員要改內容就改 `ClearScreen`，要改樣子就改自己的過關畫面。

---

## 4. UI 通用零件 `ui/`

所有零件都是 Godot 原生 `Control` 的子類別，外觀屬性（大小、字型、顏色、圖片、對齊）照 Godot 原本的 Inspector 改。
這份規格只定義「要顯示什麼」的欄位。`.tscn` 放 `ui/`，`.gd` 放 `ui/_scripts/`。

### 4.1 顯示零件

共通欄位：

```gdscript
## 要顯示哪一個數值：選「數值」再打名稱（例如金幣），或直接選內建的（遊玩時間、死亡次數、體力…）
@export_enum("數值", "遊玩時間", "死亡次數", "體力", "存活倒數", "脫殼次數", "時間軸") var source: int = 0
## 數值的名稱（source 選「數值」才出現；打字防呆同 ValueSettings.kind，用 NameCheck）
@export var kind: String = "血量"
## 數值變化時閃一下（變多閃白、變少閃紅）
@export var flash_on_change: bool = false
## 數值變少時抖一下
@export var shake_on_decrease: bool = false
```

| 零件 | 繼承 | 做什麼 | 自己的欄位 |
|---|---|---|---|
| `HudBar` | `TextureProgressBar` | 條：血條、體力條 | 填滿方向（Fill Mode）、圖片（Under／Progress，建議勾 Nine Patch Stretch）用原生屬性；沒放圖時自己畫，用 ProgressBar 的底與填滿樣式（跟現在的血條一樣、跟著配色），支援左到右／右到左／上到下／下到上；沒有上限的數值用出現過的最大值當滿格；找不到來源時畫空條加「?」 |
| `HudNumber` | `Label` | 數字 | `format`：數字／數字÷上限／分:秒；`show_name`：前面要不要加名字（數值用 `display_name`）。預設 `kind` 是金幣 |
| `HudIcons` | `HBoxContainer` | 一顆一顆的圖示（愛心、鑰匙） | `full_icon`／`empty_icon`（拖圖片，原本大小；空白畫 10×10 小方塊，顏色用配色的 accent／back）、`show_empty`（要不要畫扣掉的；沒有上限的數值不畫）、`max_icons` 拉桿（超過就只畫這麼多）；間距用原生的 Separation。圖示是內部子節點，不存進場景檔、不出現在場景樹；值有小數時捨去 |
| `HudText` | `Label` | 固定的一行字（標題、說明） | 只用原生 `text`（顯示文字例外），沒有共通欄位 |

- 編輯器裡也看得到預覽：`@tool`，在編輯器中用假資料顯示（例如血條半滿、數字 99），擺位置時才看得出大小。
- 找不到來源：編輯器黃色驚嘆號、執行時中文警告＋近似名稱建議，零件顯示「?」。
  - 編輯器：名稱空白一定抓得到；「關卡裡找不到這個數值」要零件在關卡裡才判斷得了（單獨編輯 HUD 場景時，場景裡沒有道具、`ValueSettings`）。
    HUD 場景放進關卡時看不到裡面的零件，所以 `UIRoot` 把底下零件的錯誤收集起來，掛在自己身上（寫成「零件名：…」）。
  - 執行時：數值種類還沒被用到（例如金幣還沒撿）但關卡裡有道具用到這個名稱，先顯示 0，不算找不到。
    內建來源找不到時，警告寫要掛什麼卡（例如「體力」要有 `Mechanic_Stamina`）。
  - 共通邏輯放在 `ui/_scripts/HudBinding.gd`（每個顯示零件帶一個），零件自己只管怎麼畫。
- 值改變時零件自己更新（聽 `HudData.source_changed`），不用連線。
- 零件發出 `amount_changed(old_value, new_value)`、`value_increased`、`value_decreased` 訊號（不叫 `value_changed`／`changed`：`HudBar` 繼承的 Range 已經有這兩個名字），
  想做更多效果（例如扣血時播音效）可以連到 Juice 的 `play()`。
- `flash_on_change`、`shake_on_decrease` 是 UI 自己的動畫，不受 Juice 總開關影響（總開關只管 Player → Juice）。

### 4.2 按鈕與設定零件

| 零件 | 繼承 | 做什麼 |
|---|---|---|
| `MenuAction` | `Button` | `action` 下拉：繼續遊戲／整關重來／離開遊戲（跟現在暫停選單同三個）。按下去就執行，不用連 `pressed`。「離開遊戲」在 Web 版自動藏起來 |
| `VolumeSlider` | `HSlider` | `bus` 下拉：主音量／音效／音樂。跟現在暫停選單的拉桿同一套存檔（`user://settings.cfg`） |
| `ClearStat` | `Label` | 過關畫面專用：`stat` 下拉：用了幾秒／死了幾次／製作者的話。照 `ClearScreen` 的勾選決定要不要顯示 |

### 4.3 整套換字型與配色（講師決定：做）

每個範本的根節點是 `UIRoot`（`Control`），欄位：

```gdscript
## 這是哪一種畫面（範本已經選好，不用改）
@export_enum("HUD", "暫停選單", "過關畫面") var kind: int = 0
## 這一整套 UI 用的字型，從檔案系統把字型檔拖進來；空白用專案預設的像素字
@export var font: Font
## 字的大小（像素字型請用 12 的倍數）
@export_range(12, 48, 12) var font_size: int = 12
## 配色：字、底色、按鈕、條的顏色一起換
@export_enum("預設", "暗色", "亮色", "復古綠", "糖果") var palette: int = 0
```

- 套用方式：`UIRoot` 依欄位在執行時建一份 `Theme` 套在自己身上，底下所有零件自動跟著變。
  學員不用碰 Godot 的 Theme 編輯器。`@tool`，編輯器裡改欄位馬上看得到。
- 個別零件想要不一樣的字或顏色，用原生的「主題覆寫」改（進階，不在課堂上教）；主題覆寫優先於 `UIRoot`。
- `font` 屬於資源欄位例外：拖錯類型 Inspector 本身就不會接受；空白用預設，不需要警告。
- 「預設」配色＝現在的樣子。
- `theme` 由欄位自動產生，不存進場景檔、Inspector 也不顯示。
- 遊戲開始時 `UIRoot` 如果不在 `CanvasLayer` 底下（接法 B 直接拖進關卡），自己移進一個新的 `CanvasLayer`，固定在畫面上；
  圖層照原本的預設 UI：HUD 1、過關畫面 10、暫停選單 20。
- 顯示零件畫自己的預設樣式時要用配色：`UIRoot` 套用後往下通知有 `_on_ui_root_changed(root)` 的零件，零件再呼叫
  `root.get_palette_color(role, fallback)`（角色：text、dim、panel、button、hover、pressed、accent、back）。零件不往上找根節點。

---

## 5. 範本場景 `ui/templates/`

| 範本 | `UIRoot.kind` | 內容（預設長相＝現在的樣子） |
|---|---|---|
| `HudTemplate.tscn` | HUD | 左上角血條（`HudBar` 血量）＋金幣（`HudNumber`） |
| `PauseMenuTemplate.tscn` | 暫停選單 | 半透明底、標題、三條 `VolumeSlider`、`MenuAction` 繼續遊戲／整關重來／離開遊戲、「Esc／P 繼續」提示 |
| `ClearScreenTemplate.tscn` | 過關畫面 | 「過關！」、`ClearStat` 時間／死亡次數／製作者的話、「按 R 再玩一次」提示 |

- 預設 HUD 範本只放血量（`HudNumber` 只有名字＋`HudBar`）和金幣（色塊＋`HudNumber`）；其他數值（鑰匙、學員自訂的數值）
  照現在的規則，第一次用到時由預設 HUD 自動加一列「色塊＋`HudNumber`」。每一列照原本的規則出現（`show_in_hud` 打勾或被用到過），
  被學員的 HUD 認領時藏起來（`HudData.claims_changed`）。
  學員的自訂 HUD **不會**自動加列：學員要顯示什麼就自己放零件（不然學員擺好的版面會被打亂）。
- 預設 HUD 的節點都標上 meta `hud_default`：裡面的零件不認領來源（不然預設的會讓位給自己）、不印「找不到來源」的警告，
  `UIRoot` 不算學員的自訂畫面。
- 認領在零件真的離開場景時才放掉；只是換位置（`UIRoot` 自己移進 CanvasLayer）不算。
- 按鍵（暫停的 Esc／P、過關的 R）由系統處理，不靠學員的按鈕，所以學員把按鈕全刪掉也不會卡死在畫面裡。
- 暫停、過關畫面的「暫停中也要能動」（`process_mode = ALWAYS`）由 `UIRoot` 自己設好，學員不用管。
- 現在的 `StatsHud`、`PauseMenu` 自動載入保留「什麼時候顯示」的邏輯，畫面改成實例化範本（或學員的場景）。

---

## 6. 換皮零件 `Skin`（講師決定：靜態與動畫都做）

現在所有零件、敵人、子彈都是 `ColorRect` 色塊，而且色塊在唯讀的零件場景裡面。W4 改成：

- 學員在**關卡裡**對零件的實例加一個子節點 `Skin`（`skins/Skin.tscn`，繼承 `Sprite2D`）或 `SkinAnimated`
  （`skins/SkinAnimated.tscn`，繼承 `AnimatedSprite2D`）。不用打開「可編輯的子節點」，加子節點本來就存在 `_my/` 的關卡裡。
- 零件開場時找自己底下有沒有 `Skin`／`SkinAnimated`：有的話藏起自己的 `ColorRect`，原本「變色、變淡、變灰」的狀態回饋改成作用在皮上。
- 沒有皮的零件照舊顯示色塊。皮放錯地方（不在零件底下、不在 Player → Visual 底下）→ 黃色驚嘆號。
- 碰撞範圍不跟著圖片變。`@tool`：皮在編輯器裡畫出原本色塊的外框當參考，教學時提醒「圖要畫在框裡」。

### 6.1 `Skin`（靜態圖）

```gdscript
## 平常的樣子：從檔案系統把圖片拖進來
@export var texture_normal: Texture2D
## 狀態改變後的樣子（終點踩到、按鈕亮起、門打開、重生點啟用、開關方塊切換…）；空白就用平常的圖再變色表示
@export var texture_active: Texture2D
## 要不要跟著零件左右翻（敵人轉向）
@export var follow_facing: bool = true
```

### 6.2 `SkinAnimated`（動畫）

- 學員在 `SpriteFrames` 裡做動畫，動畫名稱照固定清單取（跟 §7 角色動畫同一套規則）：
  - 一般零件：「平常」「啟動」（啟動＝狀態改變後，同 `texture_active` 的時機）
  - 敵人：「走路」「受傷」「死亡」（沒有「受傷」「死亡」就繼續播「走路」）
- 缺「平常」（或敵人缺「走路」）→ 黃色驚嘆號，列出現有的動畫名稱並附近似名稱建議（`NameCheck`）。
- `follow_facing` 同 `Skin`。

### 6.3 程式生出來的東西

子彈、近戰揮擊是遊戲中才生出來的，學員沒辦法事先加子節點。改成在「生它的人」身上加資源欄位：

| 生它的人 | 欄位 |
|---|---|
| `Ability_Ranged`、`EnemyShooter` | `bullet_texture` |
| `Ability_Melee` | `slash_texture` |

空白就用色塊，屬於資源欄位例外。脫殼卡的殼、跳字不在 W4 範圍（備品，平常不介紹）。

---

## 7. 角色動畫 `PlayerAnimator`（講師決定：方案一）

學員把 Player → Visual 底下的 `Sprite2D` 換成 `AnimatedSprite2D` 或加一個 `AnimationPlayer`（講師會教 Animation 怎麼用），
再把 `PlayerAnimator`（`juice/Juice_Animator.tscn`，節點名 `Juice_Animator`）拖進 Player → Juice 底下，就會依角色狀態自動切換動畫。

### 7.1 怎麼串接

- `PlayerAnimator` 是持續型 Juice（跟 W3 的組件同一套：拖進 Player → Juice 就生效、Juice 總開關關掉時停在「待機」）。
- 開場時在 Player → Visual 底下找播放器：先找 `AnimationPlayer`，沒有再找 `AnimatedSprite2D`。都沒有 → 黃色驚嘆號＋中文警告。
- 依角色狀態播放固定名稱的動畫：

  | 動畫名稱 | 什麼時候 | 缺的話 |
  |---|---|---|
  | 待機 | 站著沒動 | **必要**，缺了黃色驚嘆號、不播放 |
  | 跑步 | 在地面上移動 | 用待機 |
  | 跳起 | 在空中往上 | 用待機 |
  | 落下 | 在空中往下 | 用跳起 |
  | 受傷 | 受傷那一下（播完回到原本的狀態） | 不播 |
  | 死亡 | 死掉（停在最後一格，重生時回到待機） | 不播 |
  | 攻擊 | 近戰揮擊、射擊那一下（播完回到原本的狀態） | 不播 |

- 重力翻轉、自動奔跑、忽大忽小這些卡改的是 `Visual` 的 `scale`，跟動畫不衝突；W3 的擠壓、閃色、傾斜作用在
  `Visual` 的子節點上（`AnimatedSprite2D` 本身就是子節點），也不衝突。`AnimationPlayer` 動畫裡如果改了 `scale`／`modulate`，
  會跟 Juice 打架：文件提醒「動畫只改 frame（第幾格），不要改大小和顏色」，並在編輯器檢查動畫軌道，有改就黃色驚嘆號。
- 地基需要：`Ability_Melee`、`Ability_Ranged` 新增 `attacked` 訊號（揮擊／射擊那一下發出），`PlayerAnimator` 自己找到並聽它，不用學員連。
- 檢查動畫名稱時跟 §6.2 一樣：列出現有的名稱、附近似名稱建議（例如「跑」→「跑步」）。

### 7.2 自訂動畫

`PlayerAnimator` 提供 `play_custom(...)`：學員把任何訊號（例如二段跳卡的 `air_jumped`）連過去，
播放名稱叫「特殊」的動畫一次，播完回到原本的狀態。只有一個「特殊」槽，想要更多再擴充。

---

## 8. 地形圖塊

現在地形用 `art/default_tile.tres`（唯讀區），16×16 一格、`art/blocks.png`（128×64）。

- 提供 `art/tile_template.png`：跟 `blocks.png` 同樣格子配置的範本圖，每一格標好用途（實心、平台頂、裝飾…）。
- 學員流程：再製 `default_tile.tres` 到 `_my/` → 把自己照範本畫好的圖拖進去取代 atlas 圖片 → 關卡的 `TileMapLayer` 換成自己的圖塊。
  因為格子位置一樣，碰撞形狀不用重畫。
- 背景圖：直接在關卡裡加 `Sprite2D`／`Parallax2D`，用 Godot 原生的做法，不另外做零件（教學文件補一頁）。

---

## 9. 學員操作流程（課堂 SOP）

1. 換 HUD：`ui/templates/HudTemplate.tscn` 右鍵「再製」→ 存到 `_my/` → 打開改（拖位置、換圖、加零件選數值）→ 把它拖進關卡。
2. 換暫停選單／過關畫面：同上，改好拖進 `UISettings` 的欄位。
3. 換零件外觀：在關卡裡選零件 → 從 `skins/` 拖 `Skin`（或 `SkinAnimated`）進去當子節點 → 把圖片拖進 `texture_normal`。
4. 換角色：Visual 底下換成 `AnimatedSprite2D`，照 §7.1 的名稱做動畫 → 拖 `PlayerAnimator` 進 Player → Juice。
5. 換地形：見 §8。

---

## 10. 起始場景與練習關（講師決定：要有練習關）

- `levels/_starts/W4_SkinBox.tscn`：W3_JuiceBox 的路線，HUD、暫停選單、過關畫面都接了一份示範用的自訂版本，
  幾個零件已經換皮、角色有動畫，給學員看「換完長什麼樣子」。
- `levels/_starts/W4_SkinPractice.tscn`：同樣的路線全部是預設樣子，天上放告示牌（沿用 W3 的 `PracticeSign`，`task` 下拉加 W4 題目），
  由淺到深出題，F6 自動檢查、做對變綠：
  1. 把終點換成自己的圖
  2. HUD 的血條換位置
  3. HUD 加一個金幣數字
  4. 血量改成愛心圖示
  5. 整套 UI 換字型／配色
  6. 角色有待機和跑步動畫
  7. 敵人換成會動的皮
  8. 暫停選單加一顆「整關重來」以外的按鈕排版（自由發揮，只檢查有接上自訂暫停選單）

---

## 11. 測試

- `tests/ui/`：每個 UI 零件一個場景（假資料預覽、綁錯名稱的警告、值變化時更新、閃一下／抖一下）。
- `tests/skins/`：每種狀態回饋的零件（終點、按鈕、門、重生點、開關方塊、敵人轉向）加 `Skin`／`SkinAnimated` 的樣子。
- `tests/juice/`：`PlayerAnimator` 的各狀態切換、缺動畫的退路、`AnimationPlayer` 與 `AnimatedSprite2D` 兩種。
- 煙霧測試：所有範本都接上去跑一次；`Skin` 加在所有零件上跑一次；拔掉所有接口跑一次（要跟 W3 一樣）；
  `PlayerAnimator` 依 Juice 的規則自動被掃到。

---

## 12. 驗收條件

- 不接任何東西時，W1～W3 的所有場景看起來、玩起來跟 W3 完全一樣。
- 每個接口拖錯、漏放、名稱打錯都有黃色驚嘆號或中文警告，而且遊戲照常跑。
- 學員只用「再製、拖、選、拉」就能完成 §9 的每一項。
- 煙霧測試通過。
