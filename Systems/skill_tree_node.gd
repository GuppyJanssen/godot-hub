class_name SkillTreeNode
extends Node2D
## SkillTreeNode – één skill in de skill tree: een cirkel met een gekleurde rand.
##
## - Rand (buitenkant): de kleur van de soort skill (wapen, schip, beweging ...).
## - Binnenring: hoe vol de skill is (0–100), met streepjes op 25/50/75%.
## - Onbekend (nog nooit gekocht): zwart vakje met een "?" en een grijze rand.
##
## Ontwikkelaarsnotities:
## - Dit script tekent alleen. Kopen, zichtbaarheid en de popup regelt skill_tree.gd.
## - Klikken en hover gaan via contains_point(), zodat er geen Area2D of physics nodig is.

const RADIUS := 34.0
const RING_WIDTH := 5.0
const PROGRESS_RADIUS := 25.0
const PROGRESS_WIDTH := 4.0
const NAME_FONT_SIZE := 15
const LEVEL_FONT_SIZE := 17

const FILL_COLOR := Color(0.08, 0.09, 0.11)
const UNKNOWN_FILL := Color(0.0, 0.0, 0.0)
const UNKNOWN_RING := Color(0.32, 0.32, 0.34)
const TRACK_COLOR := Color(1, 1, 1, 0.12)
const PROGRESS_COLOR := Color(0.95, 0.95, 0.95)
const TEXT_COLOR := Color(0.92, 0.92, 0.92)

var skill_id: String = ""
var display_name: String = ""
var kind_color: Color = Color.GRAY
var level: int = 0
var max_level: int = 100
## Ooit gekocht: dan zie je wat het is. Anders een zwart vakje.
var discovered: bool = false
## Mag je hier nu punten in zetten (de parent heeft punten)?
var buyable: bool = false
var hovered: bool = false


func setup(id: String, name_text: String, color: Color) -> void:
	skill_id = id
	display_name = name_text
	kind_color = color


func set_state(new_level: int, new_max: int, is_discovered: bool, is_buyable: bool) -> void:
	level = new_level
	max_level = maxi(new_max, 1)
	discovered = is_discovered
	buyable = is_buyable
	modulate.a = 1.0 if buyable or level > 0 else 0.55
	queue_redraw()


func set_hovered(value: bool) -> void:
	if hovered == value:
		return
	hovered = value
	queue_redraw()


func contains_point(global_point: Vector2) -> bool:
	return to_local(global_point).length() <= RADIUS + RING_WIDTH


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var grow: float = 3.0 if hovered else 0.0

	if not discovered:
		draw_circle(Vector2.ZERO, RADIUS + grow, UNKNOWN_FILL)
		draw_arc(Vector2.ZERO, RADIUS + grow, 0.0, TAU, 48, UNKNOWN_RING, RING_WIDTH, true)
		_draw_centered(font, "?", Vector2(0, 8), 26, UNKNOWN_RING.lightened(0.3))
		return

	draw_circle(Vector2.ZERO, RADIUS + grow, FILL_COLOR)
	# Gekleurde rand aan de buitenkant: de soort skill.
	draw_arc(Vector2.ZERO, RADIUS + grow, 0.0, TAU, 48, kind_color, RING_WIDTH, true)

	# Binnenring: hoe vol de skill is, vanaf boven met de klok mee.
	draw_arc(Vector2.ZERO, PROGRESS_RADIUS, 0.0, TAU, 40, TRACK_COLOR, PROGRESS_WIDTH, true)
	var fraction: float = clampf(float(level) / float(max_level), 0.0, 1.0)
	if fraction > 0.0:
		var start: float = -PI / 2.0
		draw_arc(Vector2.ZERO, PROGRESS_RADIUS, start, start + TAU * fraction, 40,
				kind_color.lerp(PROGRESS_COLOR, 0.5), PROGRESS_WIDTH, true)
	# Mijlpalen op 25, 50 en 75%.
	for quarter in [0.25, 0.5, 0.75]:
		var dir: Vector2 = Vector2.from_angle(-PI / 2.0 + TAU * quarter)
		draw_line(dir * (PROGRESS_RADIUS - 4.0), dir * (PROGRESS_RADIUS + 4.0), Color(1, 1, 1, 0.35), 1.5, true)

	_draw_centered(font, str(level), Vector2(0, 6), LEVEL_FONT_SIZE, TEXT_COLOR)
	_draw_centered(font, display_name, Vector2(0, RADIUS + 22), NAME_FONT_SIZE, TEXT_COLOR)


func _draw_centered(font: Font, text: String, baseline: Vector2, size: int, color: Color) -> void:
	var width: float = 220.0
	draw_string(font, baseline - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)
