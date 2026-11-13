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
#skill pop up info
@onready var skill_popup: PanelContainer = find_child("SkillPopup", true, false) as PanelContainer
@onready var popup_title: Label = find_child("PopupTitle", true, false) as Label
@onready var popup_description: Label = find_child("PopupDescription", true, false) as Label


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
	# Dynamische signaalkoppeling voor de klik- EN hover-knoppen van álle slots
	if is_instance_valid(skill_slots_container):
		for slot in skill_slots_container.get_children():
			var button = slot.find_child("*Button*", true, false) as Button
			var bar = slot.find_child("*Bar*", true, false)
			if bar: bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			if button:
				var s_id = slot.skill_id if "skill_id" in slot else slot.name
				
				# Bestaande klik-koppeling
				if not button.pressed.is_connected(_on_any_skill_button_pressed):
					button.pressed.connect(_on_any_skill_button_pressed.bind(s_id))
				
				# NIEUW: Koppel mouse_entered en mouse_exited voor het popup-scherm!
				if not button.mouse_entered.is_connected(_on_skill_button_hover_entered):
					button.mouse_entered.connect(_on_skill_button_hover_entered.bind(s_id))
				if not button.mouse_exited.is_connected(_on_skill_button_hover_exited):
					button.mouse_exited.connect(_on_skill_button_hover_exited)
				
	await get_tree().process_frame
	update_skill_tree_visuals()

func _process(_delta: float) -> void:
	# REALTIME POPUP MUIS-TRACKING
	if is_instance_valid(skill_popup) and skill_popup.visible:
		var mouse_pos = get_global_mouse_position()
		
		# We zetten hem op een vaste, comfortabele afstand rechtsonder de cursor (X: 25, Y: 25)
		# Doordat het vak nu maximaal 200 breed is en wrapt, valt er niks meer buiten beeld!
		skill_popup.global_position = mouse_pos + Vector2(25, 25)


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
# --- JULLIE ORIGINELE DUAL-MODUS KOOP EN SPENDERINGS AFHANDELING ---
# =========================================================================
func _on_any_skill_button_pressed(skill_id: String) -> void:
	if not current_meta or not is_instance_valid(skill_slots_container): return
	
	# Zoek het visuele slot op basis van de skill_id property
	var slot_node: Node = null
	for child in skill_slots_container.get_children():
		if "skill_id" in child and child.skill_id == skill_id:
			slot_node = child
			break
			
	if not slot_node: return
	
	# Haal de sub-dictionary veilig op conform de goudstandaard (0-indexed valuta)
	var current_data = current_meta.skills_data.get(skill_id, {"level": 0, "currency_type": 0})
	var current_level = int(current_data["level"])
	
	if current_level >= 100: return
	
	# Haal de live variabelen op uit de node (gevuld vanuit de Master CSV)
	var cost: int = slot_node.cost_per_click if "cost_per_click" in slot_node else 5
	var c_type: int = slot_node.currency_type if "currency_type" in slot_node else 0
	
	# Bepaal de bulk-afname op basis van buy_amount (+1 of +10)
	var actual_buy_qty = buy_amount
	if current_level + actual_buy_qty > 100:
		actual_buy_qty = 100 - current_level
	if actual_buy_qty <= 0: return
	
	var total_bulk_cost = cost * actual_buy_qty
	var can_afford: bool = false
	
	# SSoT INTEGRATIE: Trek de kosten type-veilig af op basis van Godot enums (0 = currency_1)
	if c_type == 0 and current_meta.currency_1 >= total_bulk_cost:
		current_meta.currency_1 -= total_bulk_cost
		can_afford = true
	elif c_type == 1 and current_meta.currency_2 >= total_bulk_cost:
		current_meta.currency_2 -= total_bulk_cost
		can_afford = true
	elif c_type == 2 and current_meta.currency_3 >= total_bulk_cost:
		current_meta.currency_3 -= total_bulk_cost
		can_afford = true
	elif c_type == 3 and current_meta.currency_4 >= total_bulk_cost:
		current_meta.currency_4 -= total_bulk_cost
		can_afford = true
	elif c_type == 4 and current_meta.currency_5 >= total_bulk_cost:
		current_meta.currency_5 -= total_bulk_cost
		can_afford = true
	elif c_type == 5 and current_meta.currency_6 >= total_bulk_cost:
		current_meta.currency_6 -= total_bulk_cost
		can_afford = true
		
	if can_afford:
		# Dupliceer de dictionary om Godot te dwingen de nested data-update op te slaan
		var updated_slot_data = current_meta.skills_data.get(skill_id, {"level": 0, "currency_type": c_type}).duplicate()
		updated_slot_data["level"] = current_level + actual_buy_qty
		current_meta.skills_data[skill_id] = updated_slot_data
		
		print("SKILL TREE: Succesvol gekocht! ", skill_id, " level is nu: ", current_meta.skills_data[skill_id]["level"])
		
		# Sla de progressie direct op
		var save_system = load("res://Systems/SaveSystem.gd").new()
		if save_system and save_system.has_method("save_meta_progress"):
			save_system.save_meta_progress(current_meta)
			
		# Sync ook de lokale runtime variabele op het slot zelf
		if "current_level" in slot_node:
			slot_node.current_level = current_meta.skills_data[skill_id]["level"]
			
		update_skill_tree_visuals()
	else:
		print("SKILL TREE: Onvoldoende saldo voor ", skill_id, " (Kosten: ", total_bulk_cost, ")")


# =========================================================================
# --- VISUELE SYNC EN TRAP-BOCHTEN DRAW UPDATE LOOP (MET VERRE BLIK) ---
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
	
	# 1. Database controle & initialisatie via de Inspector/CSV-waarden
	for slot in all_slots:
		var s_id = slot.skill_id if "skill_id" in slot else slot.name
		var c_type: int = slot.currency_type if "currency_type" in slot else 0
		var loss_rate: int = slot.loss_per_minute if "loss_per_minute" in slot else 1
			
		if not current_meta.skills_data.has(s_id) or not (current_meta.skills_data[s_id] is Dictionary):
			current_meta.skills_data[s_id] = {
				"level": 0, 
				"currency_type": c_type,
				"loss_per_minute": loss_rate
			}
		else:
			current_meta.skills_data[s_id]["currency_type"] = c_type
			current_meta.skills_data[s_id]["loss_per_minute"] = loss_rate

	# 2. BEPAAL DE REIKWIJDTE VAN JOUW VISUELE KIJKER (DYNAMISCH)
	var vision_range: int = 1
	if current_meta.skills_data.has("skill_vision"):
		var vision_data = current_meta.skills_data["skill_vision"]
		var vision_level = int(vision_data["level"]) if vision_data is Dictionary else int(vision_data)
		if vision_level > 0:
			vision_range = 2

	# 3. Universele check van de stamboom (Zorgt voor zichtbaarheids-resets en lijnen)
	for slot in all_slots:
		var s_id = slot.skill_id if "skill_id" in slot else slot.name
		var bar = slot.find_child("*Bar*", true, false) as ProgressBar
		var button = slot.find_child("*Button*", true, false) as Button
		var level = int(current_meta.skills_data[s_id]["level"])
		
		# Check of de overkoepelende ouders belicht zijn binnen onze range
		var is_visible_by_fog: bool = false
		var parent_node = slot.get("parent_skill_slot") if "parent_skill_slot" in slot else null
		
		if parent_node == null:
			is_visible_by_fog = true
		else:
			var current_check_parent = parent_node
			var steps_away: int = 1
			
			while current_check_parent != null and steps_away <= vision_range:
				var p_id = current_check_parent.skill_id if "skill_id" in current_check_parent else current_check_parent.name
				var p_level: int = 0
				if current_meta.skills_data.has(p_id):
					var p_data = current_meta.skills_data[p_id]
					p_level = int(p_data["level"]) if p_data is Dictionary else int(p_data)
				
				if p_level > 0:
					is_visible_by_fog = true
					break
				
				current_check_parent = current_check_parent.get("parent_skill_slot") if "parent_skill_slot" in current_check_parent else null
				steps_away += 1
		
		# 4. PAS DE ZICHTBAARHEID EN DE TRAK-LIJNEN TOE
		if is_visible_by_fog:
			slot.visible = true
			if button: button.disabled = false
			update_single_skill_visual(bar, button, level, s_id)
			
			if is_instance_valid(parent_node) and parent_node.visible:
				if is_instance_valid(skill_lines_container) and line_index < skill_lines_container.get_child_count():
					draw_line_between(skill_lines_container.get_child(line_index), parent_node, slot)
					line_index += 1
		else:
			slot.visible = false
			if button: button.disabled = true


# --- VISUELE UPGRADE INKLEURING CONFORM JULLIE ARCHITECTUUR ---
func update_single_skill_visual(bar: ProgressBar, button: Button, level: int, slot_name: String) -> void:
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
		button.text = slot_name + " (100/100)"
		
	bar.add_theme_stylebox_override("fill", sb)


# --- JULLIE RECHTSTREEKSE HAAKSE Z-VORM TRAP-BOCHTEN BEREKENING (HERSTELD) ---
func draw_line_between(line: Line2D, parent_slot: Control, child_slot: Control) -> void:
	if not line or not parent_slot or not child_slot: return
	
	var p_bar = parent_slot.find_child("*Bar*", true, false)
	var c_bar = child_slot.find_child("*Bar*", true, false)
	
	if p_bar and c_bar:
		line.clear_points()
		line.visible = true
		line.default_color = Color.GOLD
		line.z_index = -1
		
		var start_pos: Vector2 = line.to_local(p_bar.global_position + Vector2(p_bar.size.x / 2, p_bar.size.y - 3))
		var end_pos: Vector2 = line.to_local(c_bar.global_position + Vector2(c_bar.size.x / 2, 3))
		
		var mid_y: float = start_pos.y + ((end_pos.y - start_pos.y) / 2)
		var knik_1: Vector2 = Vector2(start_pos.x, mid_y)
		var knik_2: Vector2 = Vector2(end_pos.x, mid_y)
		
		line.add_point(start_pos)
		line.add_point(knik_1)
		line.add_point(knik_2)
		line.add_point(end_pos)

# --- POPUP AFHANDELING: Muis schuift op de knop ---
func _on_skill_button_hover_entered(skill_id: String) -> void:
	if not is_instance_valid(skill_popup) or not current_meta: return
	
	# Haal de live data op uit de MasterDatabase (als de ID bestaat)
	var title_text = skill_id.capitalize()
	var info_text = "Placeholder: Extra informatie over deze upgrade komt dadelijk uit de CSV!"
	
	# SSoT VOORBEREIDING: Als de MasterDatabase de data al heeft, lenen we die alvast
	if MasterDatabase.skill_data.has(skill_id):
		var csv_row = MasterDatabase.skill_data[skill_id]
		# Zodra de CSV geüpload is, pakt hij automatisch jullie nieuwe kolom!
		if csv_row.has("base_stats") and csv_row["base_stats"].has("skill_pop_up_info"):
			info_text = str(csv_row["base_stats"]["skill_pop_up_info"])
			
	# Vul de labels op je monitor
	if is_instance_valid(popup_title): popup_title.text = title_text
	if is_instance_valid(popup_description): popup_description.text = info_text
	
	# Toon het venster
	skill_popup.visible = true


# --- POPUP AFHANDELING: Muis verlaat de knop ---
func _on_skill_button_hover_exited() -> void:
	if is_instance_valid(skill_popup):
		skill_popup.visible = false


func _on_back_to_main_menu_pressed() -> void:
	print("SKILL TREE: Terugkeren naar het hoofdmenu...")
	var save_system = load("res://Systems/SaveSystem.gd").new()
	if save_system and current_meta:
		save_system.save_meta_progress(current_meta)
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
