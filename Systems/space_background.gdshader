shader_type canvas_item;
// SpaceBackground – placeholder-achtergrond voor gewone kamers, in pixelstijl.
// Drie lagen met parallax (ver → dichtbij): sterren, nevel, ondergrond.
// Alles wordt berekend (geen textures), op een grof raster van pixel_size wereld-pixels,
// met 4×4-dithering tussen de kleurtreden, zodat het blokkerig oogt zoals pixel art.
// Ontwikkelaarsnotities:
// - De ColorRect ligt in wereld-coördinaten (0,0 tot de kamergrootte); camera_center komt elk
//   frame uit SpaceBackground.gd. Kosten: alleen de zichtbare pixels, een handvol ruisberekeningen.
// - Integer-hash (geen sin()), zodat het patroon op elke GPU gelijk is en geen raster vormt.

uniform vec2 camera_center = vec2(0.0);
uniform float pixel_size = 8.0;           // wereld-pixels per "art-pixel"
uniform vec3 layer_speed = vec3(0.15, 0.45, 1.0);   // 1 = beweegt mee met de wereld
uniform vec3 layer_brightness = vec3(0.8, 0.3, 0.35);
uniform float dim = 0.3;                  // 0 = niets dempen, 1 = zwart
uniform float star_density = 0.004;       // kans per art-pixel op een ster
uniform vec3 tint : source_color = vec3(0.23, 0.2, 0.33);
uniform vec3 base_color : source_color = vec3(0.03, 0.03, 0.05);
uniform vec2 seed_offset = vec2(0.0);     // per kamer anders (seed)

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 cell) {
	uint x = uint(int(cell.x));
	uint y = uint(int(cell.y));
	uint h = (x * 1597334677u) ^ (y * 3812015801u);
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = h ^ (h >> 13u);
	h = h * 3266489917u;
	h = h ^ (h >> 16u);
	return float(h) / 4294967295.0;
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float total = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int i = 0; i < octaves; i++) {
		total += value_noise(p + vec2(float(i) * 17.0, float(i) * 31.0)) * amp;
		norm += amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return total / norm;
}

// Art-pixel (geheel getal) van een laag met parallax.
vec2 layer_cell(float speed) {
	vec2 p = world_pos - camera_center * (1.0 - speed) + seed_offset;
	return floor(p / pixel_size);
}

// 4×4 Bayer-dithering.
float bayer(vec2 cell) {
	int idx = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[idx] / 16.0;
}

void fragment() {
	vec3 col = base_color;

	// 1. Sterren (ver weg): losse art-pixels, de ene wat feller dan de andere.
	vec2 c1 = layer_cell(layer_speed.x);
	if (hash(c1) < star_density) {
		col += vec3(0.5 + 0.5 * hash(c1 + vec2(911.0, 37.0))) * layer_brightness.x;
	}

	// 2. Nevel: grote, zachte vlekken in de tint, in 3 treden.
	vec2 c2 = layer_cell(layer_speed.y);
	float nebula = fbm(c2 * 0.02, 4);
	float nebula_step = floor(clamp((nebula - 0.45) * 8.0 + bayer(c2), 0.0, 3.0)) / 3.0;
	col += tint * nebula_step * layer_brightness.y;

	// 3. Ondergrond (beweegt mee met de wereld): grof gesteente in 4 tonen, met wat steentjes.
	vec2 c3 = layer_cell(layer_speed.z);
	float ground = fbm(c3 * 0.045, 5);
	float tone = floor(clamp((ground - 0.3) * 7.0 + bayer(c3) * 0.9, 0.0, 3.0)) / 3.0;
	float pebble = step(0.985, hash(c3 + vec2(5.0, 9.0)));
	float g = tone * 0.8 + pebble * 0.5;
	col += g * (vec3(0.35) + tint * 1.3) * layer_brightness.z;

	COLOR = vec4(col * (1.0 - clamp(dim, 0.0, 1.0)), 1.0);
}
