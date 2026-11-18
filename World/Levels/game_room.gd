extends Node2D
# SSoT UNIVERSELE ARENA-REGISSEUR: Achtergrond-, Waarschuwings- & Toggle-Spawns Hersteld

@onready var background_node = $Background if has_node("Background") else null

# GLOBALE SCRIPT-VARIABELEN (Schoon opgelijnd zonder shadowing!)
var screen_width: float = 1920.0
var screen_height: float = 1080.0
var edge_margin: float = 35.0
var active_player: CharacterBody2D = null

# Startposities voor de barrières
var top_b_start_pos: Vector2 = Vector2.ZERO
var bot_b_start_pos: Vector2 = Vector2.ZERO
var left_b_start_pos: Vector2 = Vector2.ZERO
var right_b_start_pos: Vector2 = Vector2.ZERO

# Referenties voor de nodes zelf
var top_b: Node = null
var bot_b: Node = null
var left_b: Node = null
var right_b: Node = null
var initialization_complete: bool = false

# Welke ring en kamer dit is. Wordt bij het laden vastgelegd, zodat het blijft kloppen
# als de LevelManager bij een kamerwissel al naar de volgende kamer wijst.
var my_layer: int = 0
var my_room: int = 0
var room_ready: bool = false


func _ready() -> void:
	print("GAMEROOM: Universele kamer online. Start initialisatie...")
	
	# De balken zijn onzichtbaar tot we weten of er vijanden zijn. Anders flitsen ze even
	# op in een kamer die al leeg is (de controle hieronder komt pas na twee frames).
	var barrier_visuals: Node = get_node_or_null("BarrierVisuals")
	if barrier_visuals is CanvasItem:
		barrier_visuals.visible = false
	
	# 1. TIMING: Wacht twee frames tot de LevelManager stabiel staat
	await get_tree().process_frame
	await get_tree().process_frame
	
	var active_layer = LevelManager.current_layer
	my_layer = active_layer
	my_room = LevelManager.current_room_index
	var max_layer_index = LevelManager.LAYER_WIDTHS.size() - 1
	print("GAMEROOM: Initialisatie compleet. Actieve Ring: ", active_layer)
	
	# 2. RUN-VASTE ACHTERGROND SELECTIE (Onthoudt de keuze voor de héle run!)
	if is_instance_valid(background_node) and background_node is TextureRect:
		var target_tex_path: String = ""
		
		if active_layer == 0:
			# Check of de LevelManager tijdens deze run AL EERDER een achtergrond heeft gekozen
			if is_instance_valid(LevelManager) and LevelManager.has_meta("active_run_background"):
				target_tex_path = LevelManager.get_meta("active_run_background")
				print("GAMEROOM: Bestaande run-achtergrond hersteld uit geheugen: ", target_tex_path)
			else:
				# Eerste keer in deze run: kies nu éénmalig een willekeurige achtergrond uit jullie map!
				var south_pole_backgrounds: Array[String] = [
					"res://Sprites Models/Backgrounds/desert.jpg",
					"res://Sprites Models/Backgrounds/ice.jpg",
					"res://Sprites Models/Backgrounds/jungle.jpg",
					"res://Sprites Models/Backgrounds/rocky.jpg"
				]
				target_tex_path = south_pole_backgrounds.pick_random()
				
				# Sla deze keuze direct permanent op in de LevelManager voor de rest van de run
				if is_instance_valid(LevelManager):
					LevelManager.set_meta("active_run_background", target_tex_path)
					print("GAMEROOM: Nieuwe run-achtergrond éénmalig gekozen en vergrendeld: ", target_tex_path)
					
		elif active_layer == max_layer_index:
			target_tex_path = "res://Sprites Models/Backgrounds/hell.jpg"
			
		if target_tex_path != "":
			if not ResourceLoader.exists(target_tex_path):
				var fallback_path = target_tex_path.replace(".png", ".jpg")
				if ResourceLoader.exists(fallback_path):
					target_tex_path = fallback_path
					
			if ResourceLoader.exists(target_tex_path):
				background_node.texture = load(target_tex_path)

	# 3. ÉÉNMALIGE NODE INDEXATIE FOR BARRIERS
	for child in find_children("*", "", true, false):
		if is_instance_valid(child):
			if child.name.to_lower().ends_with("topbarrier"): top_b = child
			elif child.name.to_lower().ends_with("bottombarrier"): bot_b = child
			elif child.name.to_lower().ends_with("leftbarrier"): left_b = child
			elif child.name.to_lower().ends_with("rightbarrier"): right_b = child
			
	if top_b and bot_b and left_b and right_b:
		top_b_start_pos = top_b.position
		bot_b_start_pos = bot_b.position
		left_b_start_pos = left_b.position
		right_b_start_pos = right_b.position
		initialization_complete = true

	# 4. DATA-HERSTEL VIA SCHIJF
	var root_node = get_tree().root
	active_player = root_node.find_child("Player", true, false) as CharacterBody2D
	
	if is_instance_valid(active_player):
		var save_system_script = load("res://Systems/SaveSystem.gd")
		if save_system_script:
			var save_instance = save_system_script.new()
			if save_instance and save_instance.has_method("load_current_run"):
				save_instance.load_current_run(active_player)
			# Het losse SaveSystem is klaar: opruimen, anders blijft het in het geheugen hangen.
			if save_instance:
				save_instance.free()
				
	# Fabrieken neerzetten: wie er zit komt uit de factie-oorlog, waar ze staan uit de seed.
	# Eerst dit, dan pas terugzetten: bestaande fabrieken halen hun gegevens zelf op.
	var factory_parent: Node = get_node_or_null("Body's/spawner")
	RoomPopulator.populate(factory_parent if factory_parent != null else self, my_layer, my_room)

	# Leg de loot en de vijanden terug zoals ze waren toen je deze kamer verliet.
	_restore_room()
	
	_check_barriers()
	# Nu staan de balken goed (open of dicht): laat ze zien.
	if barrier_visuals is CanvasItem:
		barrier_visuals.visible = true

	# 5. TOGGLE-AFHANKELIJKE RANDSPAWN
	if is_instance_valid(active_player) and LevelManager.has_meta("coming_from"):
		var direction = LevelManager.get_meta("coming_from")
		var exit_x = LevelManager.get_meta("player_exit_x") if LevelManager.has_meta("player_exit_x") else 960.0
		var exit_y = LevelManager.get_meta("player_exit_y") if LevelManager.has_meta("player_exit_y") else 540.0
		
		if not Game.debug_use_mirror_spawn:
			exit_x = 960.0
			exit_y = 540.0
		
		match direction:
			"down": active_player.global_position = Vector2(exit_x, screen_height - edge_margin)
			"up": active_player.global_position = Vector2(exit_x, edge_margin)
			"right": active_player.global_position = Vector2(screen_width - edge_margin, exit_y)
			"left": active_player.global_position = Vector2(edge_margin, exit_y)
		LevelManager.remove_meta("coming_from")


func _process(_delta: float) -> void:
	if not initialization_complete or not is_inside_tree(): return
	_check_barriers()
	_check_software_transitions()


func _check_barriers() -> void:
	var current_layer = LevelManager.current_layer
	var max_layer_index = LevelManager.LAYER_WIDTHS.size() - 1
	
	# Weer terug naar de basis: telt puur de targets en enemies!
	var enemies = get_tree().get_nodes_in_group("targets").size() + get_tree().get_nodes_in_group("enemies").size()
	var enemies_alive: bool = enemies > 0
	
	if current_layer == 0:
		_move_barrier_state(bot_b, bot_b_start_pos, true, false)
		_move_barrier_state(left_b, left_b_start_pos, false, false)
		_move_barrier_state(right_b, right_b_start_pos, false, false)
		_move_barrier_state(top_b, top_b_start_pos, enemies_alive, enemies_alive)
	elif current_layer == max_layer_index:
		_move_barrier_state(top_b, top_b_start_pos, true, false)
		_move_barrier_state(bot_b, bot_b_start_pos, enemies_alive, enemies_alive)
		_move_barrier_state(left_b, left_b_start_pos, enemies_alive, enemies_alive)
		_move_barrier_state(right_b, right_b_start_pos, enemies_alive, enemies_alive)
	else:
		_move_barrier_state(top_b, top_b_start_pos, enemies_alive, enemies_alive)
		_move_barrier_state(bot_b, bot_b_start_pos, enemies_alive, enemies_alive)
		_move_barrier_state(left_b, left_b_start_pos, enemies_alive, enemies_alive)
		_move_barrier_state(right_b, right_b_start_pos, enemies_alive, enemies_alive)


func _move_barrier_state(barrier_node: Node, start_pos: Vector2, keep_closed: bool, show_visual: bool) -> void:
	if not is_instance_valid(barrier_node): return
	barrier_node.visible = true
	if "color" in barrier_node:
		barrier_node.color.a = 1.0 if show_visual else 0.0
	barrier_node.modulate.a = 1.0 if show_visual else (0.0 if not keep_closed else 1.0)
	
	if "position" in barrier_node:
		var target_pos = start_pos if keep_closed else Vector2(-5000, -5000)
		if barrier_node.position != target_pos:
			barrier_node.position = target_pos


func _check_software_transitions() -> void:
	if not is_instance_valid(active_player): return
	
	var enemies = get_tree().get_nodes_in_group("targets").size() + get_tree().get_nodes_in_group("enemies").size()
	if enemies > 0: return 
	
	# Geen vijanden meer: deze kamer is gehaald. RunState onthoudt dat.
	RunState.mark_cleared(LevelManager.current_layer, LevelManager.current_room_index)
	# De factie-oorlog hoort dat de speler deze kamer heeft leeggemaakt.
	var war: Node = get_node_or_null("/root/FactionWar")
	if war != null:
		war.on_room_cleared(LevelManager.current_layer, LevelManager.current_room_index)
	
	var current_layer = LevelManager.current_layer
	var max_layer_index = LevelManager.LAYER_WIDTHS.size() - 1
	
	
	# NOORD-TRANSITIE (Up)
	if active_player.global_position.y < 25.0:
		if current_layer < max_layer_index:
			LevelManager.set_meta("coming_from", "down")
			LevelManager.set_meta("player_exit_x", active_player.global_position.x)
			LevelManager.current_layer += 1
			LevelManager.current_room_index = _room_index_after_ring_change(current_layer, LevelManager.current_layer)
			_save_before_transition()
			get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")
			return
			
	# ZUID-TRANSITIE (Down)
	elif active_player.global_position.y > 1055.0:
		if current_layer > 0:
			LevelManager.set_meta("coming_from", "up")
			LevelManager.set_meta("player_exit_x", active_player.global_position.x)
			LevelManager.current_layer -= 1
			LevelManager.current_room_index = _room_index_after_ring_change(current_layer, LevelManager.current_layer)
			_save_before_transition()
			get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")
			return

	# GECORRIGEERD: Horizontale transities slaan NU ook de run-winst en stats op via het SaveSystem!
	# Dit voorkomt dat je winst-tellers leeglopen zodra je zijwaarts door een poort vliegt.
	if current_layer > 0 and current_layer < max_layer_index:
		# LINKS-TRANSITIE
		if active_player.global_position.x < 15.0:
			LevelManager.set_meta("coming_from", "right")
			LevelManager.set_meta("player_exit_y", active_player.global_position.y)
			LevelManager.current_room_index -= 1
			if LevelManager.current_room_index < 0:
				LevelManager.current_room_index = LevelManager.LAYER_WIDTHS[current_layer] - 1
				
			# SSoT GUARD: Schrijf de live status en winst NU naar de schijf voordat de scene wisselt!
			_save_before_transition()
				
			get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")
			return
			
		# RECHTS-TRANSITIE
		elif active_player.global_position.x > screen_width - 15.0:
			LevelManager.set_meta("coming_from", "left")
			LevelManager.set_meta("player_exit_y", active_player.global_position.y)
			LevelManager.current_room_index += 1
			if LevelManager.current_room_index >= LevelManager.LAYER_WIDTHS[current_layer]:
				LevelManager.current_room_index = 0
				
			# SSoT GUARD: Schrijf de live status en winst NU naar de schijf voordat de scene wisselt!
			_save_before_transition()
				
			get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")
			return


# Rekent uit in welke kamer je uitkomt als je naar een andere ring gaat.
# - Bredere ring (twee keer zoveel kamers): boven elke kamer liggen er twee. Vlieg je in de
#   linkerhelft van het scherm naar buiten, dan kom je in de linker uit, anders in de rechter.
# - Smallere ring: twee kamers komen samen in één.
# Rekenregel voor de kamer na een ringwissel (bredere ring: x2, smallere ring: /2).
func _room_index_after_ring_change(from_layer: int, to_layer: int) -> int:
	var from_width: int = LevelManager.LAYER_WIDTHS[from_layer]
	var to_width: int = LevelManager.LAYER_WIDTHS[to_layer]
	var index: int = LevelManager.current_room_index
	
	if to_width > from_width:
		var in_right_half: bool = active_player.global_position.x >= screen_width / 2.0
		index = index * 2 + (1 if in_right_half else 0)
	elif to_width < from_width:
		index = floori(index / 2.0)
	
	return clampi(index, 0, to_width - 1)


# Slaat alles op vlak voor een kamerwissel. Wordt aangeroepen NADAT de LevelManager
# al op de nieuwe ring en kamer staat.
func _save_before_transition() -> void:
	# Eerst vastleggen wat er in DEZE kamer achterblijft (loot, levende vijanden).
	snapshot_room(true)
	
	# Bestaande save (positie, HP, schade aan vijanden die nog leven).
	var save_instance = load("res://Systems/SaveSystem.gd").new()
	save_instance.save_current_run(active_player)
	save_instance.free()
	
	# RunState: dode vijanden, gehaalde kamers en speeltijd.
	RunState.ring = LevelManager.current_layer
	RunState.room = LevelManager.current_room_index
	RunState.save()


# ============================================================================
# KAMER ONTHOUDEN
#
# De kamer weet NIET wat voor objecten er zijn. Elk object dat onthouden wil worden:
#   1. meldt zich aan in de groep "saveable" (in zijn _ready)
#   2. heeft drie functies:
#        get_run_id()          -> een naam die uniek is binnen de kamer
#        get_run_state()       -> een Dictionary met wat het wil bewaren ({} = sla mij over)
#        apply_run_state(data) -> zet die gegevens weer terug
#
# Een nieuw soort object (asteroïde, wrak, NPC) onthouden = die drie functies in zijn
# eigen script. Aan deze kamer en aan RunState hoeft dan niets te veranderen.
#
# Extra groep "save_only_on_quit": objecten die alleen bewaard worden bij "terug naar
# hoofdmenu", niet bij een kamerwissel (bijvoorbeeld kogels).
# ============================================================================

# Maakt een momentopname van alles in de groep "saveable" en geeft die aan RunState.
# leaving_room = true bij een kamerwissel, false bij "terug naar hoofdmenu".
func snapshot_room(leaving_room: bool = false) -> void:
	if not room_ready:
		return
	
	var units: Dictionary = {}
	for node in get_tree().get_nodes_in_group("saveable"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if leaving_room and node.is_in_group("save_only_on_quit"):
			continue
		if not node.has_method("get_run_id") or not node.has_method("get_run_state"):
			continue
		# Bij een kamerwissel loopt de tijd in deze kamer "door": objecten die nog bewegen
		# (loot met vaart) springen naar de plek waar ze tot stilstand waren gekomen.
		if leaving_room and node.has_method("settle_for_room_exit"):
			node.settle_for_room_exit()
		
		var data: Dictionary = node.get_run_state()
		if data.is_empty():
			continue
		# De scene waar het object uit komt, zodat de kamer het opnieuw kan neerzetten.
		if not data.has("scene"):
			data["scene"] = node.scene_file_path
		data["name"] = str(node.name)
		units[str(node.get_run_id())] = data
	
	RunState.save_room_snapshot(my_layer, my_room, units)


# Zet terug wat er bij de laatste momentopname was en nu niet in de kamer staat
# (loot, vijanden uit een fabriek, later kogels). Objecten die vast in de kamer staan,
# halen hun gegevens zelf op in hun eigen _ready.
func _restore_room() -> void:
	# Wat staat er al in de kamer?
	var present: Dictionary = {}
	for node in get_tree().get_nodes_in_group("saveable"):
		if is_instance_valid(node) and node.has_method("get_run_id"):
			present[str(node.get_run_id())] = true
	
	var units: Dictionary = RunState.get_saved_units(my_layer, my_room)
	for unit_id in units:
		var data = units[unit_id]
		if not data is Dictionary:
			continue
		if present.has(str(unit_id)):
			continue  # staat er al en zet zichzelf terug
		if RunState.is_dead(my_layer, my_room, str(unit_id)):
			continue
		
		var scene_path: String = str(data.get("scene", ""))
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			print("KAMER: kan ", unit_id, " niet terugzetten, scene onbekend: '", scene_path, "'")
			continue
		
		var inst = load(scene_path).instantiate()
		# Sommige objecten (vijanden) worden aan hun naam herkend en moeten die terugkrijgen.
		if data.get("keep_name", false):
			inst.name = str(data.get("name", inst.name))
		add_child(inst)
		if inst.has_method("apply_run_state"):
			inst.apply_run_state(data)
	
	room_ready = true
