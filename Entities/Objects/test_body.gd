extends CharacterBody2D
# SSoT TEST-VIJAND: Geconsolideerd met Bewegings-AI, CSV-Geboorte & Loot-Explosies

# --- VARIABELEN (Gekoppeld aan de database) ---
var max_health: int = 50
var current_health: int = 50

# Bewegingsstats (Snelheid waarmee ze achter je aan jagen)
@export var movement_speed: float = 140.0
@export var rotation_speed: float = 4.0

# Editor-keuze voor welk Excel-type deze vijand is
@export_range(1, 6) var test_body_type: int = 1

# --- FACTIE EN TYPE ---
# Samen bepalen ze welke waarden deze vijand krijgt (zie Systems/enemy_stats.gd).
# De fabriek vult ze in bij het maken. Voor een vijand die vast in de kamer staat,
# vul je ze in de Inspector in. Leeg = de oude manier via test_body_type.
@export var faction: String = ""
@export var unit_type: String = ""

# Hoe de stats in de SSOT heten (base_max_health, max_health_modifier, base_speed ...).
const STAT_HEALTH := "max_health"
const STAT_SPEED := "speed"

# --- DRAAIEN ---
## Aan: de vijand draait zijn voorkant naar de speler (zoals een schip).
## Uit: de vijand heeft geen voorkant en tolt rustig rond, zoals iets dat door de ruimte zweeft
## (bijvoorbeeld de organische spore). Zet dit per vijand-scene in de Inspector.
@export var faces_player: bool = true
## Bij tollen: de draaisnelheid wordt bij de geboorte willekeurig gekozen, tussen min en max
## (in radialen per seconde; 1 is ongeveer een zesde rondje per seconde). Linksom of rechtsom is ook willekeurig.
@export var tumble_speed_min: float = 0.3
@export var tumble_speed_max: float = 1.2
## Bij tollen: hoeveel een treffer de draai een zetje geeft.
@export var hit_spin_kick: float = 0.8

## De huidige draaisnelheid bij tollen (radialen per seconde, min = linksom).
var spin: float = 0.0


func _ready() -> void:
	add_to_group("targets")
	add_to_group("enemies")
	add_to_group("saveable")  # deze vijand wil onthouden worden (zie game_room.gd)
	
	# 1. DATA LADEN UIT DE SINGLE SOURCE OF TRUTH (SSoT) CSV
	_load_stats()
	
	# Geen voorkant: begin in een willekeurige stand en kies een eigen draaisnelheid.
	if not faces_player:
		global_rotation = randf() * TAU
		spin = randf_range(tumble_speed_min, tumble_speed_max) * (1.0 if randf() < 0.5 else -1.0)
	
	# 2. SSoT GEBOORTE-CHECK (Voorkomt herrijzenis uit de dood)
	await get_tree().process_frame
	
	if RunState.is_dead(LevelManager.current_layer, LevelManager.current_room_index, name):
		print("RUNSTATE: ", name, " is deze run al gedood. queue_free() geactiveerd!")
		queue_free()
		return
	
	# Was deze vijand er al toen je de kamer verliet? Zet dan zijn HP en zijn plek terug.
	var saved: Dictionary = RunState.get_saved_unit(LevelManager.current_layer, LevelManager.current_room_index, name)
	if not saved.is_empty():
		apply_run_state(saved)
		print("RUNSTATE: ", name, " teruggezet met HP ", current_health, "/", max_health)


# Laadt de waarden van deze vijand. Wordt aangeroepen bij de geboorte, en opnieuw
# als een bewaarde vijand zijn factie en type terugkrijgt.
func _load_stats() -> void:
	if faction != "" and unit_type != "" and EnemyStats.exists(faction, unit_type):
		# NIEUW: factie × type uit de SSOT.
		max_health = int(EnemyStats.value(faction, unit_type, STAT_HEALTH, max_health))
		movement_speed = EnemyStats.value(faction, unit_type, STAT_SPEED, movement_speed)
		print(name, " geboren als factie ", faction, " / ", unit_type, ". HP: ", max_health)
	else:
		# OUD: de testrijen enemy_test_1 t/m 6 uit de MasterDatabase.
		var csv_key = "enemy_test_" + str(test_body_type)
		if csv_key in MasterDatabase.enemy_data:
			var e_data = MasterDatabase.enemy_data[csv_key]
			var e_stats = e_data["base_stats"]
		
			if "health" in e_stats: 
				max_health = int(e_stats["health"])
			if "loot_amount_blocks" in e_stats:
				set_meta("loot_blocks", int(e_stats["loot_amount_blocks"]))
			
			print(name, " succesvol geboren! HP geladen uit SSoT CSV: ", max_health)
		else:
			max_health = 50
			set_meta("loot_blocks", 3)
	
	# De kleur van de factie over de hele vijand. De witte flits bij een treffer zit op de
	# sprite zelf, dus die blijft gewoon werken.
	if faction != "":
		modulate = EnemyStats.color(faction)
	
	current_health = max_health


# --- ONTHOUDEN: de drie functies voor de groep "saveable" ---

# De naam waaraan deze vijand herkend wordt binnen de kamer.
func get_run_id() -> String:
	return str(name)


# Wat deze vijand wil bewaren als je de kamer verlaat of naar het hoofdmenu gaat.
func get_run_state() -> Dictionary:
	if current_health <= 0:
		return {}  # dood: niet bewaren, de dodenlijst regelt dat
	return {
		"keep_name": true,
		"faction": faction,
		"unit_type": unit_type,
		"hp": current_health,
		"x": global_position.x,
		"y": global_position.y,
		"rot": global_rotation,
		"spin": spin,
	}


# Zet de bewaarde gegevens terug.
func apply_run_state(data: Dictionary) -> void:
	# Eerst factie en type terug, zodat de juiste waarden (max HP, snelheid, kleur) geladen worden.
	var saved_faction: String = str(data.get("faction", faction))
	var saved_type: String = str(data.get("unit_type", unit_type))
	if saved_faction != faction or saved_type != unit_type:
		faction = saved_faction
		unit_type = saved_type
		_load_stats()
	current_health = int(data.get("hp", max_health))
	global_position = Vector2(float(data.get("x", global_position.x)), float(data.get("y", global_position.y)))
	global_rotation = float(data.get("rot", global_rotation))
	spin = float(data.get("spin", spin))


# --- 3. DYNAMISCHE BEWEGINGS-AI (60x per seconde) ---
func _physics_process(delta: float) -> void:
	var player = Game.active_player
	
	# Geen voorkant: gewoon doortollen. In de ruimte remt niets het draaien af.
	if not faces_player:
		global_rotation += spin * delta
	
	if is_instance_valid(player):
		# Bereken de richtingvector naar de speler toe
		var direction_to_player = (player.global_position - global_position).normalized()
		
		# Draai de neus/sprite van de vijand vlot richting de astronaut (alleen als hij een voorkant heeft)
		if faces_player:
			var target_angle = direction_to_player.angle()
			global_rotation = rotate_toward(global_rotation, target_angle, rotation_speed * delta)
		
		# Geef de snelheid mee aan de CharacterBody2D en glijd over het veld
		velocity = direction_to_player * movement_speed
		move_and_slide()
	else:
		# Rem rustig af tot stilstand als de speler dood of onzichtbaar is
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()


# --- 4. SCHADE-AFHANDELING EN ARCADE-FLITS ---
func take_damage(amount: int, flash: bool = true, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0: 
		return
		
	current_health = max(0, current_health - amount)
	print(name, " geraakt tijdens het spelen! HP over: ", current_health, "/", max_health)
	
	# Een treffer geeft een tollende vijand een zetje, linksom of rechtsom.
	if not faces_player:
		spin = clampf(spin + randf_range(-1.0, 1.0) * hit_spin_kick, -tumble_speed_max * 2.0, tumble_speed_max * 2.0)
	
	if flash and has_method("flash_white"):
		call("flash_white")
	elif flash:
		_flash_white()
	
	if current_health <= 0:
		call_deferred("_deferred_death", hit_dir)


# GECORRIGEERD: Smijt de grunt direct uit de groepen zodat de deuren per direct openvliegen!
func _deferred_death(hit_dir: Vector2) -> void:
	# BINGO: Haal de node direct administratief uit de actieve groepen.
	# Dit voorkomt dat queue_free() de deurenteller in game_room.gd een frame lang gijzelt!
	if is_in_group("targets"): remove_from_group("targets")
	if is_in_group("enemies"): remove_from_group("enemies")
	
	# Onthoud in RunState dat deze vijand dood is. RunState bewaart dat voor de hele run.
	RunState.mark_dead(LevelManager.current_layer, LevelManager.current_room_index, name)
	print("VIJAND: Overlijden van ", name, " onthouden in RunState.")

	_drop_specific_loot(hit_dir)
	queue_free()


# --- 5. SAPPIGE LOOT EXPLOSIE ---
func _drop_specific_loot(hit_dir: Vector2) -> void:
	# Geen richting meegekregen? Neem dan de lijn van de speler naar deze vijand.
	# Kogels komen van de speler, dus dat is bijna altijd de vliegrichting.
	if hit_dir == Vector2.ZERO and is_instance_valid(Game.active_player):
		hit_dir = (global_position - Game.active_player.global_position).normalized()
	var loot_scene = load("res://Entities/Loot/loot_drop.tscn")
	if not loot_scene: 
		return
	
	# --- 1. MATS-WISKUNDE: GEWOGEN KANS VOOR AANTAL BLOKJES (3 t/m 10) ---
	# We rollen een willekeurige float tussen 0.0 en 1.0
	var roll = randf()
	var total_drops: int = 3 # De absolute, veelvoorkomende basis stand
	
	if roll < 0.50:
		total_drops = 3     # 50% kans op exact 3 blokjes
	elif roll < 0.75:
		total_drops = 4     # 25% kans op 4 blokjes
	elif roll < 0.88:
		total_drops = 5     # 13% kans op 5 blokjes
	elif roll < 0.94:
		total_drops = 6     # 6% kans op 6 blokjes
	elif roll < 0.97:
		total_drops = 7     # 3% kans op 7 blokjes
	elif roll < 0.99:
		total_drops = 8     # 2% kans op 8 blokjes
	elif roll < 0.995:
		total_drops = 9     # 0.5% kans op 9 blokjes
	else:
		total_drops = 10    # SLECHTS 0.5% KANS: De absolute Jackpot van 10 blokjes!
		print("JACKPOT! De database rolt een zeldzame 10-blokjes drop!")

	# --- 2. DE FYSIEKE SPAWN LUS ---
	# Instellingen van de splatter: spreiding, snelheden, afremming, startvlek.
	var settings: Dictionary = LootSplatter.default_settings()
	var offset: float = float(settings["start_offset"])

	for i in range(total_drops):
		var loot_instance = loot_scene.instantiate()

		# Elk blokje is exact 1 eenheid waard.
		loot_instance.init_loot(test_body_type, 1)

		# Kleine startvlek, daarna de streep in de richting van het schot.
		loot_instance.global_position = global_position + Vector2(randf_range(-offset, offset), randf_range(-offset, offset))
		loot_instance.launch_splatter(hit_dir, settings)

		get_tree().current_scene.add_child(loot_instance)
	print("VIJAND DROP: '", name, "' heeft succesvol ", total_drops, " losse SSoT-kristallen op het veld geworpen.")

# Laat ALLE plaatjes van de vijand even wit oplichten. Eerst werd alleen het eerste plaatje
# met "Sprite" in de naam gebruikt; sinds de nieuwe sprite was dat het oude icoon dat eronder ligt.
func _flash_white() -> void:
	var sprites: Array = []
	for child in find_children("*", "", true, false):
		if (child is Sprite2D or child is AnimatedSprite2D) and child.visible:
			sprites.append(child)
	for s in sprites:
		s.modulate = Color(4.0, 4.0, 4.0, 1.0)
	await get_tree().create_timer(0.055, false).timeout
	for s in sprites:
		if is_instance_valid(s):
			s.modulate = Color.WHITE
