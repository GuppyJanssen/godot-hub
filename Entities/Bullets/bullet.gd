extends Area2D

# --- DYNAMIC DATA INTERFACE ---
# Dit is de variabele waar de speler de 'Bullet_Data.tres' in stopt.
var current_stats: BulletStats


# --- INGEBOUWDE GODOT FUNCTIES ---

# _ready() start zodra de kogel succesvol in de Spawn_Area wereldscène is geplaatst.
func _ready() -> void:
	# Veiligheidscheck: als er per ongeluk GEEN stats zijn meegegeven, wissen we de kogel direct.
	if not current_stats:
		push_error("Fout: Kogel is gespawned zonder BulletStats resource!")
		queue_free()
		return
		
	# IN GAME VARIATIES LIVE TOEPASSEN:
	
	# 1. Grootte aanpassen (Size)
	scale = Vector2.ONE * current_stats.size_multiplier
	
	# 2. Sprite/Art live inladen
	if current_stats.texture:
		$Sprite.texture = current_stats.texture
		
	# --- AUTOMATISCH OPRUIMEN (HIERHEEN VERHUISD) ---
	# We wachten nu veilig binnen de _ready() functie 3 seconden af...
	await get_tree().create_timer(3.0).timeout
	# ...en wissen de kogel daarna uit het geheugen, zodat de game niet traag wordt.
	queue_free()


# _physics_process draait elke frame. Hier regelen we de vliegroute.
func _physics_process(delta: float) -> void:
	if not current_stats:
		return
		
	# 3. Kogel trajectory / vliegroute
	var direction: Vector2 = Vector2.RIGHT.rotated(rotation)
	
	# We verplaatsen de kogel over het scherm met de snelheid uit de meegegeven Resource
	global_position += direction * current_stats.speed * delta
