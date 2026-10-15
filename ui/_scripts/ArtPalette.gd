extends RefCounted

# 從一張圖（標題畫面的主視覺）抓主色，配出一整套 UI 的顏色。UIRoot 的 palette 選「跟主視覺配」時用。
# 字跟底框一定一個很亮一個很暗，不管圖是什麼顏色字都看得清楚。

const TONE_AUTO := 0
const TONE_DARK := 1
const TONE_LIGHT := 2

# 色相分幾格來數「哪種顏色最多」
const _HUE_BUCKETS := 12
# 太灰、太暗的像素不算顏色（只算進整體亮度）；像素圖的深色外框通常很暗，不讓它變成主色
const _MIN_SATURATION := 0.2
const _MIN_VALUE := 0.3
# 比這個還灰就當成沒有顏色（黑白灰的圖），按鈕和亮色也用灰的
const _GRAY := 0.05
# 取樣時圖最多看幾格寬（大圖跳著看，不用每個像素都數）
const _SAMPLE_SIZE := 96
# 整張圖平均亮度超過這個，「自動」就配淺底
const _LIGHT_IMAGE := 0.6


# 讀出一張圖的像素：編輯器裡直接讀原始圖檔（不用跟顯示卡要），讀不到再跟材質要；都不行回傳 null
static func read_image(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var img: Image = null
	var path := tex.resource_path
	if path != "" and not path.contains("::") and FileAccess.file_exists(path):
		img = _load_from_bytes(path)
	if img == null:
		img = tex.get_image()
		if img != null:
			img = img.duplicate()
	if img == null or img.is_empty():
		return null
	if img.is_compressed() and img.decompress() != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


# 直接讀原始圖檔的內容（PNG、JPG、WebP），不認得的格式回傳 null
static func _load_from_bytes(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img := Image.new()
	var ext := path.get_extension().to_lower()
	var err := ERR_FILE_UNRECOGNIZED
	if ext == "png":
		err = img.load_png_from_buffer(bytes)
	elif ext == "jpg" or ext == "jpeg":
		err = img.load_jpg_from_buffer(bytes)
	elif ext == "webp":
		err = img.load_webp_from_buffer(bytes)
	return img if err == OK else null

# 圖裡最多的三種顏色（由多到少；顏色不夠三種就重複最後一種）和整張圖的平均亮度：
# { "colors": [Color, Color, Color], "luminance": float }；讀不到圖回傳空的
static func analyze(img: Image) -> Dictionary:
	if img == null:
		return {}
	var w := img.get_width()
	var h := img.get_height()
	var step := maxi(1, ceili(maxf(w, h) / float(_SAMPLE_SIZE)))
	var weights := []
	var sums := []
	for i in _HUE_BUCKETS:
		weights.append(0.0)
		sums.append(Color(0, 0, 0, 0))
	var total := 0
	var lum_sum := 0.0
	var gray_sum := Color(0, 0, 0, 0)
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			total += 1
			lum_sum += c.get_luminance()
			gray_sum += c
			if c.s < _MIN_SATURATION or c.v < _MIN_VALUE:
				continue
			var b := int(c.h * _HUE_BUCKETS) % _HUE_BUCKETS
			var weight := c.s * c.v
			weights[b] += weight
			sums[b] += c * weight
	if total == 0:
		return {}
	var colors: Array[Color] = []
	var taken := []
	for n in 3:
		var best := -1
		for b in _HUE_BUCKETS:
			if taken.has(b) or weights[b] <= 0.0:
				continue
			# 隔壁的色相跟已經選到的太像，不算新的一種顏色
			if taken.has((b + 1) % _HUE_BUCKETS) or taken.has((b + _HUE_BUCKETS - 1) % _HUE_BUCKETS):
				continue
			if best == -1 or weights[b] > weights[best]:
				best = b
		if best == -1:
			break
		taken.append(best)
		var s: Color = sums[best] / weights[best]
		colors.append(Color(s.r, s.g, s.b, 1.0))
	if colors.is_empty():
		var avg: Color = gray_sum / float(total)
		colors.append(Color(avg.r, avg.g, avg.b, 1.0))
	while colors.size() < 3:
		colors.append(colors[colors.size() - 1])
	return { "colors": colors, "luminance": lum_sum / float(total) }


# 配出 4 個顏色 [字, 底框, 按鈕, 亮色]：底框帶一點圖裡最多的顏色，按鈕和亮色用 pick 選的那個顏色；
# tone 自動時看圖的整體亮度決定深底還是淺底
static func make_colors(info: Dictionary, tone: int, pick: int) -> PackedColorArray:
	if info.is_empty():
		return PackedColorArray()
	var base: Color = info.colors[0]
	var main: Color = info.colors[clampi(pick, 0, 2)]
	var dark: bool = tone == TONE_DARK or (tone == TONE_AUTO and info.luminance < _LIGHT_IMAGE)
	var text: Color
	var panel: Color
	var button: Color
	var accent: Color
	if dark:
		text = Color.from_hsv(base.h, minf(base.s, 0.08), 0.96)
		panel = Color.from_hsv(base.h, minf(base.s, 0.5), 0.15, 0.9)
		button = Color.from_hsv(main.h, _vivid(main.s, 0.35, 0.6), 0.36)
		accent = Color.from_hsv(main.h, _vivid(main.s, 0.55, 1.0), maxf(main.v, 0.85))
	else:
		text = Color.from_hsv(base.h, minf(base.s, 0.35), 0.16)
		panel = Color.from_hsv(base.h, minf(base.s, 0.12), 0.96, 0.9)
		button = Color.from_hsv(main.h, _vivid(main.s, 0.3, 0.45), 0.86)
		accent = Color.from_hsv(main.h, _vivid(main.s, 0.6, 1.0), 0.6)
	return PackedColorArray([text, panel, button, accent])

# 按鈕、亮色的鮮豔度：圖本來就淡的也拉到 low 以上（看得出是什麼顏色），最多 high；黑白灰的圖維持灰的
static func _vivid(saturation: float, low: float, high: float) -> float:
	if saturation < _GRAY:
		return 0.0
	return clampf(saturation, low, high)
