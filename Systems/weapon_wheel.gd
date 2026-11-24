extends CanvasLayer
## WeaponWheel – laat de vier wapenvakken zien als je wisselt (scrollen of 1 t/m 4).
##
## De speler maakt dit zelf aan (Player.gd). Na een wissel is het wiel even zichtbaar
## en verdwijnt het weer. Vakken: 1 = boven, 2 = rechts, 3 = onder, 4 = links.

const SHOW_SECONDS := 1.5
const RADIUS := 90.0
const SLOT_SIZE := Vector2(170.0, 40.0)
## Richting van elk vak vanuit het midden: boven, rechts, onder, links.
const DIRECTIONS: Array = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
const COLOR_SELECTED := Color(1.0, 0.8, 0.2, 0.95)
const COLOR_FILLED := Color(0.15, 0.15, 0.15, 0.85)
const COLOR_EMPTY := Color(0.15, 0.15, 0.15, 0.4)

var _root: Control
var _panels: Array = []
var _labels: Array = []
var _timer: float = 0.0


func _ready() -> void:
	layer = 50
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	for slot in DIRECTIONS.size():
		var panel: Panel = Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.size = SLOT_SIZE
		_root.add_child(panel)
		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = SLOT_SIZE
		panel.add_child(label)
		_panels.append(panel)
		_labels.append(label)
	_root.visible = false


## Toon het wiel even (na een wissel of een druk op 1 t/m 4).
func show_wheel() -> void:
	refresh()
	_root.visible = true
	_timer = SHOW_SECONDS


func refresh() -> void:
	var center: Vector2 = _root.get_viewport_rect().size / 2.0
	for slot in _panels.size():
		var panel: Panel = _panels[slot]
		var weapon: String = str(RunState.weapon_slots[slot])
		panel.position = center + DIRECTIONS[slot] * RADIUS - SLOT_SIZE / 2.0
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		if slot == RunState.weapon_selected:
			style.bg_color = COLOR_SELECTED
		elif weapon != "":
			style.bg_color = COLOR_FILLED
		else:
			style.bg_color = COLOR_EMPTY
		panel.add_theme_stylebox_override("panel", style)
		var weapon_name: String = Ssot.get_text(weapon, "ingame_name", weapon) if weapon != "" else "leeg"
		_labels[slot].text = "%d  %s" % [slot + 1, weapon_name]
		_labels[slot].add_theme_color_override("font_color", Color.BLACK if slot == RunState.weapon_selected else Color.WHITE)


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_root.visible = false
