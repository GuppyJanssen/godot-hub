extends CharacterBody2D
class_name EnemySpawner
# ÉÉN script voor ALLE fabrieken, van elke factie en elk type.
# Wat een fabriek anders maakt, stel je in de Inspector in, niet in de code:
#   - Enemy Scene  : welke vijand-scene hij maakt
#   - Faction      : "a", "b", "c", later "ab", "d" ...  -> welke factie
#   - Spawn Unit Type : "light" of "heavy"                -> welk type vijand hij maakt
#   - Sprite Scale : hoe groot de fabriek getekend wordt (1.0 = normaal, 1.5 = heavy)
# Het plaatje zelf kies je op de Sprite2D-node van de fabriek.
#
# Factie en type gaan mee naar elke vijand die hij maakt. De vijand haalt daarmee zijn
# waarden uit de SSOT (zie Systems/enemy_stats.gd).


@export var enemy_scene: PackedScene = null

# --- WAT VOOR FABRIEK IS DIT? ---
@export var faction: String = "a"
## Welk type vijand deze fabriek MAAKT (light = grunts, heavy = zware). De fabriek zelf is altijd
## van het type "factory": zijn levens komen uit de SSOT-rij unit_factory (plus de factie-modifier).
@export var spawn_unit_type: String = "light"
## Welk gebouw dit is: "factory", of een ander gebouw-type uit de SSOT (tower, hq ...).
## Levens, grootte en loot komen uit de rij unit_<building_type>. Alleen een fabriek maakt vijanden.
@export var building_type: String = "factory"
@export var sprite_scale: float = 1.0
## Testfabriek (testkamer): maakt geen vijanden en wordt niet onthouden (dropt wel loot).
@export var passive: bool = false

# --- CONFIGURATIE OPTIES ---
@export var spawner_max_health: float = 150.0  # Hoeveel schade kan deze fabriek hebben?
@export var total_enemies_to_spawn: int = -1    # -1 = Oneindig doorgaan tot hij kapot is
@export var spawn_interval_seconds: float = 3.0
@export var spawn_on_start: bool = true
## Vijanden per keer (base_spawn_amount in de SSOT). De Inspector-waarde geldt als de SSOT leeg is.
@export var spawn_per_wave: int = 1

# Interne variabelen
var spawner_current_health: float = 150.0
var enemies_spawned_count: int = 0
var spawn_timer: Timer = null
var active_scene: Node = null
var my_id: String = ""
var room_key: String = ""
var room_layer: int = 0
var room_index: int = 0
var is_destroyed: bool = false
var restored_timer_left: float = 0.0  # resterende tijd tot de volgende vijand, na het laden
var last_hit_dir: Vector2 = Vector2.ZERO  # richting van de laatste treffer, voor de loot-splatter
## Schild uit de SSOT (max_shield ... op de gebouw-rij, bijvoorbeeld unit_hq). Zie EnemyShield.
var shield: EnemyShield = null
## Straal van een fabriek (size 1) in pixels, voor de schildring.
const BUILDING_RADIUS := 62.0

@onready var sprite: Sprite2D = find_child("*Sprite*", true, false) as Sprite2D


func _ready() -> void:
	# 1. DOELWIT REGISTRATIE
	add_to_group("targets")
	if not passive:
		add_to_group("saveable")  # deze fabriek wil onthouden worden (zie game_room.gd)
	# Hitbox passend bij de sprite (vóór de grootte uit de SSOT).
	SpriteFit.fit(self)
	# Levens van de fabriek uit de SSOT (rij unit_factory, plus de factie-modifier).
	# Staat dat er niet, dan telt Spawner Max Health uit de Inspector.
	spawner_max_health = EnemyStats.value(faction, building_type, "max_health", spawner_max_health)
	# Tempo uit de SSOT: base_spawn_rate = seconden tussen twee keer, base_spawn_amount = vijanden per keer.
	spawn_interval_seconds = maxf(0.2, EnemyStats.value(faction, building_type, "spawn_rate", spawn_interval_seconds))
	spawn_per_wave = maxi(1, roundi(EnemyStats.value(faction, building_type, "spawn_amount", spawn_per_wave)))
	spawner_current_health = spawner_max_health
	# Grootte uit de SSOT (base_size). Voor gebouwen telt die vanaf een fabriek: 1 = even groot als een fabriek.
	var building_size: float = EnemyStats.value(faction, building_type, "size", 1.0)
	_apply_size(building_size)
	shield = EnemyShield.create(self, faction, building_type, BUILDING_RADIUS * maxf(0.1, building_size) + 8.0)
	
	# Onzichtbaar tot we weten of dit object deze run al kapot is (anders zie je hem even flitsen).
	visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	
	if enemy_scene == null:
		var safe_path = "res://Entities/Objects/test_body.tscn"
		if ResourceLoader.exists(safe_path):
			enemy_scene = load(safe_path)
			
	if not is_inside_tree() or get_tree() == null: return
	active_scene = get_tree().current_scene
	
	room_key = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
	room_layer = LevelManager.current_layer
	room_index = LevelManager.current_room_index
	
	# GECORRIGEERD: De fabriek krijgt nu het unieke voorvoegsel 'Spawner_' 
	# Dit voorkomt dat hij dezelfde naam draagt als de eerste vijand!
	my_id = get_run_id()
	
	# Teken de fabriek op de ingestelde grootte.
	if is_instance_valid(sprite) and not is_equal_approx(sprite_scale, 1.0):
		sprite.scale = Vector2(sprite_scale, sprite_scale)
	
	# De kleur van de factie over de hele fabriek. De witte flits bij een treffer zit op de
	# sprite zelf, dus die blijft gewoon werken.
	modulate = EnemyStats.color(faction)
	
	# Testfabriek: niets terugzetten en geen vijanden maken.
	if passive:
		visible = true
		return
	
	# Is deze fabriek deze run al gesloopt? RunState weet het.
	var spawner_already_destroyed: bool = RunState.is_dead(room_layer, room_index, my_id)
		
	if spawner_already_destroyed:
		print("SPAWNER: Object ", my_id, " is permanent kapot. Node verwijderd.")
		queue_free()
		return
	visible = true
		
	# Stond deze fabriek er al toen je de kamer verliet? Zet dan zijn HP en zijn teller terug.
	# De grunts die nog leefden, zet de kamer zelf terug (zie game_room.gd).
	var saved: Dictionary = RunState.get_saved_unit(room_layer, room_index, my_id)
	var was_restored: bool = not saved.is_empty()
	if was_restored:
		apply_run_state(saved)
		print("RUNSTATE: ", my_id, " teruggezet met HP ", spawner_current_health, "/", spawner_max_health)
	
	if spawn_on_start and not was_restored:
		spawn_single_enemy()
		
	if total_enemies_to_spawn > 1 or total_enemies_to_spawn == -1:
		_setup_spawn_timer()


func _setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval_seconds
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	# Na het laden: ga verder met de tijd die er nog op de klok stond.
	if restored_timer_left > 0.0:
		spawn_timer.start(restored_timer_left)
		restored_timer_left = 0.0


# --- ONTHOUDEN: de drie functies voor de groep "saveable" ---

# De naam waaraan deze fabriek herkend wordt: gebaseerd op zijn plek in de kamer.
func get_run_id() -> String:
	return "Spawner_" + faction + "_" + spawn_unit_type + "_" + str(int(global_position.x)) + "_0_" + str(int(global_position.y)) + "_0"


# Wat deze fabriek wil bewaren.
func get_run_state() -> Dictionary:
	if is_destroyed:
		return {}  # kapot: niet bewaren, de dodenlijst regelt dat
	var timer_left: float = 0.0
	if is_instance_valid(spawn_timer):
		timer_left = spawn_timer.time_left
	return {
		"hp": spawner_current_health,
		"count": enemies_spawned_count,
		"timer_left": timer_left,
		"shield": shield.current if shield != null else 0.0,
	}


# Zet de bewaarde gegevens terug.
func apply_run_state(data: Dictionary) -> void:
	spawner_current_health = clampf(SaveSystem._safe_float(data.get("hp", spawner_max_health)), 1.0, spawner_max_health)
	if shield != null:
		shield.restore(SaveSystem._safe_float(data.get("shield", shield.max_value)))
	enemies_spawned_count = int(data.get("count", 0))
	restored_timer_left = float(data.get("timer_left", 0.0))


func _physics_process(delta: float) -> void:
	if shield != null and not is_destroyed:
		shield.update(delta)


func _on_spawn_timer_timeout() -> void:
	if is_destroyed: return
	# Na het laden liep de klok één keer korter. Zet hem terug op de normale tijd.
	if is_instance_valid(spawn_timer) and not is_equal_approx(spawn_timer.wait_time, spawn_interval_seconds):
		spawn_timer.start(spawn_interval_seconds)
	if total_enemies_to_spawn != -1 and enemies_spawned_count >= total_enemies_to_spawn:
		if is_instance_valid(spawn_timer): spawn_timer.stop()
		return
	for _i in spawn_per_wave:
		spawn_single_enemy()


func spawn_single_enemy() -> void:
	if is_destroyed or not enemy_scene or not is_instance_valid(active_scene): return
	
	var inst = enemy_scene.instantiate()
	
	# GECORRIGEERD: De grunts behouden de pure 'Enemy_' prefix voor de SSoT database!
	var enemy_base_name = "Enemy_" + faction + "_" + spawn_unit_type + "_" + str(int(global_position.x)) + "_0_" + str(int(global_position.y)) + "_0"
	
	if total_enemies_to_spawn == 1:
		inst.name = enemy_base_name
	else:
		# Sla de vijanden over die deze run al gedood zijn, zodat de fabriek verdergaat waar hij was.
		while RunState.is_dead(room_layer, room_index, enemy_base_name + "_" + str(enemies_spawned_count)):
			enemies_spawned_count += 1
		if total_enemies_to_spawn != -1 and enemies_spawned_count >= total_enemies_to_spawn:
			inst.free()
			return
		inst.name = enemy_base_name + "_" + str(enemies_spawned_count)
		
	# Geef factie en type mee, VOORDAT de vijand in de kamer komt. Zo laadt hij meteen
	# de juiste waarden.
	if "faction" in inst:
		inst.faction = faction
	if "unit_type" in inst:
		inst.unit_type = spawn_unit_type
	# Eeuwige fabriek: de hoeveelste unit dit is, voor minder loot per unit (loot_factory_falloff).
	if total_enemies_to_spawn == -1 and "factory_order" in inst:
		inst.factory_order = enemies_spawned_count
	
	inst.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(20, 40))
	active_scene.add_child(inst)
	
	inst.add_to_group("targets")
	inst.add_to_group("enemies")
	enemies_spawned_count += 1


## Schade die de speler krijgt als hij tegen dit gebouw aan vliegt (base_damage). Leeg = 10.
func get_contact_damage() -> float:
	return maxf(0.0, EnemyStats.value(faction, building_type, "damage", 10.0))


# --- SCHADE OPVANGEN EN PERMANENTE VERNIETIGING ---
func take_damage(amount: int, flash: bool = true, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if is_destroyed or spawner_current_health <= 0: return
	DamageCalc.take_hit_by(self)  # wie raakte (andere factie) is voor een fabriek niet nodig; opruimen
	if hit_dir != Vector2.ZERO:
		last_hit_dir = hit_dir
	
	var through: float = float(amount)
	if shield != null:
		through = shield.absorb(through, DamageCalc.shield_factor_for(self))
	spawner_current_health = max(0, spawner_current_health - through)
	
	# Arcade flits-effect op de fabriek zelf
	if flash and sprite:
		sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
		await get_tree().create_timer(0.055, false).timeout
		sprite.modulate = Color.WHITE
		
	if spawner_current_health <= 0:
		is_destroyed = true
		call_deferred("_deferred_destruction")


func _deferred_death(_hit_dir: Vector2) -> void:
	# Fallback: Mocht een kogel per ongeluk _deferred_death aanroepen in plaats van take_damage
	take_damage(999, false)


# GECORRIGEERD: Smijt de spawner direct uit de groepen zodat de barrières direct openvliegen!
func _deferred_destruction() -> void:
	print("SPAWNER: ", my_id, " is volledig BESCHOTEN en VERNIETIGD!")
	
	# BINGO: Haal de node direct administratief uit de groepen. 
	# Hierdoor ziet game_room.gd per direct 0 vijanden en zakken de muren direct in!
	if is_in_group("targets"): remove_from_group("targets")
	if is_in_group("enemies"): remove_from_group("enemies")
	
	# Onthoud in RunState dat deze fabriek kapot is (een testfabriek niet).
	if not passive:
		RunState.mark_dead(room_layer, room_index, my_id)
	print("SPAWNER: Destructie onthouden in RunState.")
				
	if is_instance_valid(spawn_timer):
		spawn_timer.stop()
	
	# Loot uit de SSOT (rij unit_factory): soort, aantal en splatter. Standaard Metal.
	var count: int = LootDrops.roll_count(faction, building_type)
	var resource: String = LootDrops.resource_id(faction, building_type, "metal")
	if is_instance_valid(active_scene):
		LootDrops.spawn(active_scene, global_position, last_hit_dir, count, resource, LootDrops.splatter_settings(faction, building_type))
		LootDrops.spawn_faction_loot(active_scene, global_position, last_hit_dir, faction, building_type, LootDrops.splatter_settings(faction, building_type))
		LootDrops.spawn_bonus_loot(active_scene, global_position, last_hit_dir, faction, building_type, LootDrops.splatter_settings(faction, building_type))
		print("SPAWNER: ", my_id, " laat ", count, " blokjes vallen.")
		
	# Wis de node nu veilig aan de start van het volgende frame
	queue_free()


# Maakt het gebouw groter of kleiner. We schalen de onderdelen (sprite, botsvorm) en niet het
# gebouw zelf, want Godot rekent niet goed met een geschaald physics-lichaam (net als test_body.gd).
func _apply_size(size: float) -> void:
	if size <= 0.0 or is_equal_approx(size, 1.0) or has_meta("size_applied"):
		return
	set_meta("size_applied", true)
	for child in get_children():
		if child is Node2D:
			child.scale *= size
