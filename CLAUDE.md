# 專案：五週遊戲原型工作坊 Godot 實驗包

這是一個給**完全沒寫過程式的大學社團學員**使用的 Godot 教學實驗包。
不是一般遊戲專案。下面每一條鐵律都有對應的實際教學事故，請嚴格遵守。

---

## 環境

- **Godot 4.7.2（非 .NET 版）**，版本鎖死，不要使用 4.8+ 或任何 4.7.2 以後的 API
- GDScript only，不使用 C#
- 目標平台：Windows 桌面 + Web（HTML5）
- 學員在學校電腦教室或自己的筆電，硬體普遍偏弱

---

## 最高原則

> 學員全程只做三個動作：**拖節點、選下拉選單、拉數值拉桿。**

任何設計都用這句話檢驗：這個操作能不能用滑鼠示範完，而且示範一次學員就會？

不能的話就是設計錯了，要改設計，不是改教學。

---

## 溝通語言

Claude Code 在這個專案裡的所有對話回覆、進度回報、驗收結果說明，一律使用**繁體中文**。
程式碼裡的識別字仍照下面「命名規範」執行（英文變數名、`@export` 欄位英文變數名搭配中文 `##` doc comment tooltip），這一條只規範跟使用者的溝通。

---

## 五條鐵律

### 1. 零連線

組件拖進場景就要生效，**學員不得手動連任何一條線、填任何一個節點路徑**。
上期用 Unity 時，講師整堂課都在幫學員檢查 UnityEvent 拉線有沒有拉對。

違反範例：`@export var target_node: NodePath`
正確做法：由 Player 主動發現子節點並呼叫其 `setup()`

### 2. 學員的檔案只在 `_my/`

`res://_my/` 以外的所有檔案都是**唯讀區**。
學員的任何操作（掛機制卡、調數值、蓋關卡、換素材）都必須只寫進 `_my/` 底下的場景檔。

這讓「重灌 SOP」成立：複製 `_my/` → 刪專案 → 重新解壓 → 貼回 `_my/`（30 秒）。

**所以：不要把學員會改的東西做進 `player/Player.tscn`。**
容器節點（Mechanics / Juice）和視覺節點都住在關卡場景裡，當 Player 實例的子節點。

### 3. 不可能出現「靜默失效」

學員拖錯位置、漏掉前置條件時，**必須有看得見的回饋**，不能只是沒反應。
沒反應 = 學員舉手 = 講師巡場時間，這正是要消滅的成本。

所有組件在 `setup()` 失敗時必須 `push_warning()` 並在 `_ready()` 印出中文訊息到輸出面板。

### 4. Inspector 全英文變數名 + 中文說明、打字只限名稱

所有 @export 欄位：

變數名用英文 snake_case，選字限定在新手能一眼猜到的簡單字（speed / strength / duration / enabled / delay / min_ / max_），避開 threshold、multiplier 這類詞
每個 @export 上方必須有 ## 文件註解寫中文說明，Inspector 滑過去會顯示為 tooltip
@export_group 的群組名用中文（參數是字串）
@export_enum 的選項用中文（參數是字串）
原則上只能是 @export_enum 下拉、@export_range 拉桿、或 bool 勾選框

**例外：名稱欄位可以打字。** 完全不能打字會讓組件無法擴充，學員想要的很多功能做不出來，所以
「名稱／標籤」類的欄位允許 `@export var xxx: String` 讓學員打字。名稱指的是學員自己取、無法
預先窮舉成下拉選單的識別名稱，例如數值種類（金幣、血量…）、群組名稱（Button 的偵測對象）。

以下仍然**禁止**打字：數值（一律用拉桿）、`NodePath` 或任何節點路徑（鐵律 1 不變）、
場景路徑、運算式或程式碼片段、函式名稱。

每個打字欄位都必須做到以下四點防呆，缺一不可：

1. **不打字也能用**：預設值要能直接運作，打字是進階選項。如果欄位只在某個下拉選項下才有意義，
   就用 `_validate_property()` 在其他選項下隱藏它，學員沒選到就看不到。
2. **編輯器裡就看得到錯**：組件加 `@tool`，實作 `_get_configuration_warnings()`，名稱空白或
   場景裡找不到對應名稱時，場景樹上直接出現黃色驚嘆號，不用等按 Play。
3. **執行時中文警告**：找不到對象就 `push_warning()`，訊息列出場景中現有的名稱，並附上
   「是不是想打『…』？」的近似名稱建議。
4. **自動清掉常見打錯**：比對前先去掉頭尾空白、全形英數字轉半形。

名稱的整理與近似比對一律呼叫共用工具 `NameCheck`，不要在組件裡各寫一份。
目前的打字欄位：`ValueSettings.kind`（數值種類，見 `documents/01a_shared_systems.md` §4.1）、
`Button.tag`、`Pickup.custom_kind`（種類選「自訂」才出現）、`Door.custom_kind`（開門方式選「自訂數值」才出現）（見 `documents/01c_blocks_and_abilities.md`）、`Juice_TextPopup.custom_kind`（種類選「自訂」才出現，見 `documents/03_game_feel_juice.md` §3.2）。新增打字欄位時要補進這份清單。

**顯示文字例外（講師決定）**：`ClearScreen.message`（過關畫面最下面製作者選填的一行字）是純顯示用的文字，不拿去比對任何東西，
所以只需要做到「不打字也能用（空白就不顯示）」和「去掉頭尾空白」，不需要編輯器檢查與近似建議。
`ValueSettings.display_name`（數值在 HUD、跳字上顯示的名字，空白就顯示 `kind`）同屬顯示文字例外（見 `documents/progress.md` U166）。

**資源欄位例外（講師決定）**：`Juice_Sound.custom_sound`（`AudioStream`）讓學員把自己的音檔從檔案系統拖進欄位，屬於「拖」而不是打字。
只在下拉選「自訂」時出現；空白時編輯器黃色驚嘆號＋執行時中文警告，並改用預設值照常運作（見 `documents/03_game_feel_juice.md` §3.1）。
`Juice_Particles.custom_particles`（`PackedScene`）同一套規則：學員把自己做的粒子場景拖進欄位，只在樣式選「自訂場景」時出現，
空白或根節點不是 `CPUParticles2D` 時黃色驚嘆號＋中文警告，改用塵土照常運作。
`Juice_BGM.music`（`AudioStream`）同屬資源欄位例外：學員把自己的音樂檔拖進來；沒有內建曲目，空白時黃色驚嘆號＋執行時中文警告、不播放（見 `documents/progress.md` U154）。
`UISettings.hud_scene`／`pause_menu_scene`／`clear_screen_scene`（`PackedScene`）同屬資源欄位例外：學員把從 `ui/templates/` 再製改好的場景拖進來；
空白就用預設的（不警告）；最上層不是 `UIRoot`、種類拖錯欄位、跟直接放進關卡的同一種畫面重複時，黃色驚嘆號＋執行時中文警告，改用預設的（見 `documents/04_skin_and_ui.md` §3.1）。
`Skin.texture_normal`／`texture_active`（`Texture2D`）同屬資源欄位例外：學員把圖片拖進來；`texture_normal` 空白時黃色驚嘆號＋執行時中文警告，零件照舊顯示色塊；
`texture_active` 空白就把平常的圖變色，不警告（見 `documents/04_skin_and_ui.md` §6.1）。

### 5. 組件之間不准打架

任意組合、任意數量的機制卡與 Juice 組件同時存在時，遊戲不得崩潰或卡死。
拔掉任何一個組件，遊戲仍必須能跑。

---

## 命名規範

| 對象 | 規範 | 範例 |
|---|---|---|
| 檔案／節點名 | 英文 PascalCase | `Mechanic_GravityFlip.tscn` |
| 組件檔案位置 | `.tscn` 放外層給學員拖，`.gd` 放同層 `_scripts/`（`mechanics/`、`juice/`、`blocks/`、`abilities/`、`ui/`、`skins/`，含 `_extra/`；見 `documents/00_foundation.md` §1） | `mechanics/Mechanic_GravityFlip.tscn`<br>`mechanics/_scripts/Mechanic_GravityFlip.gd` |
| 腳本內部變數、函式 | 英文 snake_case | `_on_landed`, `impact_force` |
| `@export` 欄位 | 英文 snake_case + 上方 `##` 中文 doc comment | `## 影響跳躍高度，數值越大跳越高`<br>`@export_range(0.0, 2.0) var strength` |
| `@export_enum` 選項字串 | **繁體中文** | `@export_enum("跳躍時", "落地時")` |
| 輸出面板訊息 | **繁體中文** | `print("[重力翻轉] 已啟用")` |
| 程式註解 | 繁體中文，規則見下方「函式註解規則」 | |

### 函式註解規則

- 每個函式上方加一行中文註解，說這個函式**在做什麼**，不解釋怎麼做。私有函式（`_` 開頭）也要加。
- 用 `#`，不要用 `##`——`##` 保留給 `@export` 欄位的 Inspector tooltip，不要跟函式註解混用。
- 公開 API（機制卡／Juice 作者會呼叫或覆寫的函式，例如 Player 提供的那些）要寫成**使用者看得懂的角度**：

  ```gdscript
  # 翻轉重力方向，重力翻轉卡用這個
  func flip_gravity() -> void:
  ```

- 不要加檔頭大段說明，不要加 `# ----` 分隔線以外的裝飾。

---

## 禁止事項

- ❌ 不要在組件裡寫 `get_parent().get_parent()` 或任何往上爬節點樹的程式碼
- ❌ 不要使用 `@onready var x = $"../../Something"` 這類相對路徑
- ❌ 不要讓組件直接寫入 `Player.velocity`，一律透過 Player 提供的公開 API
- ❌ 不要在 `player/Player.gd` 裡寫任何跟特定機制卡有關的邏輯
- ❌ 不得在 `Player.gd` 裡處理死亡後的流程，死亡一律透過 `Events` 廣播（`kill()` 只宣告死亡，重生由 `RespawnHandler` 這類處理者呼叫 `revive()`）
- ❌ 不要用 `reload_current_scene()` 或切換場景做重生／換關，一律在同一個場景內用 `Room` 與軟重生（見 `documents/00b_rooms_and_soft_respawn.md`）
- ❌ 不要新增需要學員安裝的外掛或 addon
- ❌ 不要用 Godot 3.x 的 API（`KinematicBody2D`、`move_and_slide(velocity, UP)` 舊簽章等）

---

## 驗證方式

Claude Code 無法目視確認畫面，所以每次改動後至少要跑：

```bash
# 語法與資源檢查（不開視窗）
godot --headless --check-only --path .

# 匯入資源並立刻退出，確認沒有匯入錯誤
godot --headless --import --path .

# 跑煙霧測試場景（自動測完退出，錯誤會印在 stdout）
godot --headless --path . res://_tests/SmokeTest.tscn
```

`_tests/SmokeTest.tscn` 的規格見 `documents/00_foundation.md`。
**任何新增的機制卡或 Juice 組件都必須加進煙霧測試的清單。**

---

## 開發順序

一次只做一週。不要提前實作未指定的週次。

1. `documents/00_foundation.md` — 地基（所有週次的前提）
   - `documents/00b_rooms_and_soft_respawn.md` — 地基增補：房間制、鏡頭瞬切、軟重生
2. W1（依序）：
   - `documents/01a_shared_systems.md` — 共用系統（輸入路由／數值／死亡重生／訊號連接）
   - `documents/01b_mechanic_cards.md` — 18 張機制卡（10 張主限制卡 + 8 張規則卡）+ 備品庫
   - `documents/01c_blocks_and_abilities.md` — 零件（`blocks/`）與攻擊能力（`abilities/`）
   - `documents/01d_showroom_and_toybox.md` — 展示間與玩具箱
3. W3：`documents/03_game_feel_juice.md` — 手感果汁（Juice 組件、表現層 API、音效素材）
4. W4：`documents/04_skin_and_ui.md` — 套皮與 UI（UI 範本與通用顯示零件、零件換皮、角色動畫、地形圖塊）
5. 之後的週次規格會在該週開課前才提供

---

## 工作流程（逐單元實作）

所有實作照 `documents/progress.md` 的單元（U01、U02…）進行：

- **一次只做一個單元**，做完就停，等使用者說「繼續」才做下一個。只改這個單元需要的檔案，不順手重構別的地方。
- **規格不清楚、或需要做決定時，停下來問**，不要自己猜。講師的決定寫進 progress.md 該單元底下（`　　→ 講師決定：…`）。
- 系統層級的單元（自動載入、跨組件機制）要附一個 `tests/` 底下的測試場景，讓使用者按 F6 手動驗證。
  `tests/` 依類別分資料夾（`systems/`、`mechanics/`、`mechanics/_extra/`、`blocks/`、`abilities/`、`juice/`、`juice/_extra/`、`ui/`、`skins/`），
  `.tscn` 放在類別資料夾，`.gd` 放在同層 `_scripts/`；場景腳本用 `print("[測試] …")` 印出操作步驟與預期結果。
- **做完回報**：做了什麼（1～2 句）、改了哪些檔案、怎麼驗證（哪個場景、做什麼、應該看到什麼）、已知限制。
- **使用者在編輯器驗收通過才 commit**，同一批把 progress.md 該單元打勾（`- [ ]` → `- [x]`）。
  「繼續」的意思是「開始下一個單元」，**不代表上一個驗收通過**；驗收要使用者明確說。
- 每個單元一個 commit，訊息以單元編號開頭（例如 `U108 MoveContext 倍率改成乘上去…`）。

### Godot 驗證

- 單元的驗收交給使用者在編輯器裡測，不需要每次都自己跑 headless。
- 整份規格的單元全部完成時，跑一次煙霧測試（加 timeout，例如 `timeout 200`），卡住就回報「逾時」，不要重跑。
- 使用者遇到 bug、請你自己跑看看時，可以用 headless 重現與除錯（一律加 timeout）。
- 小技巧：
  - 手動測試場景不會自己結束，headless 跑的時候加 `--quit-after <幀數>`；要自動結束的場景自己呼叫 `get_tree().quit()`。
  - 用 `-s` 跑臨時 `extends SceneTree` 腳本時，不能直接寫自動載入的名稱（`Stats`、`Events`…），要用 `root.get_node("Stats")`；
    臨時腳本用完要刪掉（含 `.uid`）。
  - 幫**已存在**的腳本加 `class_name` 後，編輯器的全域類別快取可能沒更新（出現「Identifier not declared」），
    跑 `godot --headless --editor --quit --path .` 重新掃描，並請使用者「專案 → 重新載入目前專案」。

---

## 背景脈絡

- 上期用 Unity，環境建置吃掉大半堂課、打包太慢導致最後一週取消上台報告
- 這期改 Godot 就是為了解決這兩件事
- 學員中會有人**中途才加入**，所以每週產出要能獨立展示
- 講師只有一個人加一位助教，現場約 10-15 人
- 課堂上**不鼓勵學員用 AI 寫程式**（新手無法判斷 AI 給的是 Godot 3.x 還是 4.x 的答案）