shader_type canvas_item;
render_mode unshaded;

// Wasser in harten Pixeln: die Oberkante kommt aus einer 480x1-Textur (Waves.height, ganze Pixel),
// darunter Tiefenstufen als Bayer-Dithering, Wellenlinien, Schaum und Glitzern. Drei Schichten
// (tone 0 = fern/dunstig, 1 = mittel, 2 = vorn/dunkel) mit eigener Palette.

uniform sampler2D surf : filter_nearest, repeat_disable;
uniform int tone = 1;
uniform float storm = 0.3;
uniform float flash = 0.0;
uniform float time = 0.0;
uniform vec2 sun_pos = vec2(300.0, 86.0);

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

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hx(float r, float g, float b) {
	return vec3(r, g, b) / 255.0;
}

float S(int x) {
	return texelFetch(surf, ivec2(clamp(x, 0, 479), 0), 0).r;
}

void fragment() {
	vec2 p = floor(lp + 0.002);
	int xi = int(p.x);
	float s = S(xi);
	float sl = S(xi - 1);
	float sr = S(xi + 1);
	float d = p.y - s;
	float st = storm;
	bool crest = s <= sl && s <= sr && (s < sl || s < sr);
	bool steep = abs(s - sl) >= 2.0 || abs(sr - s) >= 2.0;
	vec3 foam = mix(hx(196.0, 210.0, 216.0), hx(214.0, 222.0, 220.0), st);

	if (d < 0.0) {
		// Schaumkrone ragt ueber die Kante hinaus (ab maessigem Seegang)
		float up = crest ? 1.0 : 0.0;
		if (st > 0.22 && d >= -up && hash(vec2(p.x, 3.0)) < 0.22 + st * 0.5) {
			COLOR = vec4(foam, 1.0);
		} else {
			discard;
		}
	} else {
		float bm = bayer4(p);
		// --- Paletten (5 Stufen, ruhig -> Sturm)
		vec3 pc[5];
		vec3 rim;
		if (tone == 0) {
			pc[0] = mix(hx(118.0, 138.0, 150.0), hx(52.0, 70.0, 78.0), st);
			pc[1] = mix(hx(96.0, 117.0, 131.0), hx(42.0, 58.0, 66.0), st);
			pc[2] = mix(hx(78.0, 98.0, 113.0), hx(34.0, 47.0, 55.0), st);
			pc[3] = mix(hx(63.0, 82.0, 98.0), hx(27.0, 38.0, 46.0), st);
			pc[4] = mix(hx(52.0, 69.0, 85.0), hx(21.0, 30.0, 37.0), st);
			rim = mix(hx(168.0, 184.0, 192.0), hx(104.0, 126.0, 134.0), st);
		} else if (tone == 1) {
			pc[0] = mix(hx(70.0, 94.0, 108.0), hx(30.0, 46.0, 56.0), st);
			pc[1] = mix(hx(58.0, 80.0, 94.0), hx(24.0, 37.0, 46.0), st);
			pc[2] = mix(hx(47.0, 67.0, 80.0), hx(19.0, 30.0, 38.0), st);
			pc[3] = mix(hx(38.0, 55.0, 67.0), hx(15.0, 24.0, 31.0), st);
			pc[4] = mix(hx(30.0, 45.0, 56.0), hx(11.0, 18.0, 24.0), st);
			rim = mix(hx(132.0, 156.0, 168.0), hx(88.0, 110.0, 120.0), st);
		} else {
			pc[0] = mix(hx(36.0, 66.0, 80.0), hx(18.0, 32.0, 42.0), st);
			pc[1] = mix(hx(28.0, 54.0, 67.0), hx(14.0, 25.0, 33.0), st);
			pc[2] = mix(hx(22.0, 44.0, 56.0), hx(11.0, 20.0, 27.0), st);
			pc[3] = mix(hx(17.0, 35.0, 46.0), hx(8.0, 15.0, 21.0), st);
			pc[4] = mix(hx(12.0, 26.0, 36.0), hx(6.0, 11.0, 16.0), st);
			rim = mix(hx(100.0, 130.0, 146.0), hx(72.0, 98.0, 110.0), st);
		}

		// --- Tiefe: geordnetes Dithering zwischen den Stufen
		float H = tone == 0 ? 14.0 : (tone == 1 ? 26.0 : 44.0);
		float tabs = clamp((p.y - 150.0) / 190.0, 0.0, 1.0);
		float t = clamp(pow(clamp(d / H, 0.0, 1.0), 0.8) * 0.62 + tabs * 0.38, 0.0, 1.0);
		float fs = t * 4.0;
		int i0 = int(min(floor(fs), 3.0));
		float f = clamp((fs - float(i0) - 0.2) / 0.6, 0.0, 1.0);
		int idx = i0 + ((f > bm) ? 1 : 0);
		vec3 col = pc[idx];

		// --- Wellenlinien: folgen der Oberflaeche, ziehen langsam mit
		float period = tone == 0 ? 6.0 : (tone == 1 ? 9.0 : 12.0);
		float v = d + floor(2.0 * sin(p.x * 0.05 + time * 0.3 + float(tone) * 1.9) + 0.5);
		float vm = mod(v, period);
		float bandid = floor(v / period) + float(tone) * 11.0;
		float hb = hash(vec2(floor((p.x + time * (1.5 + st * 4.0)) / 3.0), bandid));
		if (d > 2.0) {
			if (vm < 1.0 && hb > 0.4) {
				col = pc[max(idx - 1, 0)];
			} else if (vm >= 1.0 && vm < 2.0 && hb > 0.62) {
				col = pc[min(idx + 1, 4)];
			}
		}

		// --- Oberkante: Lichtkante und gedithertes Band darunter
		if (d < 0.5) {
			col = rim;
		} else if (d < 1.5) {
			col = ((int(p.x) + int(p.y)) % 2 == 0) ? rim : pc[max(idx - 1, 0)];
		} else if (d < 2.5 && bm < 0.4) {
			col = pc[max(idx - 1, 0)];
		}

		// --- Schaum: Kamm, steile Flanken, treibende Streifen
		if (st > 0.22) {
			float fl = crest ? 2.0 : (steep ? 0.0 : -1.0);
			if (d <= fl && hash(vec2(p.x, floor(p.y * 0.5))) < 0.25 + st * 0.5) {
				col = (d > 1.5) ? foam * 0.86 : foam;
			}
		}
		float sp = 3.0 + st * 10.0;
		float sx = floor(p.x - time * sp);
		float lenc = 4.0 + floor(st * 4.0);
		float hs = hash(vec2(floor(sx / lenc), floor(p.y * 0.5) + float(tone) * 5.0));
		if (d >= 1.5 && d <= 3.0 + st * 14.0 && hs > 0.975 - st * 0.06 && mod(sx, lenc) < lenc - 1.0) {
			col = foam * (0.55 + 0.1 * float(tone == 0));
		}

		// --- Sonnenglitzern: nur bei ruhiger See, auf den Wellenlinien, Saeule unter der Sonne
		float sv = clamp(1.0 - st * 1.5, 0.0, 1.0);
		if (sv > 0.0 && d >= 1.0) {
			float dx = abs(p.x - sun_pos.x);
			float width = 4.0 + (p.y - 150.0) * 0.22;
			if (dx < width && p.y < 232.0) {
				float k = 1.0 - dx / width;
				float tw = floor(time * 0.6 + hash(p) * 3.0);
				float hg = hash(p + vec2(tw * 7.0, tw * 3.0));
				bool lit = (vm < 3.0) || tone == 0;
				if (lit && hg > 0.95 - 0.24 * k * sv) {
					col = hx(214.0, 208.0, 178.0);
				} else if (lit && hg > 0.89 - 0.2 * k * sv) {
					col = hx(150.0, 160.0, 150.0);
				}
			}
		}

		// --- Blitz: Wasser hellt kurz auf, ohne zu blenden
		col += hx(46.0, 58.0, 78.0) * flash * (1.0 - t * 0.7) * 0.5;
		if (d < 0.5) {
			col += hx(60.0, 72.0, 90.0) * flash * 0.5;
		}
		COLOR = vec4(col, 1.0);
	}
}
