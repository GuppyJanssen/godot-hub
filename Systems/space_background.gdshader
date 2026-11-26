shader_type canvas_item;
// SpaceBackground – placeholder-achtergrond voor gewone kamers, in pixelstijl.
// Drie lagen met parallax (ver → dichtbij):
//   1. Diepe ruimte: nevels in twee kleuren en hier en daar een klein sterrenstelsel (galaxy).
//   2. Sterren: veel zwakke, een paar wat fellere. Bewust rustig (Daan, 26 nov: sterren waren te
//      aanwezig, de verte was te leeg).
//   3. Dichtbij: vage stofslierten die met de wereld meebewegen, zodat je voelt dat je vliegt.
//      Geen felle puntjes meer (die leken op sterren en lagen bovenop alles).
// Alles wordt berekend (geen textures), op een grof raster van pixel_size wereld-pixels,
// met 4×4-dithering tussen de kleurtreden, zodat het blokkerig oogt zoals pixel art.
// Ontwikkelaarsnotities:
// - De ColorRect ligt in wereld-coördinaten (0,0 tot de kamergrootte); camera_center komt elk
//   frame uit SpaceBackground.gd. Kosten: alleen de zichtbare pixels, een handvol ruisberekeningen
//   (nevel 2× fbm van 4 octaven, stof 1× fbm van 3, sterrenstelsels alleen in hun eigen vakje).
// - Integer-hash (geen sin()), zodat het patroon op elke GPU gelijk is en geen raster vormt.

uniform vec2 camera_center = vec2(0.0);
uniform float pixel_size = 8.0;           // wereld-pixels per "art-pixel"
uniform vec3 layer_speed = vec3(0.1, 0.3, 1.0);     // 1 = beweegt mee met de wereld
uniform vec3 layer_brightness = vec3(0.6, 0.45, 0.2); // diepe ruimte / sterren / stof
uniform float dim = 0.3;                  // 0 = niets dempen, 1 = zwart
uniform float star_density = 0.003;       // kans per art-pixel op een ster
uniform float galaxy_density = 0.25;      // kans per vak van GALAXY_CELL art-pixels op een sterrenstelsel
uniform vec3 tint : source_color = vec3(0.23, 0.2, 0.33);
uniform vec3 base_color : source_color = vec3(0.02, 0.02, 0.035);
uniform vec2 seed_offset = vec2(0.0);     // per kamer anders (seed)

const float GALAXY_CELL = 64.0;           // art-pixels per vak waarin hooguit één sterrenstelsel staat

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

// Een waarde 0..1 in 'steps' treden, met dithering ertussen (pixel-art-look).
float quantize(float v, float steps, vec2 cell) {
	return floor(clamp(v * steps + bayer(cell) - 0.5, 0.0, steps)) / steps;
}

// Klein sterrenstelsel in het vak van 'cell' (of 0): spiraal of ellips, felle kern.
vec3 galaxy(vec2 cell) {
	vec2 box = floor(cell / GALAXY_CELL);
	if (hash(box + vec2(71.0, 3.0)) >= galaxy_density) {
		return vec3(0.0);
	}
	float radius = mix(8.0, 18.0, hash(box + vec2(5.0, 88.0)));
	// Midden in het vak, ver genoeg van de rand dat hij niet wordt afgesneden.
	vec2 center = (box + 0.5) * GALAXY_CELL
			+ (vec2(hash(box + vec2(1.0, 2.0)), hash(box + vec2(3.0, 4.0))) - 0.5) * (GALAXY_CELL - 2.6 * radius);
	vec2 q = cell + 0.5 - center;
	float angle = hash(box + vec2(9.0, 9.0)) * 6.2832;
	q = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * q;
	q.y /= mix(0.35, 0.9, hash(box + vec2(13.0, 7.0)));   // schuin gezien: platter
	float d = length(q) / radius;
	if (d > 1.6) {
		return vec3(0.0);
	}
	float spiral = hash(box + vec2(21.0, 6.0)) < 0.65 ? 1.0 : 0.0;  // anders een ellips
	float arms = 0.5 + 0.5 * cos(2.0 * atan(q.y, q.x) - 5.0 * log(max(d, 0.05)));
	float glow = exp(-d * 3.2) * (1.0 - spiral * 0.5 + spiral * 0.9 * arms * smoothstep(0.1, 0.45, d));
	glow += exp(-d * 14.0) * 0.8;                                    // kern
	float level = quantize(glow * 1.6, 4.0, cell);
	vec3 core = vec3(1.0, 0.85, 0.65);
	vec3 disk = mix(vec3(0.55, 0.65, 1.0), tint * 2.5, 0.35);
	return mix(disk, core, clamp(1.0 - d * 2.5, 0.0, 1.0)) * level;
}

void fragment() {
	vec3 col = base_color;

	// 1. Diepe ruimte: nevels in twee kleuren (de tint van de ring en een verschoven tint),
	//    met wat vervorming zodat het slierten worden in plaats van vlekken. Plus sterrenstelsels.
	vec2 c1 = layer_cell(layer_speed.x);
	vec2 warp = vec2(fbm(c1 * 0.012 + vec2(3.1, 7.7), 3), fbm(c1 * 0.012 + vec2(9.4, 1.3), 3));
	float neb_a = fbm(c1 * 0.018 + warp * 2.5, 4);
	float neb_b = fbm(c1 * 0.025 - warp * 2.0 + vec2(40.0, 11.0), 4);
	vec3 color_a = tint * 1.8;
	vec3 color_b = mix(tint.zxy * 1.6, vec3(0.45, 0.25, 0.5), 0.35);
	col += color_a * quantize(smoothstep(0.42, 0.78, neb_a), 4.0, c1) * layer_brightness.x;
	col += color_b * quantize(smoothstep(0.5, 0.82, neb_b), 3.0, c1) * layer_brightness.x * 0.8;
	// Heel zwakke sterrenstof in de verte, vooral waar de nevel is.
	if (hash(c1 + vec2(400.0, 17.0)) < star_density * 2.0) {
		col += vec3(0.6, 0.65, 0.8) * (0.15 + 0.35 * neb_a) * layer_brightness.x;
	}
	col += galaxy(c1) * layer_brightness.x;

	// 2. Sterren: de meeste zwak, een enkele feller. Licht gekleurd (blauwig of warm), niet puur wit.
	vec2 c2 = layer_cell(layer_speed.y);
	if (hash(c2) < star_density) {
		float power = pow(hash(c2 + vec2(911.0, 37.0)), 3.0);       // meestal klein
		vec3 star_color = hash(c2 + vec2(5.0, 51.0)) < 0.5 ? vec3(0.75, 0.82, 1.0) : vec3(1.0, 0.9, 0.75);
		col += star_color * (0.25 + 0.75 * power) * layer_brightness.y;
	}

	// 3. Dichtbij: vage stofslierten in de tint, in 2 treden (beweegt mee met de wereld).
	vec2 c3 = layer_cell(layer_speed.z);
	float dust = fbm(c3 * vec2(0.03, 0.05), 3);
	col += (vec3(0.25) + tint) * quantize(smoothstep(0.55, 0.85, dust), 2.0, c3) * layer_brightness.z;

	COLOR = vec4(col * (1.0 - clamp(dim, 0.0, 1.0)), 1.0);
}
