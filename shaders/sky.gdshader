shader_type canvas_item;
render_mode unshaded;

// Himmel in harten Pixeln: Verlauf als geordnetes Dithering (Bayer 4x4) zwischen sechs
// Farbstufen, zwei Wolkenschichten (Schwellen auf kachelbarem Rauschen, 3 Tonwerte), Sonne
// samt Dunsthof. Alle Muster liegen fest im 480x320-Raster (floor), nichts wird weichgezeichnet.

uniform float storm = 0.3;
uniform float flash = 0.0;
uniform float off_a = 0.0;   // Wolkenversatz in Pixeln (hohe Schicht)
uniform float off_b = 0.0;   // (niedrige Baenke)
uniform vec2 sun_pos = vec2(300.0, 86.0);
uniform float sun_vis = 1.0;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (BAYER[y * 4 + x] + 0.5) / 16.0;
}

vec3 hx(float r, float g, float b) {
	return vec3(r, g, b) / 255.0;
}

float dens_a(vec2 p) {
	float env = 1.0 - abs((p.y - mix(58.0, 70.0, storm)) / mix(46.0, 96.0, storm));
	vec2 uv = vec2((p.x + off_a) * 0.0042, p.y * 0.0125);
	float n = texture(noise_tex, uv).r * 0.86 + texture(noise_tex, uv * 2.7 + vec2(0.31, 0.57)).g * 0.14;
	return n + clamp(env, -0.4, 1.0) * 0.30;
}

float dens_b(vec2 p) {
	float env = 1.0 - abs((p.y - 140.0) / mix(24.0, 34.0, storm));
	vec2 uv = vec2((p.x + off_b) * 0.0030, p.y * 0.030 + 0.37);
	float n = texture(noise_tex, uv).b * 0.80 + texture(noise_tex, uv * 3.3 + vec2(0.7, 0.2)).g * 0.20;
	return n + clamp(env, -0.5, 1.0) * 0.34;
}

void fragment() {
	vec2 p = floor(lp + 0.002);
	float bm = bayer4(p);

	// --- Verlauf: 6 Stufen, schmale Dither-Uebergaenge zwischen ebenen Baendern
	vec3 cs[6];
	cs[0] = hx(34.0, 46.0, 60.0);
	cs[1] = hx(48.0, 63.0, 80.0);
	cs[2] = hx(72.0, 90.0, 106.0);
	cs[3] = hx(100.0, 116.0, 129.0);
	cs[4] = hx(134.0, 146.0, 156.0);
	cs[5] = hx(166.0, 172.0, 174.0);
	vec3 ss[6];
	ss[0] = hx(6.0, 8.0, 12.0);
	ss[1] = hx(10.0, 14.0, 19.0);
	ss[2] = hx(16.0, 23.0, 29.0);
	ss[3] = hx(23.0, 33.0, 38.0);
	ss[4] = hx(31.0, 45.0, 47.0);
	ss[5] = hx(44.0, 60.0, 58.0);

	float g = clamp((p.y + 16.0) / 184.0, 0.0, 1.0);
	g = pow(g, 1.3);
	float fs = g * 5.0;
	int i0 = int(min(floor(fs), 4.0));
	float f = clamp((fs - float(i0) - 0.25) / 0.5, 0.0, 1.0);
	int idx = i0 + ((f > bm) ? 1 : 0);
	vec3 col = mix(cs[idx], ss[idx], storm);

	// --- Sonne mit Dunsthof (nur bei ruhiger See; im Sturm verschluckt)
	float sv = clamp(1.0 - storm * 1.4, 0.0, 1.0);
	if (sv > 0.0) {
		float sd = length((p - sun_pos) * vec2(1.0, 1.25));
		vec3 warm = hx(201.0, 190.0, 150.0);
		if (sd < 9.0) {
			col = mix(col, hx(222.0, 217.0, 190.0), sv);
		} else if (sd < 12.0) {
			col = mix(col, warm, sv * (bm < 0.6 ? 0.55 : 0.0));
		} else if (sd < 20.0) {
			float h = (20.0 - sd) / 8.0;
			col = mix(col, warm, sv * (bm < h * 0.55 ? 0.28 : 0.0));
		}
	}

	// --- Blitz: Himmel hinter den Wolken wird hell, die Wolken bleiben dunkle Scherenschnitte
	vec3 flash_sky = hx(120.0, 138.0, 164.0);
	col = mix(col, flash_sky, flash * 0.55);
	float shade = 1.0 - flash * 0.5;

	// --- Wolkenschicht A (hoch, gross) und B (niedrige Baenke am Horizont)
	float thr_a = mix(0.72, 0.32, storm);
	float da = dens_a(p) + (bm - 0.5) * 0.03;
	if (da > thr_a) {
		float up = dens_a(p + vec2(0.0, -2.0)) + (bm - 0.5) * 0.03;
		float dn = dens_a(p + vec2(0.0, 2.0)) + (bm - 0.5) * 0.03;
		vec3 rim = mix(hx(176.0, 188.0, 198.0), hx(62.0, 78.0, 85.0), storm);
		vec3 mid = mix(hx(130.0, 144.0, 158.0), hx(38.0, 52.0, 58.0), storm);
		vec3 sh = mix(hx(100.0, 114.0, 128.0), hx(21.0, 30.0, 36.0), storm);
		vec3 c = mid;
		if (up <= thr_a) {
			c = rim;
		} else if (dn <= thr_a) {
			c = sh;
		} else if (da > thr_a + 0.10) {
			c = sh;
		}
		col = c * shade + (c == rim ? flash * 0.2 * hx(190.0, 205.0, 230.0) : vec3(0.0));
	}

	float thr_b = mix(0.70, 0.36, storm);
	float db = (p.y < 168.0) ? dens_b(p) + (bm - 0.5) * 0.03 : 0.0;  // unterhalb des Horizonts nicht berechnen
	if (db > thr_b && p.y < 168.0) {
		float up = dens_b(p + vec2(0.0, -2.0)) + (bm - 0.5) * 0.03;
		vec3 rim = mix(hx(150.0, 160.0, 168.0), hx(52.0, 68.0, 66.0), storm);
		vec3 mid = mix(hx(112.0, 124.0, 134.0), hx(31.0, 43.0, 44.0), storm);
		vec3 sh = mix(hx(88.0, 100.0, 112.0), hx(19.0, 28.0, 30.0), storm);
		vec3 c = mid;
		if (up <= thr_b) {
			c = rim;
		} else if (db > thr_b + 0.10) {
			c = sh;
		}
		col = c * shade + (c == rim ? flash * 0.12 * hx(190.0, 205.0, 230.0) : vec3(0.0));
	}

	COLOR = vec4(col, 1.0);
}
