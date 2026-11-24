extends Node
# SINGLE SOURCE OF TRUTH: LevelManager / Router

## Aantal kamers per ring, van de Zuidpool (ring 0) tot de Noordpool. Komt uit de SSOT
## (rij world, kolom world_ring_widths, bijvoorbeeld "1/6/12/24/48/96/48/24/12/6/1").
## De factie-oorlog kent precies RING_COUNT ringen; een lijst met een ander aantal wordt genegeerd.
const RING_COUNT := 11
const DEFAULT_LAYER_WIDTHS: Array[int] = [1, 6, 12, 24, 48, 96, 48, 24, 12, 6, 1]
## Grootste aantal kamers in één ring (beschermt tegen een typfout als 9600).
const MAX_RING_WIDTH := 1000
var LAYER_WIDTHS: Array[int] = DEFAULT_LAYER_WIDTHS.duplicate()


func _ready() -> void:
	# Ssot is een latere autoload: pas lezen als alle autoloads klaar staan, en opnieuw na elke load.
	call_deferred("_load_ring_widths")
	Ssot.loaded.connect(_load_ring_widths)


func _load_ring_widths() -> void:
	var text: String = Ssot.get_text("world", "world_ring_widths", "")
	if text.strip_edges() == "":
		return
	var widths: Array[int] = []
	for part in text.split("/"):
		var clean: String = part.strip_edges()
		if not clean.is_valid_int() or clean.to_int() < 1 or clean.to_int() > MAX_RING_WIDTH:
			push_warning("LevelManager: world_ring_widths '%s' bevat een ongeldig getal; standaard gebruikt." % text)
			return
		widths.append(clean.to_int())
	if widths.size() != RING_COUNT or widths[0] != 1 or widths[widths.size() - 1] != 1:
		push_warning("LevelManager: world_ring_widths moet %d ringen hebben en met 1 beginnen en eindigen; standaard gebruikt." % RING_COUNT)
		return
	LAYER_WIDTHS = widths

var current_layer: int = 0       
var current_room_index: int = 0  
var is_loading_from_continue: bool = false
## In de testkamer onder de startkamer (alleen bereikbaar met God Mode). De ring blijft dan 0.
var in_test_room: bool = false


func reset_manager_for_new_run() -> void:
	current_layer = 0
	current_room_index = 0
	is_loading_from_continue = false
	in_test_room = false
	set_meta("last_direction", "up")
	set_meta("player_exit_x", 960.0)
	set_meta("player_exit_y", 1000.0)
	print("LEVEL MANAGER: Router succesvol gereset naar Ring 0.")
