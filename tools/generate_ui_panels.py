# 產生 UI 風格的底框九宮格圖（ui/styles/Panel_*.png）：24×24 灰階，四邊各 8 像素不拉伸，遊戲中依配色上色。
# 灰階越亮，上色後越接近配色的 panel 顏色；255 就是 panel 顏色本身，0 是黑色。
# U211 加的四種：木牌、科幻、漫畫、復古遊戲機（像素復古、乾淨極簡、可愛圓角是 U191 畫的，不在這裡重畫）。
# U212：每種風格（漫畫除外，它本來就是黑框）再畫一張外框圖 Outline_*.png。
# 用法：在專案根目錄執行 python tools/generate_ui_panels.py（需要 Pillow）

from PIL import Image

SIZE = 24


# 建一張全透明的灰階圖
def blank():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


# 在 (x, y) 畫一個灰階像素
def put(im, x, y, gray, alpha=255):
    im.putpixel((x, y), (gray, gray, gray, alpha))


# 畫一個實心長方形（含兩端）
def rect(im, x0, y0, x1, y1, gray, alpha=255):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(im, x, y, gray, alpha)


# 木牌：木紋橫條（中間 8 格是 4 像素一循環，重複鋪也接得起來）、深色外框、四角釘子
def wood():
    im = blank()
    grain = [236, 236, 214, 228]
    for y in range(SIZE):
        rect(im, 0, y, SIZE - 1, y, grain[y % 4])
    for x in range(SIZE):
        put(im, x, 0, 96)
        put(im, x, SIZE - 1, 96)
    for y in range(SIZE):
        put(im, 0, y, 96)
        put(im, SIZE - 1, y, 96)
    for x in range(1, SIZE - 1):
        put(im, x, 1, 250)
        put(im, x, SIZE - 2, 150)
    for cx, cy in [(3, 3), (SIZE - 5, 3), (3, SIZE - 5), (SIZE - 5, SIZE - 5)]:
        rect(im, cx, cy, cx + 1, cy + 1, 120)
        put(im, cx, cy, 255)
    return im


# 科幻：四角切角、亮色細外框、角上多一小段亮線，裡面稍暗
def scifi():
    im = blank()
    cut = 5
    for y in range(SIZE):
        for x in range(SIZE):
            d = min(x, y, SIZE - 1 - x, SIZE - 1 - y)
            corner = min(x, SIZE - 1 - x) + min(y, SIZE - 1 - y)
            if corner < cut:
                continue
            edge = d == 0 or corner == cut
            put(im, x, y, 255 if edge else 190, 255 if edge else 235)
    for i in range(3):
        put(im, cut + 1 + i, 2, 255)
        put(im, SIZE - cut - 2 - i, SIZE - 3, 255)
    return im


# 漫畫：2 像素黑框，右邊、下面多 2 像素黑色硬陰影
def comic():
    im = blank()
    body = SIZE - 3
    rect(im, 2, 2, SIZE - 1, SIZE - 1, 0)
    rect(im, 0, 0, body, body, 0)
    rect(im, 2, 2, body - 2, body - 2, 255)
    return im


# 復古遊戲機：雙線外框（外一圈、隔一格、內一圈），方角
def retro():
    im = blank()
    rect(im, 0, 0, SIZE - 1, SIZE - 1, 255)
    for inset in (1, 3):
        for i in range(inset, SIZE - inset):
            put(im, i, inset, 70)
            put(im, i, SIZE - 1 - inset, 70)
            put(im, inset, i, 70)
            put(im, SIZE - 1 - inset, i, 70)
    return im


# 外框圖：底框形狀最外面一圈（不透明、而且旁邊是透明或圖的邊）畫成白色，其他透明；遊戲中依配色的 accent 上色疊在底框上
def outline_of(panel):
    im = blank()
    src = panel.convert("RGBA")
    for y in range(SIZE):
        for x in range(SIZE):
            if src.getpixel((x, y))[3] == 0:
                continue
            for nx, ny in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]:
                if not (0 <= nx < SIZE and 0 <= ny < SIZE) or src.getpixel((nx, ny))[3] == 0:
                    put(im, x, y, 255)
                    break
    return im


if __name__ == "__main__":
    for name, make in [("Wood", wood), ("SciFi", scifi), ("Comic", comic), ("Retro", retro)]:
        path = "ui/styles/Panel_%s.png" % name
        make().save(path)
        print("寫入", path)
    for name in ["Pixel", "Clean", "Cute", "Wood", "SciFi", "Retro"]:
        path = "ui/styles/Outline_%s.png" % name
        outline_of(Image.open("ui/styles/Panel_%s.png" % name)).save(path)
        print("寫入", path)
