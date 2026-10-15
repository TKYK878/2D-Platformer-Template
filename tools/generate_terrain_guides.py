# 產生零件手冊 §7.4「自己設接邊規則」的對照圖：
#   art/terrain_rules_sides.png   只看四邊（16 格）每格要點哪些小方塊
#   art/terrain_rules_corners.png 四邊＋四角（47 格）每格要點哪些小方塊
# 用法：python tools/generate_terrain_guides.py（在專案根目錄）
from PIL import Image, ImageDraw, ImageFont

FONT = "C:/Windows/Fonts/msjh.ttc"
BG = (38, 40, 52)
TEXT = (235, 235, 240)
DIM = (150, 152, 165)
ON = (60, 150, 110)       # 點了：這個方向接著地面
OFF = (70, 72, 86)        # 沒點
CENTER = (80, 190, 140)   # 中間：這格是「地面」
GRID = (25, 26, 34)
TILE = (200, 200, 205)
EDGE = (225, 60, 55)      # 紅線：露在外面

U, D, L, R = "U", "D", "L", "R"
CORNERS = {"UL": (U, L), "UR": (U, R), "DL": (D, L), "DR": (D, R)}


def font(size):
    return ImageFont.truetype(FONT, size)


# 畫 3×3 的小方塊（Godot 圖塊集「繪製 → 地形」裡點的那些）
def draw_bits(d, x, y, s, sides, corners, show_corners):
    cells = {
        (0, 0): "UL", (1, 0): U, (2, 0): "UR",
        (0, 1): L, (1, 1): "C", (2, 1): R,
        (0, 2): "DL", (1, 2): D, (2, 2): "DR",
    }
    for (cx, cy), key in cells.items():
        if key == "C":
            color = CENTER
        elif key in (U, D, L, R):
            color = ON if key in sides else OFF
        else:
            color = (ON if key in corners else OFF) if show_corners else BG
        d.rectangle([x + cx * s, y + cy * s, x + cx * s + s - 1, y + cy * s + s - 1], fill=color, outline=GRID)


# 畫這格大概長什麼樣子：露在外面的邊畫紅線，內側轉角畫紅色小角（只看四邊時不畫）
def draw_tile(d, x, y, s, sides, corners, inner=True):
    d.rectangle([x, y, x + s - 1, y + s - 1], fill=TILE)
    t = max(3, s // 10)
    if U not in sides:
        d.rectangle([x, y, x + s - 1, y + t - 1], fill=EDGE)
    if D not in sides:
        d.rectangle([x, y + s - t, x + s - 1, y + s - 1], fill=EDGE)
    if L not in sides:
        d.rectangle([x, y, x + t - 1, y + s - 1], fill=EDGE)
    if R not in sides:
        d.rectangle([x + s - t, y, x + s - 1, y + s - 1], fill=EDGE)
    for key, (a, b) in CORNERS.items():
        if inner and a in sides and b in sides and key not in corners:
            cx = x if "L" in key else x + s - t
            cy = y if "U" in key else y + s - t
            d.rectangle([cx, cy, cx + t - 1, cy + t - 1], fill=EDGE)


SIDES_NAMES = {
    "": "單獨一格", "D": "柱子 上", "UD": "柱子 中", "U": "柱子 下",
    "R": "橫條 左", "LR": "橫條 中", "L": "橫條 右",
    "DR": "地面 左上", "DLR": "地面 上", "DL": "地面 右上",
    "UDR": "地面 左", "UDLR": "地面 裡面", "UDL": "地面 右",
    "UR": "地面 左下", "ULR": "地面 下", "UL": "地面 右下",
}


def key_of(sides):
    return "".join(c for c in "UDLR" if c in sides)


def sides_image():
    order = [
        ["DR", "DLR", "DL", "D"],
        ["UDR", "UDLR", "UDL", "UD"],
        ["UR", "ULR", "UL", "U"],
        ["R", "LR", "L", ""],
    ]
    bit, tile, pad = 22, 66, 18
    cw, ch = bit * 3 + tile + pad * 3, tile + 40
    top = 120
    w, h = pad + cw * 4, top + ch * 4 + 70
    img = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(img)
    d.text((pad, 14), "只看四邊（Match Sides）：16 格，每格點中間＋接著地面的那幾邊", font=font(22), fill=TEXT)
    d.text((pad, 50), "左邊的小方塊＝在圖塊集「繪製 → 地形」要點的地方；右邊＝這格大概要畫成什麼樣子", font=font(16), fill=DIM)
    draw_legend(d, pad, 80, False)
    for r, row in enumerate(order):
        for c, k in enumerate(row):
            x, y = pad + c * cw, top + r * ch
            sides = set(k)
            draw_bits(d, x, y + (tile - bit * 3) // 2, bit, sides, set(), False)
            draw_tile(d, x + bit * 3 + pad, y, tile, sides, set(), False)
            d.text((x, y + tile + 6), SIDES_NAMES[k], font=font(16), fill=TEXT)
    d.text((pad, h - 56), "名字跟 art/tile_template_guide.png 一樣；自己下載的圖排法不同沒關係，照「這格長什麼樣子」點就對了。", font=font(15), fill=DIM)
    d.text((pad, h - 32), "少畫幾種也能用，只是刷到那種形狀時會挑最接近的那格，看起來會怪。", font=font(15), fill=DIM)
    return img


def draw_legend(d, x, y, corners):
    items = [(CENTER, "中間：這格是地面（一定要點）"), (ON, "點了：這個方向接著地面"), (OFF, "沒點：這個方向是空的")]
    for color, label in items:
        d.rectangle([x, y + 3, x + 16, y + 19], fill=color, outline=GRID)
        d.text((x + 24, y), label, font=font(15), fill=TEXT)
        x += 24 + int(d.textlength(label, font=font(15))) + 30
    if corners:
        d.rectangle([x, y + 3, x + 16, y + 19], fill=EDGE)
        d.text((x + 24, y), "紅色小角：內側轉角", font=font(15), fill=TEXT)


# 四邊＋四角的 47 種：角只有在旁邊兩個邊都接著時才算數
def blob_combos():
    seen, out = set(), []
    for m in range(256):
        sides = {s for i, s in enumerate("UDLR") if m >> i & 1}
        corners = {c for i, c in enumerate(["UL", "UR", "DL", "DR"]) if m >> (4 + i) & 1}
        corners = {c for c in corners if CORNERS[c][0] in sides and CORNERS[c][1] in sides}
        key = (key_of(sides), "".join(sorted(corners)))
        if key not in seen:
            seen.add(key)
            out.append((sides, corners))
    assert len(out) == 47
    return out


def corners_image():
    combos = blob_combos()
    groups = [
        ("四邊都接（內側轉角 0～4 個）", lambda s: len(s) == 4),
        ("接三邊", lambda s: len(s) == 3),
        ("接兩邊（轉彎）", lambda s: len(s) == 2 and s not in ({U, D}, {L, R})),
        ("接兩邊（直的）、一邊、都不接", lambda s: len(s) < 2 or s in ({U, D}, {L, R})),
    ]
    bit, tile, pad, per_row = 16, 48, 14, 8
    cw, ch = bit * 3 + tile + pad * 3, tile + 14
    top = 150
    rows = []
    for title, f in groups:
        items = [c for c in combos if f(c[0])]
        items.sort(key=lambda c: (sorted(c[0]), -len(c[1]), sorted(c[1])))
        rows.append((title, [items[i:i + per_row] for i in range(0, len(items), per_row)]))
    h = top + sum(34 + len(chunks) * ch for _, chunks in rows) + 70
    w = pad + cw * per_row
    img = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(img)
    d.text((pad, 14), "四邊＋四角（Match Corners and Sides）：47 格，內側轉角也接好", font=font(22), fill=TEXT)
    d.text((pad, 50), "規則：先點中間和接著地面的邊；角只有「旁邊兩個邊都點了，而且斜對角那格也是地面」才點。", font=font(16), fill=DIM)
    d.text((pad, 76), "旁邊兩個邊有一個沒點，那個角就不用管（點不點都一樣，Godot 會當成沒點）。", font=font(16), fill=DIM)
    draw_legend(d, pad, 108, True)
    y = top
    for title, chunks in rows:
        d.text((pad, y), title, font=font(17), fill=TEXT)
        y += 34
        for chunk in chunks:
            for c, (sides, corners) in enumerate(chunk):
                x = pad + c * cw
                draw_bits(d, x, y + (tile - bit * 3) // 2, bit, sides, corners, True)
                draw_tile(d, x + bit * 3 + pad, y, tile, sides, corners)
            y += ch
    d.text((pad, h - 56), "47 格全畫很花時間：先畫每一組角全部點滿的那幾格（就是 16 格版的形狀），有紅色小角的之後再補。", font=font(15), fill=DIM)
    d.text((pad, h - 32), "網路上下載的圖塊大多是這種接法，排法每套不一樣，照「這格長什麼樣子」對照上面點。", font=font(15), fill=DIM)
    return img


if __name__ == "__main__":
    sides_image().save("art/terrain_rules_sides.png")
    corners_image().save("art/terrain_rules_corners.png")
    print("ok")
