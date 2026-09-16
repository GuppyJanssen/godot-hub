extends Node2D # Dit script hoort bij onze hoofdnode van het type Node2D.

# --- VARIABELEN ---
# @export: Zorgt voor een leeg vakje in de Inspector waarin we 'player.tscn' slepen.
@export var player_scene: PackedScene

# @onready: Zoekt in de boomstructuur naar de marker zodra het spel start.
# Omdat PlayerSpawnPoint direct onder Spawn_Area hangt, vindt het '$'-teken hem nu direct!
@onready var spawn_point: Marker2D = $PlayerSpawnPoint


# --- INGEBOUWDE GODOT FUNCTIES ---

# _ready() start exact één keer zodra deze scène wordt opgestart.
func _ready() -> void:
	spawn_the_player() # We roepen direct onze spawn-functie aan bij de start.


# _process(delta) draait continu op de achtergrond.
func _process(_delta: float) -> void:
	# Als je op de Spatiebalk drukt, spawnen we een nieuwe test-speler op de coördinaten.
	if Input.is_action_just_pressed("ui_accept"):
		spawn_the_player()


# --- EIGEN FUNCTIES ---

func spawn_the_player() -> void:
	# VEILIGHEIDSCHECK 1: Is er een speler-scène gekoppeld in de Inspector?
	if not player_scene:
		push_error("Fout: Sleep 'player.tscn' in het Player Scene vakje van de Spawn_Area!")
		return

	# VEILIGHEIDSCHECK 2: Bestaat onze zojuist gemaakte Marker2D wel echt?
	if not spawn_point:
		push_error("Fout: De node 'PlayerSpawnPoint' kan niet worden gevonden. Controleer de spelling linksboven!")
		return

	# ALS ALLES KLOPT, SPAWN VEILIG:
	# 1. Maak de actieve kopie van het spelerscript in het geheugen.
	var new_player = player_scene.instantiate()
	
	# 2. Plak de speler eerst in de wereldscène.
	add_child(new_player)
	
	# 3. Geef de speler de exacte X- en Y-coördinaten (500, 400) van onze marker.
	new_player.global_position = spawn_point.global_position
