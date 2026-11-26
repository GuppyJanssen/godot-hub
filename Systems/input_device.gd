class_name InputDevice
## InputDevice – houdt bij of de speler met muis/toetsenbord of met een controller speelt,
## en leest de controller uit voor de twin stick-besturing.
##
## Besturing met een controller:
##   Linker stick      vliegen (gekoppeld aan de bestaande beweeg-acties, zie MOVE_BINDINGS)
##   Rechter stick     richten (alleen de richting; de afstand is aim_stick_distance × bereik)
##   Rechter trigger   schieten (ook losse schoten: de trigger werkt als een knop)
##
## Touchscreen: twee virtuele sticks en een schietknop (komt in een eigen TouchControls-scherm).
## Die drukken dezelfde acties in als de controller, via Input.action_press(actie, sterkte).
## Het schip, het vizier en het schieten merken dus geen verschil tussen controller en touch.
##
## Wisselen gaat vanzelf: muis of toets = muis/toetsenbord, stick of knop = controller,
## aanraken van het scherm = touch.
##
## SSOT, rij world (leeg = de standaard hieronder):
##   stick_deadzone       0..0,9: onder deze uitslag telt een stick niet (tegen "drift")
##   aim_stick_distance   0,1..1: afstand van het vizier bij de controller, als deel van het bereik
##
## Ontwikkelaarsnotities:
## - Alles statisch: geen autoload nodig. Crosshair geeft elke invoer door aan note_event().
## - ensure_bindings() voegt de controller-knoppen toe aan de InputMap als ze er nog niet zijn.
##   Bestaande toetsenbord-/muisknoppen blijven gewoon werken. Een actie die niet bestaat, wordt
##   overgeslagen met een waarschuwing (dan klopt de naam in MOVE_BINDINGS niet).
## - Alle acties krijgen hun eigen dode zone mee (InputMap.action_set_deadzone), zodat
##   Input.get_vector en is_action_just_pressed vanzelf de dode zone gebruiken.

enum Mode { MOUSE, PAD, TOUCH }

## Acties voor richten en schieten met de controller (worden aangemaakt als ze ontbreken).
const AIM_LEFT := "pad_aim_left"
const AIM_RIGHT := "pad_aim_right"
const AIM_UP := "pad_aim_up"
const AIM_DOWN := "pad_aim_down"
const FIRE := "pad_fire"

## Bestaande beweeg-acties → as en richting van de linker stick.
## Pas de namen aan als het project andere namen gebruikt (zie Projectinstellingen > Invoer).
const MOVE_BINDINGS := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}

const DEFAULT_DEADZONE := 0.25
const DEFAULT_AIM_DISTANCE := 0.7
## Vanaf deze uitslag telt de trigger als ingedrukt.
const TRIGGER_THRESHOLD := 0.5

static var mode: Mode = Mode.MOUSE
static var _bound: bool = false


## Zet de controller-knoppen in de InputMap. Veilig om vaker aan te roepen.
static func ensure_bindings() -> void:
	if _bound:
		return
	_bound = true
	var deadzone: float = stick_deadzone()
	_add_axis(AIM_LEFT, JOY_AXIS_RIGHT_X, -1.0, deadzone)
	_add_axis(AIM_RIGHT, JOY_AXIS_RIGHT_X, 1.0, deadzone)
	_add_axis(AIM_UP, JOY_AXIS_RIGHT_Y, -1.0, deadzone)
	_add_axis(AIM_DOWN, JOY_AXIS_RIGHT_Y, 1.0, deadzone)
	_add_axis(FIRE, JOY_AXIS_TRIGGER_RIGHT, 1.0, TRIGGER_THRESHOLD)
	for action in MOVE_BINDINGS:
		if not InputMap.has_action(action):
			push_warning("InputDevice: beweeg-actie '%s' bestaat niet; linker stick daarvoor niet gekoppeld." % action)
			continue
		var binding: Array = MOVE_BINDINGS[action]
		_add_axis(action, int(binding[0]), float(binding[1]), deadzone, false)


## Elke invoer langs laten komen; bepaalt welk apparaat nu gebruikt wordt.
static func note_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		mode = Mode.MOUSE
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		mode = Mode.TOUCH
	elif event is InputEventJoypadButton:
		mode = Mode.PAD
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > stick_deadzone():
		mode = Mode.PAD


static func using_pad() -> bool:
	return mode == Mode.PAD


static func using_touch() -> bool:
	return mode == Mode.TOUCH


## Richten met een stick (controller of virtueel op het touchscreen) in plaats van de muis.
static func using_sticks() -> bool:
	return mode != Mode.MOUSE


## Richting van de rechter stick (lengte 0..1), of nul binnen de dode zone.
static func aim_vector() -> Vector2:
	ensure_bindings()
	return Input.get_vector(AIM_LEFT, AIM_RIGHT, AIM_UP, AIM_DOWN)


## Schieten met de trigger: vasthouden (automatische wapens) en net ingedrukt (losse schoten).
static func fire_held() -> bool:
	ensure_bindings()
	return Input.is_action_pressed(FIRE)


static func fire_just_pressed() -> bool:
	ensure_bindings()
	return Input.is_action_just_pressed(FIRE)


static func stick_deadzone() -> float:
	return clampf(Ssot.get_number("world", "stick_deadzone", DEFAULT_DEADZONE), 0.0, 0.9)


static func aim_distance() -> float:
	return clampf(Ssot.get_number("world", "aim_stick_distance", DEFAULT_AIM_DISTANCE), 0.1, 1.0)


# Maakt de actie aan (als die er nog niet is) en koppelt een as van de controller.
static func _add_axis(action: String, axis: int, direction: float, deadzone: float, set_deadzone: bool = true) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	elif set_deadzone:
		InputMap.action_set_deadzone(action, deadzone)
	for existing in InputMap.action_get_events(action):
		var motion: InputEventJoypadMotion = existing as InputEventJoypadMotion
		if motion != null and motion.axis == axis and signf(motion.axis_value) == signf(direction):
			return  # staat er al
	var event := InputEventJoypadMotion.new()
	event.device = -1  # elke controller
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)
