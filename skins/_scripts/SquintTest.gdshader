// 瞇眼測試：把整個畫面變糊（可以再變成黑白），看玩家、危險物、目標是不是一眼分得出來
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
// 模糊的距離（畫面像素）
uniform float blur = 2.0;
// 要不要順便變成黑白（只看明暗，不看顏色）
uniform bool gray = false;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur;
	vec3 sum = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			sum += texture(screen, SCREEN_UV + vec2(float(x), float(y)) * px).rgb;
		}
	}
	vec3 color = sum / 9.0;
	if (gray) {
		color = vec3(dot(color, vec3(0.299, 0.587, 0.114)));
	}
	COLOR = vec4(color, 1.0);
}
