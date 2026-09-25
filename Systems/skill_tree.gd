extends Control
# BEDIENING: SSoT Skill Tree Manager (Volledig hersteld conform jullie Git-architectuur)

var current_meta: MetaProgress = null

# Bepaalt hoeveel levels er per klik worden gekocht (1 of 10)
var buy_amount: int = 1

# --- CAMERA & CONTAINERS ---
@onready var tree_camera: Camera2D = $TreeCamera
@onready var skill_slots_container: Node = $Skill_Slots
@onready var skill_lines_container: Node = $Skill_Lines
@onready var back_button: Button = find_child("back_to_main_menu", true, false) as Button

# --- CAMERA ZOOM & PAN INSTELLINGEN ---
var min_zoom: float = 0.5
var max_zoom: float = 2.0
var zoom_speed: float = 0.1
var is_dragging: bool = false


func _ready() -> void:
	get_viewport().gui_release_focus()
	
	# Laad de meta-progressie in via het SaveSystem
	var save_system = load("res://Systems/SaveSystem.gd").new()
	if save_system and save_system.has_method("get_loaded_meta_progress"):
		current_meta = save_system.get_loaded_meta_progress()
		
	if not current_meta:
		current_meta = MetaProgress.new()
	
	setup_slot_anchors()
	
	# Centreer de camera netjes in het midden bij opstarten
	if is_instance_valid(tree_camera):
		tree_camera.global_position = Vector2(960, 540)
	
	# Handmatige signaalkoppeling voor de terugknop
	if is_instance_valid(back_button):
		if not back_button.pressed.is_connected(_on_back_to_main_menu_pressed):
			back_button.pressed.connect(_on_back_to_main_menu_pressed)
	
	# Dynamische signaalkoppeling voor de klik-knoppen van álle slots in de map
	if is_instance_valid(skill_slots_container):
		for slot in skill_slots_container.get_children():
			var button = slot.find_child("*Button*", true, false)
			var bar = slot.find_child("*Bar*", true, false)
			if bar: bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if button and not button.pressed.is_connected(_on_any_skill_button_pressed):
				button.pressed.connect(_on_any_skill_button_pressed.bind(slot.name))
				
	await get_tree().process_frame
	update_skill_tree_visuals()


func setup_slot_anchors() -> void:
	pass


# =========================================================================
# --- INTERACTIEVE CAMERA BESTURING (ZOOM & PAN VIA RECHTERMUISKNOP) ---
# =========================================================================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		_on_back_to_main_menu_pressed()
		return

	# 1. SLEEP DE KAART MET DE RECHTERMUISKNOP
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_dragging = event.pressed
			
	if event is InputEventMouseMotion and is_dragging and is_instance_valid(tree_camera):
		# GECORRIGEERD: We delen door de float .x om vector-crashes te voorkomen!
		tree_camera.global_position -= event.relative / tree_camera.zoom.x
		
	# 2. ZOOM IN EN UIT MET HET MUISWIEL
	if event is InputEventMouseButton and event.is_pressed():
		var current_zoom = tree_camera.zoom.x
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_zoom = clamp(current_zoom + zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_zoom = clamp(current_zoom - zoom_speed, min_zoom, max_zoom)
		tree_camera.zoom = Vector2(current_zoom, current_zoom)


# =========================================================================
# --- DYNAMISCHE DUAL-MODUS KOOP EN SPENDERINGS AFHANDELING ---
# =========================================================================
func _on_any_skill_button_pressed(slot_name: String) -> void:
	if not current_meta or not is_instance_valid(skill_slots_container): return
	
	var slot_node = skill_slots_container.find_child(slot_name, true, false)
	if not slot_node: return
	
	# Haal de sub-dictionary veilig op conform jullie Git goudstand
	var current_data = current_meta.skills_data.get(slot_name, {"level": 0, "currency_type": 1})
	var current_level = int(current_data["level"])
	
	if current_level >= 100: return
	
	# Haal de dynamische prijs en valuta op uit de Inspector van het slot
	var cost: int = slot_node.cost_per_click if "cost_per_click" in slot_node else 1
	# Godot enums beginnen bij 0, de database telt vanaf 1
	var c_type: int = slot_node.currency_type + 1 if "currency_type" in slot_node else 1
	
	# Bepaal de bulk-afname op basis van buy_amount (+1 of +10)
	var actual_buy_qty = buy_amount
	if current_level + actual_buy_qty > 100:
		actual_buy_qty = 100 - current_level
	if actual_buy_qty <= 0: return
	
	var total_bulk_cost = cost * actual_buy_qty
	var can_afford: bool = false
	
	# SSoT INTEGRATIE: Trek de kosten type-veilig af van de actieve Meta Wallet
	if c_type == 1 and current_meta.currency_1 >= total_bulk_cost:
		current_meta.currency_1 -= total_bulk_cost
		can_afford = true
	elif c_type == 2 and current_meta.currency_2 >= total_bulk_cost:
		current_meta.currency_2 -= total_bulk_cost
		can_afford = true
	elif c_type == 3 and current_meta.currency_3 >= total_bulk_cost:
		current_meta.currency_3 -= total_bulk_cost
		can_afford = true
	elif c_type == 4 and current_meta.currency_4 >= total_bulk_cost:
		current_meta.currency_4 -= total_bulk_cost
		can_afford = true
	elif c_type == 5 and current_meta.currency_5 >= total_bulk_cost:
		current_meta.currency_5 -= total_bulk_cost
		can_afford = true
	elif c_type == 6 and current_meta.currency_6 >= total_bulk_cost:
		current_meta.currency_6 -= total_bulk_cost
		can_afford = true
		
	if can_afford:
		current_meta.skills_data[slot_name]["level"] = current_level + actual_buy_qty
		print("SKILL TREE: Succesvol gekocht! ", slot_name, " level is nu: ", current_meta.skills_data[slot_name]["level"])
		
		var save_system = load("res://Systems/SaveSystem.gd").new()
		if save_system and save_system.has_method("save_meta_progress"):
			save_system.save_meta_progress(current_meta)
			
		update_skill_tree_visuals()


# =========================================================================
# --- VISUELE SYNC EN TRAP-BOCHTEN DRAW UPDATE LOOP ---
# =========================================================================
func update_skill_tree_visuals() -> void:
	if not current_meta or not is_instance_valid(skill_slots_container): return
	
	# Wis alle oude haakse verbindingslijnen voor de herberekening
	if is_instance_valid(skill_lines_container):
		for line in skill_lines_container.get_children():
			if line is Line2D:
				line.clear_points()
				line.visible = false
				
	var line_index: int = 0
	var all_slots = skill_slots_container.get_children()
	
	# Database controle & initialisatie via de Inspector-waarden
	for slot in all_slots:
		var c_type: int = 1
		var loss_rate: int = 1
		if "currency_type" in slot: c_type = slot.currency_type + 1
		if "points_lost_per_minute" in slot: loss_rate = slot.points_lost_per_minute
			
		if not current_meta.skills_data.has(slot.name) or not (current_meta.skills_data[slot.name] is Dictionary):
			current_meta.skills_data[slot.name] = {
				"level": 0, 
				"currency_type": c_type,
				"loss_per_minute": loss_rate
			}
		else:
			current_meta.skills_data[slot.name]["currency_type"] = c_type
			current_meta.skills_data[slot.name]["loss_per_minute"] = loss_rate

	# Universele check van de stamboom (Zorgt voor zichtbaarheids-resets en lijnen)
	for slot in all_slots:
		var bar = slot.find_child("*Bar*", true, false)
		var button = slot.find_child("*Button*", true, false)
		var level = int(current_meta.skills_data[slot.name]["level"])
		
		# Controleer of dit slot een ouder-slot heeft waaraan hij vastgeketend zit
		var parent_node = slot.get("parent_skill_slot") if "parent_skill_slot" in slot else null
		
		if is_instance_valid(parent_node):
			var parent_level: int = 0
			if current_meta.skills_data.has(parent_node.name):
				parent_level = int(current_meta.skills_data[parent_node.name]["level"])
			
			if parent_level > 0:
				slot.visible = true
				_apply_skill_visual_rules(bar, button, level, slot.name)
				if is_instance_valid(skill_lines_container) and line_index < skill_lines_container.get_child_count():
					draw_line_between(skill_lines_container.get_child(line_index), parent_node, slot)
					line_index += 1
			else:
				slot.visible = false
		else:
			# Slots zonder parent zijn de start-skills; die staan altijd aan!
			slot.visible = true
			_apply_skill_visual_rules(bar, button, level, slot.name)


# --- RECHTSTREEKSE VERTALING VAN JULLIE INTERNE INKLEURINGS-LOGICA ---
func _apply_skill_visual_rules(bar: ProgressBar, button: Button, level: int, slot_name: String) -> void:
	if not is_instance_valid(bar) or not is_instance_valid(button): return
	bar.value = level
	
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	bg.set_border_width_all(0)
	bar.add_theme_stylebox_override("background", bg)
	
	var sb = StyleBoxFlat.new()
	sb.set_border_width_all(0)
	sb.anti_aliasing = false
	
	if level <= 0:
		sb.bg_color = Color.RED
		button.text = slot_name + " (0/100)"
	elif level <= 25:
		sb.bg_color = Color.ORANGE
		button.text = slot_name + " (" + str(level) + "/100)"
	elif level <= 50:
		sb.bg_color = Color.YELLOW
		button.text = slot_name + " (" + str(level) + "/100)"
	elif level <= 75:
		sb.bg_color = Color.GREEN
		button.text = slot_name + " (" + str(level) + "/100)"
	else:
		sb.bg_color = Color.DODGER_BLUE
		button.text = "MAXIMAAL! (100/100)"
		
	bar.add_theme_stylebox_override("fill", sb)


# --- JULLIE RECHTSTREEKSE HAAKSE Z-VORM TRAP-BOCHTEN BEREKENING ---
func draw_line_between(line: Line2D, parent_slot: Control, child_slot: Control) -> void:
	if not line or not parent_slot or not child_slot: return
	
	var p_bar = parent_slot.find_child("*Bar*", true, false)
	var c_bar = child_slot.find_child("*Bar*", true, false)
	
	if p_bar and c_bar:
		line.clear_points()
		line.visible = true
		line.default_color = Color.GOLD
		line.z_index = -1 # Dwingt de goudlijn ALTIJD achter de vakjes te zakken!
		
		# Omrekening naar lokale coördinaten voor de Line2D node
		var start_pos: Vector2 = line.to_local(p_bar.global_position + Vector2(p_bar.size.x / 2, p_bar.size.y - 3))
		var end_pos: Vector2 = line.to_local(c_bar.global_position + Vector2(c_bar.size.x / 2, 3))
		
		# Bereken de perfecte haakse trap-bocht (Z-vorm)
		var mid_y: float = start_pos.y + ((end_pos.y - start_pos.y) / 2)
		var knik_1: Vector2 = Vector2(start_pos.x, mid_y)
		var knik_2: Vector2 = Vector2(end_pos.x, mid_y)
		
		# Voeg de vier hoekpunten op volgorde toe aan de Line2D
		line.add_point(start_pos)
		line.add_point(knik_1)
		line.add_point(knik_2)
		line.add_point(end_pos)

# GECORRIGEERD: De naam klopt nu 1-op-1 met de signaalkoppeling op regel 41 en 42!
func _on_back_to_main_menu_pressed() -> void:
	print("SKILL TREE: Terugkeren naar het hoofdmenu...")
	var save_system = load("res://Systems/SaveSystem.gd").new()
	if save_system and current_meta:
		save_system.save_meta_progress(current_meta)
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
