extends CanvasLayer
## FactionWarMap – debugkaart van de factie-oorlog.
##
## Autoload: voeg dit script toe als "FactionWarMap".
##
## ALLEEN voor testen: in een gewone export (release) haalt de kaart zichzelf meteen weg,
## dus normale spelers zien hem nooit. In de editor en in een debug-export werkt hij wel.
##
## Toetsen:
##   F2 = kaart aan/uit
##   F3 = (terwijl de kaart open is) de oorlog versnellen: 1x, 10x, 60x
##
## Hoe je de kaart leest:
##   - Elke rij is een ring. Onderaan de zuidpool, bovenaan de noordpool.
##   - Elk vakje is een kamer, gekleurd naar de factie die hem bezit. Hoe feller, hoe sterker.
##   - Grijs = leeg. Donkerrood = net door de speler leeggemaakt.
##   - Een dun streepje bovenin een vakje = die kamer wordt aangevallen (kleur van de aanvaller).
##   - Wit kader = de kamer waar de speler nu is.
##
## Later kan deze kaart naar het F1-debugscherm verhuizen.

const MAP_WIDTH := 1200.0
const ROW_HEIGHT := 34.0
const LABEL_WIDTH := 80.0
const MARGIN := 16.0
const HEADER_HEIGHT := 40.0
const FOOTER_HEIGHT := 50.0
const FONT_SIZE := 16
const SPEEDS: Array = [1.0, 10.0, 60.0]
const REDRAW_SECONDS := 0.2

const EMPTY_COLOR := Color(0.18, 0.18, 0.18)
const CLEARED_COLOR := Color(0.4, 0.08, 0.08)

var _view: Control
var _speed_index: int = 0
var _redraw_timer: float = 0.0


func _ready() -> void:
	# Normale spelers krijgen de kaart nooit te zien.
	if not OS.is_debug_build():
		queue_free()
		return

	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.position = Vector2(40.0, 40.0)
	add_child(_view)
	_view.draw.connect(_draw_map)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_F2:
		visible = not visible
		_view.queue_redraw()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_F3 and visible:
		_speed_index = (_speed_index + 1) % SPEEDS.size()
		FactionWar.debug_time_scale = SPEEDS[_speed_index]
		print("FACTIEOORLOG-KAART: snelheid ", SPEEDS[_speed_index], "x")
		_view.queue_redraw()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_SECONDS
		_view.queue_redraw()


func _draw_map() -> void:
	var font: Font = ThemeDB.fallback_font
	var ring_count: int = FactionWar.rooms.size()
	var total_width: float = LABEL_WIDTH + MAP_WIDTH + MARGIN * 2.0
	var total_height: float = HEADER_HEIGHT + maxi(ring_count, 1) * ROW_HEIGHT + FOOTER_HEIGHT + MARGIN * 2.0
	_view.draw_rect(Rect2(0.0, 0.0, total_width, total_height), Color(0.0, 0.0, 0.0, 0.85))

	# Kopregel: tijd en snelheid.
	var t: int = int(FactionWar.war_time)
	var header: String = "FACTIEOORLOG   tijd %d:%02d   snelheid %sx   (F2 sluiten, F3 versnellen)" % [floori(t / 60.0), t % 60, str(SPEEDS[_speed_index])]
	if not FactionWar.active:
		header = "FACTIEOORLOG   geen oorlog actief (start een New Run)"
	_view.draw_string(font, Vector2(MARGIN, MARGIN + 18.0), header, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
	if ring_count == 0:
		return

	var max_strength: float = FactionWar.get_setting("max_strength")
	for r in ring_count:
		var row_y: float = MARGIN + HEADER_HEIGHT + (ring_count - 1 - r) * ROW_HEIGHT
		var ring_rooms: Array = FactionWar.rooms[r]
		var width: int = ring_rooms.size()
		var cell_width: float = MAP_WIDTH / width

		_view.draw_string(font, Vector2(MARGIN, row_y + ROW_HEIGHT * 0.65), "Ring %d" % r, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0.8, 0.8, 0.8))

		for i in width:
			var room: Dictionary = ring_rooms[i]
			var rect: Rect2 = Rect2(MARGIN + LABEL_WIDTH + i * cell_width, row_y, maxf(cell_width - 1.0, 1.0), ROW_HEIGHT - 4.0)
			_view.draw_rect(rect, _room_color(room, max_strength))

			# Wordt aangevallen of ingenomen: streepje in de kleur van de aanvaller.
			var attacker: String = room["attacker"]
			if attacker != "":
				_view.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), faction_color(attacker))

			# De kamer van de speler.
			if r == LevelManager.current_layer and i == LevelManager.current_room_index:
				_view.draw_rect(rect.grow(1.0), Color.WHITE, false, 2.0)

	# Onderregel: hoeveel kamers elke factie heeft.
	var counts: Dictionary = FactionWar.owner_counts()
	var factions: Array = counts.keys()
	factions.sort()
	var legend: String = ""
	for faction in factions:
		var label: String = "leeg" if faction == "" else str(faction).to_upper()
		legend += "%s: %d    " % [label, counts[faction]]
	var footer_y: float = MARGIN + HEADER_HEIGHT + ring_count * ROW_HEIGHT + 28.0
	_view.draw_string(font, Vector2(MARGIN, footer_y), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)


func _room_color(room: Dictionary, max_strength: float) -> Color:
	var holder: String = room["owner"]
	if holder == "":
		return CLEARED_COLOR if room["cleared_at"] >= 0.0 else EMPTY_COLOR
	var strength: float = clampf(room["strength"] / maxf(max_strength, 1.0), 0.0, 1.0)
	# Zwakke kamers donker, sterke kamers fel.
	return faction_color(holder).lerp(Color.BLACK, 0.7 * (1.0 - strength))


## De kleur van een factie. Een hybride krijgt de mengkleur van zijn twee ouders.
static func faction_color(faction: String) -> Color:
	# Staat er een eigen kleur in de SSOT, dan gaat die voor (ook voor hybrides).
	if Ssot.has_value(EnemyStats.faction_row(faction), EnemyStats.COLOR_COLUMN):
		return EnemyStats.color(faction)
	if faction.length() == 2:
		return EnemyStats.color(faction.substr(0, 1)).lerp(EnemyStats.color(faction.substr(1, 1)), 0.5)
	return EnemyStats.color(faction)
