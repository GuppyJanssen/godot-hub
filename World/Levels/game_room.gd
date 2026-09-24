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


func _ready() -> void:
	print("GAMEROOM: Universele kamer online. Start initialisatie...")
	
	# 1. TIMING: Wacht twee frames tot de LevelManager stabiel staat
	await get_tree().process_frame
	await get_tree().process_frame
	
	var active_layer = LevelManager.current_layer
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
					"res://Sprites Models/Backgrounds/desert.png",
					"res://Sprites Models/Backgrounds/ice.png",
					"res://Sprites Models/Backgrounds/jungle.png",
					"res://Sprites Models/Backgrounds/rocky.png"
				]
				target_tex_path = south_pole_backgrounds.pick_random()
				
				# Sla deze keuze direct permanent op in de LevelManager voor de rest van de run
				if is_instance_valid(LevelManager):
					LevelManager.set_meta("active_run_background", target_tex_path)
					print("GAMEROOM: Nieuwe run-achtergrond éénmalig gekozen en vergrendeld: ", target_tex_path)
					
		elif active_layer == max_layer_index:
			target_tex_path = "res://Sprites Models/Backgrounds/hell.png"
			
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
				
	_check_barriers()

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
	
	var current_layer = LevelManager.current_layer
	var max_layer_index = LevelManager.LAYER_WIDTHS.size() - 1
	
	var save_system_script = load("res://Systems/SaveSystem.gd")
	var save_instance = save_system_script.new() if save_system_script else null
	
	# NOORD-TRANSITIE (Up)
	if active_player.global_position.y < 25.0:
		if current_layer < max_layer_index:
			LevelManager.set_meta("coming_from", "down")
			LevelManager.set_meta("player_exit_x", active_player.global_position.x)
			LevelManager.current_layer += 1
			LevelManager.current_room_index = 0
			if save_instance and save_instance.has_method("save_current_run"): save_instance.save_current_run(active_player)
			get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")
			return
			
	# ZUID-TRANSITIE (Down)
	elif active_player.global_position.y > 1055.0:
		if current_layer > 0:
			LevelManager.set_meta("coming_from", "up")
			LevelManager.set_meta("player_exit_x", active_player.global_position.x)
			LevelManager.current_layer -= 1
			LevelManager.current_room_index = 0
			if save_instance and save_instance.has_method("save_current_run"): save_instance.save_current_run(active_player)
			get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")
			return

	# HORIZONTALE TRANSITIES (Links / Rechts)
	if current_layer > 0 and current_layer < max_layer_index:
		if active_player.global_position.x < 15.0:
			LevelManager.set_meta("coming_from", "right")
			LevelManager.set_meta("player_exit_y", active_player.global_position.y)
			LevelManager.current_room_index -= 1
			if LevelManager.current_room_index < 0:
				LevelManager.current_room_index = LevelManager.LAYER_WIDTHS[current_layer] - 1
			get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")
			return
		elif active_player.global_position.x > screen_width - 15.0:
			LevelManager.set_meta("coming_from", "left")
			LevelManager.set_meta("player_exit_y", active_player.global_position.y)
			LevelManager.current_room_index += 1
			if LevelManager.current_room_index >= LevelManager.LAYER_WIDTHS[current_layer]:
				LevelManager.current_room_index = 0
			get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")
			return
