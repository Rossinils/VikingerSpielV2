shader_type canvas_item;
render_mode unshaded;

// Fuer Kuestensilhouette und Moewen: blendet im Bayer-Raster aus (harte Pixel, kein Alpha-Verlauf)
// und faerbt zum Sturm hin in den Dunst um.

uniform float amount = 1.0;
uniform vec3 tint_col = vec3(0.12, 0.17, 0.18);
uniform float tint = 0.0;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = floor(lp + 0.002);
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float bm = (BAYER[y * 4 + x] + 0.5) / 16.0;
	c.rgb = mix(c.rgb, tint_col, tint);
	if (bm >= amount) {
		c.a = 0.0;
	}
	COLOR = c;
}
