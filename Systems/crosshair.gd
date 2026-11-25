extends Node2D
class_name Crosshair
## Crosshair – het vizier tijdens een run.
##
## Hoe het werkt:
## - Het vizier hangt op een vaste plek TEN OPZICHTE VAN HET SCHIP (aim_offset). Alleen als je de muis
##   beweegt, verschuift het. Vlieg je zonder de muis te bewegen, dan blijft je mikrichting en
##   -afstand precies gelijk; het vizier vliegt gewoon met je mee.
## - DRAAISNELHEID: de muis bepaalt waar je HEEN WIL mikken (aim_offset, een vaag stipje). Het vizier
##   zelf staat altijd in de richting waarin het schip wijst, op dezelfde afstand. Het schip draait
##   met base_rotation_speed naar het stipje, dus het vizier draait even snel mee. Zo voel je de
##   draaisnelheid, en het vizier wijst altijd eerlijk aan waar je kogels heen gaan.
## - Het vizier komt nooit verder dan het bereik van het huidige wapen
##   (current_weapon_stats["weapon_range"], met de F1-bereikinstelling). Beweeg je de muis verder,
##   dan blijft het vizier op het bereik; terugbewegen werkt meteen.
## - Tijdens het spelen is de muis "gevangen" (MOUSE_MODE_CAPTURED): onzichtbaar, en hij kan niet
##   uit het venster of tegen de schermrand lopen. In pauze, menu's en het F1-menu is hij gewoon vrij.
##
## SSOT, rij world: aim_sensitivity (leeg = 1): hoe ver het vizier beweegt per beweging van de muis.
##
## Ontwikkelaarsnotities:
## - Vroeger volgde het vizier de echte muis op het scherm. Omdat de camera meebeweegt (en bij de
##   kamerrand stilstaat), schoof de wereld onder een stilstaande muis door en werd het vizier
##   "meegesleept". Nu telt alleen de beweging van de muis (InputEventMouseMotion.relative).
## - Player (draaien) en GameCamera (vooruitkijken) lezen aim_point() in plaats van de muispositie.
## - top_level en process_mode ALWAYS: het vizier draait niet mee met het schip, en de muismodus
##   wordt ook tijdens de pauze goed gezet.

const COLOR := Color(1.0, 1.0, 1.0, 0.9)
const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.18)
const RING_RADIUS := 10.0
const TICK := 6.0
const WIDTH := 2.0
## Beginafstand van het vizier voor het schip, als deel van het bereik.
const START_FRACTION := 0.5
## Het stipje waar je heen wil mikken (alleen zichtbaar als het schip nog moet draaien).
const TARGET_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const TARGET_RADIUS := 3.0
## Vanaf deze afstand (wereld-pixels, voor zoom) tussen vizier en stipje is het stipje te zien.
const TARGET_SHOW_DISTANCE := 6.0

## Plek van het vizier ten opzichte van het schip (wereld-pixels).
var aim_offset: Vector2 = Vector2.ZERO
var _initialized: bool = false


func _ready() -> void:
	top_level = true
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


## Waar het vizier nu staat (in de richting van het schip), in wereld-coördinaten.
func aim_point() -> Vector2:
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return global_position
	return player.global_position + shown_offset()


## Het vizier ten opzichte van het schip: richting van het schip, afstand van de muis.
func shown_offset() -> Vector2:
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return aim_offset
	return Vector2.from_angle(player.global_rotation) * aim_offset.length()


## Waar je met de muis heen wil mikken; hier draait het schip naartoe.
func target_point() -> Vector2:
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return global_position
	return player.global_position + aim_offset


func _input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	# Schermbeweging omrekenen naar wereld-pixels (houdt rekening met de camerazoom).
	var world_delta: Vector2 = get_viewport().get_canvas_transform().affine_inverse().basis_xform(motion.relative)
	aim_offset += world_delta * _sensitivity()
	_clamp_to_range()


func _process(_delta: float) -> void:
	_update_mouse_mode()
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return
	if not _initialized:
		_initialized = true
		aim_offset = Vector2.RIGHT.rotated(player.global_rotation) * _weapon_range(player) * START_FRACTION
	# Ander wapen met een korter bereik: het vizier schuift mee naar binnen.
	_clamp_to_range()
	global_position = Vector2.ZERO
	queue_redraw()


func _clamp_to_range() -> void:
	var player: Node = get_parent()
	if not is_instance_valid(player):
		return
	var reach: float = _weapon_range(player)
	if aim_offset.length() > reach:
		aim_offset = aim_offset.normalized() * reach


func _draw() -> void:
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return
	var point: Vector2 = aim_point()
	# Even groot op het scherm, hoe ver de camera ook is uitgezoomd.
	var k: float = GameCamera.ui_scale()
	draw_line(player.global_position, point, LINE_COLOR, 1.0 * k)
	draw_arc(point, RING_RADIUS * k, 0.0, TAU, 24, COLOR, WIDTH * k)
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(point + dir * (RING_RADIUS + 2.0) * k, point + dir * (RING_RADIUS + 2.0 + TICK) * k, COLOR, WIDTH * k)
	var target: Vector2 = target_point()
	if target.distance_to(point) > TARGET_SHOW_DISTANCE * k:
		draw_circle(target, TARGET_RADIUS * k, TARGET_COLOR)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Muis gevangen tijdens het spelen, vrij bij pauze of met het F1-menu open.
func _update_mouse_mode() -> void:
	var menu_open: bool = get_tree().paused or (is_instance_valid(DebugOverlay) and DebugOverlay.visible)
	var wanted: Input.MouseMode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != wanted:
		Input.mouse_mode = wanted


static func _sensitivity() -> float:
	return clampf(Ssot.get_number("world", "aim_sensitivity", 1.0), 0.1, 5.0)


static func _weapon_range(player: Node) -> float:
	var reach: float = 300.0
	if "current_weapon_stats" in player and player.current_weapon_stats is Dictionary:
		reach = float(player.current_weapon_stats.get("weapon_range", reach))
	if Game.debug_range_multiplier > 0.0:
		reach *= Game.debug_range_multiplier
	return maxf(reach, 20.0)
