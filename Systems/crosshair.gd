extends Node2D
class_name Crosshair
## Crosshair – het vizier tijdens een run.
##
## Hoe het werkt:
## - Het vizier hangt op een vaste plek TEN OPZICHTE VAN HET SCHIP (aim_offset). Alleen als je de muis
##   of de rechter stick beweegt, verschuift het. Vlieg je zonder te richten, dan blijft je
##   mikrichting en -afstand precies gelijk; het vizier vliegt gewoon met je mee.
## - DRAAISNELHEID: de muis of stick bepaalt waar je HEEN WIL mikken (aim_offset, een vaag stipje).
##   Het vizier zelf staat altijd in de richting waarin het schip wijst, op dezelfde afstand. Het
##   schip draait met base_rotation_speed naar het stipje, dus het vizier draait even snel mee.
## - CONTROLLER en TOUCH (zie InputDevice): de rechter stick geeft alleen de richting; de afstand is
##   aim_stick_distance × het bereik. Laat je de stick los, dan blijft het vizier staan.
## - Het vizier komt nooit verder dan het bereik van het huidige wapen
##   (current_weapon_stats["weapon_range"], met de F1-bereikinstelling).
## - Muis: tijdens het spelen "gevangen" (MOUSE_MODE_CAPTURED). Met de controller verborgen maar vrij
##   (MOUSE_MODE_HIDDEN), zodat een muisbeweging meteen terugschakelt. In pauze, menu's en het
##   F1-menu is hij gewoon zichtbaar.
##
## LOCK-ON (skill met base_lockon_margin): ligt het stipje binnen lockon_margin pixels van de rand
## van iets wat kapot kan (vijand, gebouw), dan zet het vizier zich daarop vast en volgt het mee.
## Losbreken: de muis/stick verder dan die marge van het doel af bewegen. Vastgezet = oranje vizier.
## Doel kapot of weg: het stipje blijft op de laatste plek. Op het maximale level van de skill
## (weapon_type "homing") sturen kogels die je dan afvuurt bij naar het doel (zie weapon_output).
##
## SSOT, rij world: aim_sensitivity (leeg = 1): hoe ver het vizier beweegt per beweging van de muis.
##
## Ontwikkelaarsnotities:
## - Alleen de beweging van de muis telt (InputEventMouseMotion.relative), niet de plek op het scherm.
## - Player (draaien) leest target_point(), GameCamera (vooruitkijken) shown_offset().
## - Lock-on zoekt maar LOCK_SEARCH_INTERVAL keer per seconde naar doelen (groepen targets en
##   enemies), niet elk frame, en alleen binnen het bereik van het wapen.
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

const LOCK_COLOR := Color(1.0, 0.65, 0.2, 0.95)
## Seconden tussen twee zoekrondes naar een lock-on-doel.
const LOCK_SEARCH_INTERVAL := 0.12
## Straal van een doel zonder body_radius (gebouwen e.d.).
const DEFAULT_TARGET_RADIUS := 30.0

## Plek waar je heen wil mikken, ten opzichte van het schip (wereld-pixels).
var aim_offset: Vector2 = Vector2.ZERO
## Het doel waar het vizier op vastzit (lock-on), of null.
var locked_target: Node2D = null
# Waar de muis/stick zelf heen wijst (zonder lock-on), ten opzichte van het schip.
var _raw_offset: Vector2 = Vector2.ZERO
var _lock_search_left: float = 0.0
# Het doel van vorige frame, om het stipje mee te laten bewegen met een vastgezet doel.
var _locked_last_pos: Vector2 = Vector2.ZERO
var _initialized: bool = false


func _ready() -> void:
	top_level = true
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputDevice.ensure_bindings()


## Waar het vizier nu staat (in de richting van het schip), in wereld-coördinaten.
func aim_point() -> Vector2:
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return global_position
	return player.global_position + shown_offset()


## Het vizier ten opzichte van het schip: richting van het schip, afstand van de muis of stick.
func shown_offset() -> Vector2:
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return aim_offset
	return Vector2.from_angle(player.global_rotation) * aim_offset.length()


## Waar je heen wil mikken; hier draait het schip naartoe.
func target_point() -> Vector2:
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return global_position
	return player.global_position + aim_offset


func _input(event: InputEvent) -> void:
	InputDevice.note_event(event)
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	# Schermbeweging omrekenen naar wereld-pixels (houdt rekening met de camerazoom).
	var world_delta: Vector2 = get_viewport().get_canvas_transform().affine_inverse().basis_xform(motion.relative)
	_raw_offset += world_delta * _sensitivity()
	if locked_target == null:
		aim_offset = _raw_offset
	_clamp_to_range()


func _process(delta: float) -> void:
	_update_mouse_mode()
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return
	if not _initialized:
		_initialized = true
		aim_offset = Vector2.RIGHT.rotated(player.global_rotation) * _weapon_range(player) * START_FRACTION
		_raw_offset = aim_offset
	# Controller: de rechter stick geeft de richting, de afstand ligt vast.
	if InputDevice.using_sticks() and not get_tree().paused:
		var stick: Vector2 = InputDevice.aim_vector()
		if stick != Vector2.ZERO:
			_raw_offset = stick.normalized() * _weapon_range(player) * InputDevice.aim_distance()
			if locked_target == null:
				aim_offset = _raw_offset
	_update_lock_on(player, delta)
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
	if _raw_offset.length() > reach:
		_raw_offset = _raw_offset.normalized() * reach


func _draw() -> void:
	var player: Node2D = get_parent() as Node2D
	if not is_instance_valid(player):
		return
	var point: Vector2 = aim_point()
	# Even groot op het scherm, hoe ver de camera ook is uitgezoomd.
	var k: float = GameCamera.ui_scale()
	var color: Color = LOCK_COLOR if locked_target != null else COLOR
	draw_line(player.global_position, point, LINE_COLOR, 1.0 * k)
	draw_arc(point, RING_RADIUS * k, 0.0, TAU, 24, color, WIDTH * k)
	# Vastgezet: de streepjes schuin (een X), zodat het ook zonder kleur te zien is.
	var ticks: Array = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	if locked_target != null:
		ticks = [Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
	for dir in ticks:
		draw_line(point + dir * (RING_RADIUS + 2.0) * k, point + dir * (RING_RADIUS + 2.0 + TICK) * k, color, WIDTH * k)
	var target: Vector2 = target_point()
	if target.distance_to(point) > TARGET_SHOW_DISTANCE * k:
		draw_circle(target, TARGET_RADIUS * k, TARGET_COLOR)


# --- LOCK-ON ---

## Zoekt een doel bij het stipje en houdt het vast zolang je binnen de marge blijft.
func _update_lock_on(player: Node2D, delta: float) -> void:
	var margin: float = lock_margin()
	if margin <= 0.0 or get_tree().paused:
		_unlock()
		return
	if locked_target != null:
		if not _is_lockable(locked_target):
			_unlock()  # kapot of weg: het stipje blijft op de laatste plek
			aim_offset = _raw_offset
		else:
			# Het stipje beweegt mee met het doel (muis); bij de stick wijst de stick zelf.
			var target_pos: Vector2 = locked_target.global_position
			if not InputDevice.using_sticks():
				_raw_offset += target_pos - _locked_last_pos
			_locked_last_pos = target_pos
			var target_offset: Vector2 = target_pos - player.global_position
			if _aim_miss(_raw_offset, target_offset) > _target_radius(locked_target) + margin \
					or target_offset.length() > _weapon_range(player):
				_unlock()
				aim_offset = _raw_offset
			else:
				aim_offset = target_offset
				return
	_lock_search_left -= delta
	if _lock_search_left > 0.0:
		return
	_lock_search_left = LOCK_SEARCH_INTERVAL
	var target: Node2D = _find_target(player, margin)
	if target != null:
		locked_target = target
		_locked_last_pos = target.global_position
		aim_offset = target.global_position - player.global_position


## Zoekt in de RICHTING waarin je mikt (Daan, 26 nov), niet alleen rond het stipje: een doel telt als
## het binnen het bereik van het wapen ligt en hooguit (straal + marge) naast de mik-lijn.
func _find_target(player: Node2D, margin: float) -> Node2D:
	var reach: float = _weapon_range(player)
	var best: Node2D = null
	var best_distance: float = INF
	var seen: Dictionary = {}
	for node in get_tree().get_nodes_in_group("targets") + get_tree().get_nodes_in_group("enemies"):
		if seen.has(node) or not node is Node2D or not _is_lockable(node):
			continue
		seen[node] = true
		var target: Node2D = node
		if target.global_position.distance_to(player.global_position) > reach:
			continue
		var distance: float = _aim_miss(_raw_offset, target.global_position - player.global_position)
		if distance <= _target_radius(target) + margin and distance < best_distance:
			best = target
			best_distance = distance
	return best


## Hoe ver een doel naast de mik-lijn ligt (pixels). Achter het schip = oneindig.
static func _aim_miss(aim: Vector2, target_offset: Vector2) -> float:
	if aim.length() < 1.0:
		return target_offset.length()
	var dir: Vector2 = aim.normalized()
	var along: float = target_offset.dot(dir)
	if along < 0.0:
		return INF
	return (target_offset - dir * along).length()


func _unlock() -> void:
	locked_target = null


## Marge van de lock-on (0 = geen skill): base_lockon_margin via de skills.
static func lock_margin() -> float:
	return maxf(0.0, StatCalc.player_value("player_base", "lockon_margin", 0.0))


## Mag hierop vastgezet worden? Alles wat kapot kan en nog leeft.
static func _is_lockable(node: Node) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.has_method("take_damage"):
		return false
	if "current_health" in node and float(node.current_health) <= 0.0:
		return false
	if "is_destroyed" in node and bool(node.is_destroyed):
		return false
	return true


static func _target_radius(node: Node) -> float:
	if "body_radius" in node:
		return float(node.body_radius)
	return DEFAULT_TARGET_RADIUS


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Muis gevangen tijdens het spelen, verborgen bij controller of touch, vrij bij pauze of met F1 open.
func _update_mouse_mode() -> void:
	var menu_open: bool = get_tree().paused or (is_instance_valid(DebugOverlay) and DebugOverlay.visible)
	var wanted: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
	if menu_open:
		wanted = Input.MOUSE_MODE_VISIBLE
	elif InputDevice.using_sticks():
		wanted = Input.MOUSE_MODE_HIDDEN
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
