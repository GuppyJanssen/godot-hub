extends Camera2D
class_name GameCamera
## GameCamera – de camera tijdens een run (zoomtest).
##
## Wat hij doet:
## - Volgt de speler en kijkt vooruit in de RICHTING van de muis/crosshair. Hoe ver de muis van het
##   schip staat, maakt niets uit (geen zeeziek-effect): de camera schuift altijd even ver op.
## - Komt nooit buiten de kamer (limit_* = de kamerranden). In een hoek staat het beeld stil.
## - Draait rustig bij (afgevlakt) en reageert niet als de muis vlak bij het schip staat (dode zone).
##
## SSOT, rij world (leeg = de standaard hieronder):
##   camera_zoom       1 = ware grootte, 2 = twee keer ingezoomd (je ziet een kwart).
##   camera_lookahead  hoe ver de camera vooruitkijkt, als deel van het halve beeld (0.6 = 60%).
##                     Het schip staat dan nooit dichter dan 40% van het halve beeld bij de rand.
##   camera_smoothing  hoe snel de camera bijdraait (hoger = sneller).
##   camera_deadzone   pixels rond het schip waarin de muis de kijkrichting niet verandert.
##   (camera_smoothing is nu: hoe snel de kijkrichting hooguit draait, in radialen per seconde.)
##   camera_turn_acceleration  hoe snel die draaisnelheid op gang komt en afremt (radialen per s²).
##
## Ontwikkelaarsnotities:
## - top_level: de camera draait niet mee met het schip; hij zet zijn eigen positie.
## - Werkt samen met RoomBounds.size() (world_room_width/height), zodat de kamer groter kan.

const SETTINGS_ROW := "world"
const DEFAULTS := {
	"camera_zoom": 1.0,
	"camera_lookahead": 0.6,
	"camera_smoothing": 6.0,
	"camera_deadzone": 40.0,
	"camera_turn_acceleration": 2.0,
}
## Het schip blijft altijd minstens dit deel van het halve beeld van de rand af.
const MAX_LOOKAHEAD := 0.85

var _look_dir: Vector2 = Vector2.ZERO
# Hoek waarin de camera nu vooruitkijkt. Draait traag mee met het vizier, "door een dikke vloeistof",
# en altijd langs de cirkel: als het vizier naar het schip toe of eroverheen beweegt, schuift de camera
# niet terug door het midden maar blijft hij vooruitkijken (Daan, 26 nov).
var _look_angle: float = 0.0
var _look_speed: float = 0.0   # radialen per seconde, nu
var _has_look: bool = false
var _offset_now: Vector2 = Vector2.ZERO


func _ready() -> void:
	top_level = true
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	apply_settings()
	make_current()
	_snap_to_target()


## Leest zoom en kamergrenzen opnieuw (bijvoorbeeld na een wissel in het F1-menu).
func apply_settings() -> void:
	var z: float = current_zoom()
	zoom = Vector2(z, z)
	var room: Vector2 = RoomBounds.size()
	limit_left = 0
	limit_top = 0
	limit_right = int(room.x)
	limit_bottom = int(room.y)


func _physics_process(delta: float) -> void:
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return
	# Kijkrichting: alleen de richting van het vizier, niet de afstand.
	var to_mouse: Vector2 = player.get_global_mouse_position() - player.global_position
	if "crosshair" in player and is_instance_valid(player.crosshair):
		# De echte mik-richting (muis/stick), niet het lock-on-doel: vastzetten trekt de camera niet weg.
		to_mouse = player.crosshair.wish_offset()
	# Kijkrichting draait METEEN mee (geen vertraging), maar met een maximale draaisnelheid
	# (camera_smoothing, radialen per seconde). Snel heen en weer met de muis geeft zo alleen een
	# lichte beweging, en de camera loopt niet na als de muis stilstaat.
	if to_mouse.length() > _setting("camera_deadzone"):
		if not _has_look:
			_look_angle = to_mouse.angle()
			_has_look = true
		if _setting("camera_smoothing") <= 0.0:
			# Test (Daan, 26 nov): de camera draait even snel als het schip (base_rotation_speed) naar
			# waar je echt mikt. Zonder lock-on is dat precies de neus van het schip; met lock-on draait
			# het schip naar het doel, maar de camera blijft bij je mik-richting.
			var speed: float = player.call("turn_speed") if player.has_method("turn_speed") else 10.0
			_look_angle = rotate_toward(_look_angle, to_mouse.angle(), speed * delta)
		else:
			_turn_look(to_mouse.angle(), delta)
	if _has_look:
		_look_dir = Vector2.from_angle(_look_angle)
	_offset_now = _target_offset()
	# Het schip wordt zonder vertraging gevolgd; alleen de kijkrichting draait begrensd mee.
	global_position = player.global_position + _offset_now


## Hoe ver de camera vooruitkijkt, per as: een deel van het halve beeld (rekening houdend met de zoom).
func _target_offset() -> Vector2:
	var half_view: Vector2 = get_viewport_rect().size / zoom / 2.0
	var amount: float = clampf(_setting("camera_lookahead"), 0.0, MAX_LOOKAHEAD)
	return Vector2(_look_dir.x * half_view.x, _look_dir.y * half_view.y) * amount


## Draait de kijkrichting naar 'wanted' met een begrensde snelheid (camera_smoothing) EN een begrensde
## versnelling (camera_turn_acceleration): het beeld komt rustig op gang en remt op tijd af. Snel
## heen en weer met de muis bouwt zo bijna geen snelheid op, dus het beeld beweegt maar een beetje.
func _turn_look(wanted: float, delta: float) -> void:
	var max_speed: float = maxf(0.0, _setting("camera_smoothing"))
	var accel: float = maxf(0.01, _setting("camera_turn_acceleration"))
	var diff: float = wrapf(wanted - _look_angle, -PI, PI)
	# Zo hard als kan, maar langzaam genoeg om op tijd te stoppen (remweg v²/2a).
	var desired: float = signf(diff) * minf(max_speed, sqrt(2.0 * accel * absf(diff)))
	_look_speed = move_toward(_look_speed, desired, accel * delta)
	_look_angle = wrapf(_look_angle + _look_speed * delta, -PI, PI)


func _snap_to_target() -> void:
	snap()


## Zet de camera meteen op het schip, zonder afvlakken (na een kamerwissel of teleport), zodat de
## achtergrond niet "verschiet" doordat de camera vanaf het midden van de kamer komt aanglijden.
func snap() -> void:
	var player: Node2D = get_parent() as Node2D
	_offset_now = _target_offset()
	if is_instance_valid(player):
		global_position = player.global_position + _offset_now
	reset_smoothing()


## De zoom van de camera (camera_zoom uit de SSOT).
## F1 "Zoomtest": zo ver uitgezoomd dat de hele kamer in beeld is. De kamer en alles erin blijven
## even groot; alleen de camera kijkt van verder weg.
static func current_zoom() -> float:
	var normal: float = clampf(_setting("camera_zoom"), 0.05, 4.0)
	if not Game.debug_zoom_overview:
		return clampf(normal, 0.25, 4.0)
	var view: Vector2 = Vector2(1920.0, 1080.0)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		view = tree.root.get_visible_rect().size
	var room: Vector2 = RoomBounds.size()
	return minf(normal, minf(view.x / room.x, view.y / room.y))


## Tekst en lijnen in de wereld (naambordjes, vizier) blijven even groot op het scherm,
## hoe ver de camera ook is uitgezoomd: vermenigvuldig hun maat hiermee.
static func ui_scale() -> float:
	return 1.0 / current_zoom()


## Een Label in de wereld leesbaar houden bij elke zoom: schalen rond zijn midden.
static func fit_world_label(label: Label) -> void:
	if label == null:
		return
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * ui_scale()


static func _setting(setting_name: String) -> float:
	return Ssot.get_number(SETTINGS_ROW, setting_name, float(DEFAULTS[setting_name]))
