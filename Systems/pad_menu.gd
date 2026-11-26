extends Node
## PadMenu (autoload) – menu's bedienen met een controller, zonder dat elk menu daar iets voor hoeft.
##
## Werkt zodra je met de controller speelt en de muis zichtbaar is (hoofdmenu, pauze, skill tree,
## F1-menu). Twee manieren, door elkaar te gebruiken:
## - Linker stick: beweegt het muisje over het scherm. Kruisje klikt op de plek van het muisje.
## - D-pad (of pijltjes): springt van knop naar knop (Godot-focus). Kruisje kiest de knop met focus.
## Rondje = terug (ui_cancel), Start = pauze: die zitten in de InputMap (InputDevice).
##
## Ontwikkelaarsnotities:
## - Ook InputDevice.note_event loopt hier, zodat het wisselen tussen muis en controller overal werkt
##   (ook buiten een run, waar geen Crosshair is).
## - Het muisje verplaatsen en klikken maakt zelf muisinvoer; InputDevice.mark_synthetic_mouse() zorgt
##   dat dat niet terugschakelt naar "muis".
## - Beweegt de stick het muisje, dan gaat de focus van de knoppen af, zodat kruisje op het muisje klikt
##   en niet op een knop die je niet ziet.
## - Touch: later een eigen scherm; tikken werkt in menu's al als klikken.

## Pixels per seconde bij een volle stick (schermpixels).
const CURSOR_SPEED := 1100.0

var _cursor_moved: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputDevice.ensure_bindings()


func _input(event: InputEvent) -> void:
	InputDevice.note_event(event)
	if not _menu_active():
		return
	var viewport: Viewport = get_viewport()
	# Kruisje zonder knop met focus: klik op de plek van het muisje.
	var pressed: InputEventJoypadButton = event as InputEventJoypadButton
	if pressed != null and pressed.pressed and pressed.button_index == JOY_BUTTON_A:
		if viewport.gui_get_focus_owner() == null:
			_click(viewport.get_mouse_position())
			viewport.set_input_as_handled()
		return
	# D-pad zonder focus: de eerste knop krijgt focus, daarna navigeert Godot zelf.
	if event is InputEventJoypadButton and viewport.gui_get_focus_owner() == null:
		for action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
			if event.is_action_pressed(action):
				var first: Control = _first_button()
				if first != null:
					first.grab_focus()
					viewport.set_input_as_handled()
				return


func _process(delta: float) -> void:
	if not _menu_active():
		return
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() < InputDevice.stick_deadzone():
		return
	var viewport: Viewport = get_viewport()
	if viewport.gui_get_focus_owner() != null:
		viewport.gui_release_focus()
	var size: Vector2 = viewport.get_visible_rect().size
	var target: Vector2 = (viewport.get_mouse_position() + stick * CURSOR_SPEED * delta).clamp(Vector2.ZERO, size)
	InputDevice.mark_synthetic_mouse()
	viewport.warp_mouse(target)


## Alleen met de controller, en alleen als de muis zichtbaar is (dus in een menu).
func _menu_active() -> bool:
	return InputDevice.using_pad() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE


func _click(at: Vector2) -> void:
	InputDevice.mark_synthetic_mouse()
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)


## De bovenste zichtbare knop die focus kan krijgen.
func _first_button() -> Control:
	var best: Control = null
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		if button == null or not button.is_visible_in_tree() or button.disabled or button.focus_mode == Control.FOCUS_NONE:
			continue
		if best == null or button.global_position.y < best.global_position.y:
			best = button
	return best
