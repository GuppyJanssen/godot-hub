extends Control

var current_meta = null

# --- 6 LIVE CURRENCY LABELS ---
@onready var c1_label: Label = $FixedUI/Node2D/HBoxContainer/CurrencyLabel1
@onready var c2_label: Label = $FixedUI/Node2D/HBoxContainer/CurrencyLabel2
@onready var c3_label: Label = $FixedUI/Node2D/HBoxContainer/CurrencyLabel3
@onready var c4_label: Label = $FixedUI/Node2D/VBoxContainer/CurrencyLabel4
@onready var c5_label: Label = $FixedUI/Node2D/VBoxContainer/CurrencyLabel5
@onready var c6_label: Label = $FixedUI/Node2D/VBoxContainer/CurrencyLabel6

# --- SIMPELE CAMERA & MAP-MAPPEN ---
@onready var tree_camera: Camera2D = $TreeCamera
@onready var skill_slots_container: Node = $Skill_Slots
@onready var skill_lines_container: Node = $Skill_Lines

# --- CAMERA ZOOM & PAN INSTELLINGEN ---
var min_zoom: float = 0.5
var max_zoom: float = 2.0
var zoom_speed: float = 0.1
var is_dragging: bool = false


func _ready() -> void:
	get_viewport().gui_release_focus()
	
	var save_system = load("res://Systems/SaveSystem.gd").new()
	current_meta = save_system.get_loaded_meta_progress()
	
	# Centreer de camera netjes in het midden van het scherm bij opstarten
	tree_camera.global_position = Vector2(960, 540)
	
	# Dynamische signaalkoppeling voor de klik-knoppen van álle slots in de map
	for slot in skill_slots_container.get_children():
		var button = slot.find_child("*Button*", true, false)
		var bar = slot.find_child("*Bar*", true, false)
		if bar: bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if button and not button.pressed.is_connected(_on_any_skill_button_pressed):
			button.pressed.connect(_on_any_skill_button_pressed.bind(slot.name))
			
	await get_tree().process_frame
	update_skill_tree_visuals()


# --- INTERACTIEVE CAMERA BESTURING & ESCAPE SNELTOETS ---

func _input(event: InputEvent) -> void:
	# SNELTOETS: Als de speler op Escape drukt, reizen we direct terug naar het hoofdmenu!
	if event.is_action_pressed("ui_cancel"):
		_on_main_menu_button_pressed()
		return

	# 1. SLEEP DE KAART MET DE RECHTERMUISKNOP
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.is_pressed():
			is_dragging = true
		else:
			is_dragging = false
			
	if event is InputEventMouseMotion and is_dragging:
		tree_camera.global_position -= event.relative / tree_camera.zoom
		
	# 2. ZOOM IN EN UIT MET HET MUISWIEL
	if event is InputEventMouseButton and event.is_pressed():
		var current_zoom = tree_camera.zoom.x
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_zoom = clamp(current_zoom + zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_zoom = clamp(current_zoom - zoom_speed, min_zoom, max_zoom)
		tree_camera.zoom = Vector2(current_zoom, current_zoom)


# --- VISUELE UPGRADE INKLEURING (Nu BOVENAAN declared zodat Godot hem kent!) ---

func update_single_skill_visual(bar: ProgressBar, button: Button, level: int, slot_name: String) -> void:
	if not bar or not button: return
	
	# De voortgangsbalk schaalt nu 1-op-1 mee met het aantal punten (0 t/m 100)
	bar.value = level
	
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.15, 1.0) # Massief donkergrijs schild tegen de lijn
	bg.set_border_width_all(0)
	bg.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("background", bg)
	
	var sb = StyleBoxFlat.new()
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	
	# Kleurverloop op basis van het percentage
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


# --- DE INTELLIGENTE TRAP-BOCHTEN BEREKENING (Z-VORM) ---

func draw_line_between(line: Line2D, parent_slot: Control, child_slot: Control) -> void:
	if not line or not parent_slot or not child_slot: return
	
	var p_bar = parent_slot.find_child("*Bar*", true, false)
	var c_bar = child_slot.find_child("*Bar*", true, false)
	
	if p_bar and c_bar:
		line.clear_points() # Wis oude spook-punten direct!
		line.visible = true
		line.default_color = Color.GOLD
		
		# Omrekening naar lokale coördinaten voor de Line2D node
		var start_pos: Vector2 = line.to_local(p_bar.global_position + Vector2(p_bar.size.x / 2, p_bar.size.y - 3))
		var end_pos: Vector2 = line.to_local(c_bar.global_position + Vector2(c_bar.size.x / 2, 3))
		
		# Bereken de perfecte haakse trap-bocht (Z-vorm)
		var mid_y: float = start_pos.y + ((end_pos.y - start_pos.y) / 2)
		var knik_1: Vector2 = Vector2(start_pos.x, mid_y)
		var knik_2: Vector2 = Vector2(end_pos.x, mid_y)
		
		line.add_point(start_pos)
		line.add_point(knik_1)
		line.add_point(knik_2)
		line.add_point(end_pos)


# --- DYNAMISCHE UPDATE LOOP & DATA REPARATIE ---

func update_skill_tree_visuals() -> void:
	c1_label.text = "0lrite: " + str(current_meta.currency_1 if "currency_1" in current_meta else 0)
	c2_label.text = "Gold: " + str(current_meta.currency_2 if "currency_2" in current_meta else 0)
	c3_label.text = "Keepium: " + str(current_meta.currency_3 if "currency_3" in current_meta else 0)
	c4_label.text = "Element 1: " + str(current_meta.currency_4 if "currency_4" in current_meta else 0)
	c5_label.text = "Element 2: " + str(current_meta.currency_5 if "currency_5" in current_meta else 0)
	c6_label.text = "Element 3: " + str(current_meta.currency_6 if "currency_6" in current_meta else 0)
	
	for line in skill_lines_container.get_children():
		if line is Line2D: 
			line.clear_points()
			line.visible = false
		
	var line_index: int = 0
	var all_slots = skill_slots_container.get_children()
	
	# database-controle & initialisatie via de Inspector-waarden
	for slot in all_slots:
		var c_type: int = 1
		var loss_rate: int = 1
		if slot is SkillSlot:
			# Godot enums beginnen bij 0, onze database telt vanaf 1
			c_type = slot.currency_type + 1 
			loss_rate = slot.points_lost_per_minute
			
		if not current_meta.skills_data.has(slot.name) or not (current_meta.skills_data[slot.name] is Dictionary):
			current_meta.skills_data[slot.name] = {
				"level": 0, 
				"currency_type": c_type,
				"loss_per_minute": loss_rate
			}
		else:
			# Update de live Inspector-waarden in de actieve database
			current_meta.skills_data[slot.name]["currency_type"] = c_type
			current_meta.skills_data[slot.name]["loss_per_minute"] = loss_rate

	# Universele, dynamische check van de complete stamboom (Geen hardcoded namen meer!)
	for slot in all_slots:
		var bar = slot.find_child("*Bar*", true, false)
		var button = slot.find_child("*Button*", true, false)
		var level = current_meta.skills_data[slot.name]["level"]
		
		if slot is SkillSlot and slot.parent_skill_slot != null:
			var parent_node = slot.parent_skill_slot
			var parent_level: int = 0
			if current_meta.skills_data.has(parent_node.name):
				parent_level = current_meta.skills_data[parent_node.name]["level"]
			
			if parent_level > 0:
				slot.visible = true
				update_single_skill_visual(bar, button, level, slot.name)
				if line_index < skill_lines_container.get_child_count():
					draw_line_between(skill_lines_container.get_child(line_index), parent_node, slot)
					line_index += 1
			else:
				slot.visible = false
		else:
			slot.visible = true
			update_single_skill_visual(bar, button, level, slot.name)


func _on_any_skill_button_pressed(slot_name: String) -> void:
	var slot_node = skill_slots_container.find_child(slot_name, true, false)
	var current_data = current_meta.skills_data.get(slot_name, {"level": 0, "currency_type": 1})
	var current_level = current_data["level"]
	
	if current_level >= 100: return
	
	# Haal de dynamische prijs en valuta op uit de Inspector van het slot
	var cost: int = slot_node.cost_per_click if slot_node is SkillSlot else 1
	var c_type: int = slot_node.currency_type + 1 if slot_node is SkillSlot else 1
	
	var can_afford: bool = false
	if c_type == 1 and current_meta.currency_1 >= cost:
		current_meta.currency_1 -= cost
		can_afford = true
	elif c_type == 2 and current_meta.currency_2 >= cost:
		current_meta.currency_2 -= cost
		can_afford = true
	elif c_type == 3 and current_meta.currency_3 >= cost:
		current_meta.currency_3 -= cost
		can_afford = true
	elif c_type == 4 and current_meta.currency_4 >= cost:
		current_meta.currency_4 -= cost
		can_afford = true
	elif c_type == 5 and current_meta.currency_5 >= cost:
		current_meta.currency_5 -= cost
		can_afford = true
	elif c_type == 6 and current_meta.currency_6 >= cost:
		current_meta.currency_6 -= cost
		can_afford = true
		
	if can_afford:
		current_meta.skills_data[slot_name]["level"] = current_level + 1
		var save_system = load("res://Systems/SaveSystem.gd").new()
		save_system.save_meta_progress(current_meta)
		update_skill_tree_visuals()



func _on_main_menu_button_pressed() -> void:
	var save_system = load("res://Systems/SaveSystem.gd").new()
	save_system.save_meta_progress(current_meta)
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")


# Luister of de ontwerper op F1 drukt om de cheat-box te tonen
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("ui_text_clear_carets_and_selection") or (event is InputEventKey and event.pressed and event.keycode == KEY_F1):
		$FixedUI/DebugMenu.visible = not $FixedUI/DebugMenu.visible
		print("DEBUG: Cheat-menu omgeschakeld!")
