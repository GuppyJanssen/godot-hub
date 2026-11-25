extends Node2D
class_name Crosshair
## Crosshair – het vizier tijdens een run.
##
## - Volgt de muis, maar komt nooit verder dan het bereik van het huidige wapen
##   (current_weapon_stats["weapon_range"] van de speler, met de F1-bereikinstelling).
##   Ligt de muis verder weg, dan staat het vizier op het bereik, in de mikrichting.
## - Een dun lijntje van het schip naar het vizier laat de mikrichting zien.
## - De muis zelf is onzichtbaar tijdens het spelen, en gewoon zichtbaar zodra het spel op pauze
##   staat of het F1-menu open is. Bij het verlaten van de kamer wordt de muis weer zichtbaar.
##
## Ontwikkelaarsnotities:
## - top_level en process_mode ALWAYS: het vizier draait niet mee met het schip, en de muis wordt
##   ook tijdens de pauze goed gezet.
## - Alleen tekenen met _draw (geen sprite nodig). Kleuren en maten hieronder.

const COLOR := Color(1.0, 1.0, 1.0, 0.9)
const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.18)
const RING_RADIUS := 10.0
const TICK := 6.0
const WIDTH := 2.0

var _aim_point: Vector2 = Vector2.ZERO


func _ready() -> void:
	top_level = true
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_update_mouse_mode()
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return
	var from: Vector2 = player.global_position
	var to_mouse: Vector2 = get_global_mouse_position() - from
	var reach: float = _weapon_range(player)
	if to_mouse.length() > reach:
		to_mouse = to_mouse.normalized() * reach
	_aim_point = from + to_mouse
	global_position = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return
	draw_line(player.global_position, _aim_point, LINE_COLOR, 1.0)
	draw_arc(_aim_point, RING_RADIUS, 0.0, TAU, 24, COLOR, WIDTH)
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(_aim_point + dir * (RING_RADIUS + 2.0), _aim_point + dir * (RING_RADIUS + 2.0 + TICK), COLOR, WIDTH)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Muis verbergen tijdens het spelen, tonen bij pauze of met het F1-menu open.
func _update_mouse_mode() -> void:
	var menu_open: bool = get_tree().paused or (is_instance_valid(DebugOverlay) and DebugOverlay.visible)
	var wanted: int = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_HIDDEN
	if Input.mouse_mode != wanted:
		Input.mouse_mode = wanted


static func _weapon_range(player: Node) -> float:
	var reach: float = 300.0
	if "current_weapon_stats" in player and player.current_weapon_stats is Dictionary:
		reach = float(player.current_weapon_stats.get("weapon_range", reach))
	if Game.debug_range_multiplier > 0.0:
		reach *= Game.debug_range_multiplier
	return maxf(reach, 20.0)
