class_name SpaceBackground
extends ColorRect
## SpaceBackground – placeholder-achtergrond voor de gewone kamers (niet de Zuid- en Noordpool,
## die hebben een eigen plaatje). Drie lagen in pixelstijl die met parallax meebewegen, zodat je
## het idee hebt dat je ergens overheen vliegt. Rustig gehouden: donker, weinig contrast,
## niets dat knippert, zodat vijanden, kogels en loot altijd goed zichtbaar blijven.
##
## Gebruik (game_room.gd): SpaceBackground.create(parent, ring, kamer, kamergrootte)
##
## SSOT, rij world (leeg = de standaard hieronder):
##   background_pixel_size        wereld-pixels per art-pixel (grover = blokkeriger)
##   background_layer_speeds      parallax per laag, ver/midden/dichtbij, bijv. 0.15/0.45/1
##   background_layer_brightness  helderheid per laag, bijv. 0.8/0.3/0.35
##   background_dim               algemene demping, 0 = niets, 1 = zwart
##   background_star_density      kans per art-pixel op een ster
##   background_ring_tints        kleur per ring als hex, van de Zuidpool tot de Noordpool,
##                                gescheiden door / (bijv. #5a4a8a/#3f6a8a/...)
##
## Ontwikkelaarsnotities:
## - Eén ColorRect met een shader over de hele kamer; de GPU rekent alleen zichtbare pixels.
##   Per frame wordt alleen de camerapositie doorgegeven (geen nodes per ster).
## - Per kamer een kleine variatie (iets andere tint, ander stuk van het patroon), vast via
##   ring en kamernummer, dus elke keer dat je terugkomt ziet de kamer er hetzelfde uit.

const SHADER_PATH := "res://Systems/space_background.gdshader"
const DEFAULT_TINTS := ["#3b3355", "#33405a", "#2f4a52", "#34503f", "#4d4a33", "#553a33",
	"#4d4a33", "#34503f", "#2f4a52", "#33405a", "#3b3355"]
## Hoeveel de tint per kamer mag verschuiven (kleurtoon, 0..1).
const HUE_VARIATION := 0.03

var _material: ShaderMaterial = null


static func create(parent: Node, ring: int, room: int, room_size: Vector2) -> SpaceBackground:
	var shader: Shader = load(SHADER_PATH) as Shader
	if shader == null or parent == null:
		push_warning("SpaceBackground: shader niet gevonden; geen achtergrond.")
		return null
	var bg := SpaceBackground.new()
	bg.name = "SpaceBackground"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = Vector2.ZERO
	bg.size = room_size
	bg.z_index = -100
	bg._material = ShaderMaterial.new()
	bg._material.shader = shader
	bg.material = bg._material
	bg._apply_settings(ring, room)
	parent.add_child(bg)
	parent.move_child(bg, 0)
	return bg


func _process(_delta: float) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null and _material != null:
		_material.set_shader_parameter("camera_center", camera.get_screen_center_position())


func _apply_settings(ring: int, room: int) -> void:
	var speeds: Vector3 = _vec3("background_layer_speeds", Vector3(0.15, 0.45, 1.0), 0.0, 1.0)
	var brightness: Vector3 = _vec3("background_layer_brightness", Vector3(0.8, 0.3, 0.35), 0.0, 2.0)
	_material.set_shader_parameter("pixel_size", clampf(Ssot.get_number("world", "background_pixel_size", 8.0), 1.0, 64.0))
	_material.set_shader_parameter("layer_speed", speeds)
	_material.set_shader_parameter("layer_brightness", brightness)
	_material.set_shader_parameter("dim", clampf(Ssot.get_number("world", "background_dim", 0.3), 0.0, 1.0))
	_material.set_shader_parameter("star_density", clampf(Ssot.get_number("world", "background_star_density", 0.004), 0.0, 0.05))
	# Vaste variatie per kamer.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bg_%d_%d" % [ring, room])
	var tint: Color = _ring_tint(ring)
	tint.h = fposmod(tint.h + rng.randf_range(-HUE_VARIATION, HUE_VARIATION), 1.0)
	_material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_material.set_shader_parameter("seed_offset", Vector2(rng.randf_range(0.0, 50000.0), rng.randf_range(0.0, 50000.0)))


static func _ring_tint(ring: int) -> Color:
	var text: String = Ssot.get_text("world", "background_ring_tints", "")
	var tints: Array = text.split("/", false) if text != "" else DEFAULT_TINTS
	if tints.is_empty():
		tints = DEFAULT_TINTS
	var pick: String = str(tints[clampi(ring, 0, tints.size() - 1)]).strip_edges()
	if not Color.html_is_valid(pick):
		push_warning("SpaceBackground: '%s' is geen geldige kleur in background_ring_tints." % pick)
		pick = str(DEFAULT_TINTS[clampi(ring, 0, DEFAULT_TINTS.size() - 1)])
	return Color.html(pick)


## Drie getallen gescheiden door / (bijv. "0.15/0.45/1"); ongeldig = de standaard.
static func _vec3(column: String, fallback: Vector3, low: float, high: float) -> Vector3:
	var parts: PackedStringArray = Ssot.get_text("world", column, "").split("/", false)
	if parts.size() != 3:
		return fallback
	var out := Vector3()
	for i in 3:
		var part: String = parts[i].strip_edges()
		if not part.is_valid_float():
			return fallback
		out[i] = clampf(part.to_float(), low, high)
	return out
