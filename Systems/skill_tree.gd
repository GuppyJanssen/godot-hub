extends Control

var current_meta = null

# Labels voor de valuta (hangen nog onder Node2D)
@onready var c1_label: Label = $Node2D/HBoxContainer/CurrencyLabel1
@onready var c2_label: Label = $Node2D/HBoxContainer/CurrencyLabel2
@onready var c3_label: Label = $Node2D/HBoxContainer/CurrencyLabel3

# UPDATED: De goudlijn zit nu in de Skill_Lines map
@onready var skill_line: Line2D = $Skill_Lines/SkillLine

# UPDATED PADEN: De code zoekt nu diep in de 'Skill_Slots' map!
@onready var skill_1_slot: Control = $Skill_Slots/Skill1_Slot
@onready var skill_1_bar: ProgressBar = $Skill_Slots/Skill1_Slot/Skill1Button/Skill1_Bar
@onready var skill_1_button: Button = $Skill_Slots/Skill1_Slot/Skill1Button

@onready var skill_2_slot: Control = $Skill_Slots/Skill2_Slot
@onready var skill_2_bar: ProgressBar = $Skill_Slots/Skill2_Slot/Skill2Button/Skill2_Bar
@onready var skill_2_button: Button = $Skill_Slots/Skill2_Slot/Skill2Button




func _ready() -> void:
	get_viewport().gui_release_focus()
	
	# Laad de voortgang in via de Bestands-Manager
	var save_system = load("res://Systems/SaveSystem.gd").new()
	current_meta = save_system.get_loaded_meta_progress()
	
	# Zet de ankers van de hoofd-slots centraal
	setup_slot_anchors()
	
	# Teken de verbindingslijn (wacht 1 frame zodat global_positions stabiel zijn)
	await get_tree().process_frame
	setup_connection_line()
	
	# Update alle tekstvelden, kleuren en zichtbaarheden
	update_skill_tree_visuals()


func setup_slot_anchors() -> void:
	# We lieten Godot hier de positie overschrijven. 
	# Door dit leeg te laten, herstelt de editor-uitlijning zich direct!
	pass


func setup_connection_line() -> void:
	skill_line.clear_points()
	
	# GECORRIGEERD: We trekken 1 pixel van de Y-as af zodat de lijn exact onder de rand stopt!
	var start_pos: Vector2 = skill_1_bar.global_position + Vector2(skill_1_bar.size.x / 2, 0)
	var end_pos: Vector2 = skill_2_bar.global_position + Vector2(skill_2_bar.size.x / 2, skill_2_bar.size.y - 2)
	
	# Haakse bocht berekenen
	var mid_y: float = start_pos.y + ((end_pos.y - start_pos.y) / 2)
	var knik_1: Vector2 = Vector2(start_pos.x, mid_y)
	var knik_2: Vector2 = Vector2(end_pos.x, mid_y)
	
	# Punten toevoegen als lokale coördinaten
	skill_line.add_point(skill_line.to_local(start_pos))
	skill_line.add_point(skill_line.to_local(knik_1))
	skill_line.add_point(skill_line.to_local(knik_2))
	skill_line.add_point(skill_line.to_local(end_pos))
	skill_line.z_index = -1 # Dwingt de lijn ALTIJD achter de vakjes te zakken!



# --- DYNAMISCHE UPDATE LOOP ---

func update_skill_tree_visuals() -> void:
	# Live geld-counters bijwerken
	c1_label.text = "XP (Currency 1): " + str(current_meta.currency_1)
	c2_label.text = "Goud (Currency 2): " + str(current_meta.currency_2)
	c3_label.text = "Tokens (Currency 3): " + str(current_meta.currency_3)
	
	update_single_skill_visual(skill_1_bar, skill_1_button, current_meta.skill_1_level)
	
	# NIEUW: We zetten nu het hele MAPJE (Skill2_Slot) op onzichtbaar of zichtbaar!
	if current_meta.skill_1_level > 0:
		skill_2_slot.visible = true
		update_single_skill_visual(skill_2_bar, skill_2_button, current_meta.skill_2_level)
		skill_line.default_color = Color.GOLD
		skill_line.visible = true
	else:
		skill_2_slot.visible = false
		skill_line.default_color = Color(0.2, 0.2, 0.2, 1.0)
		skill_line.visible = false


#progressbar van skill tree slots
func update_single_skill_visual(bar: ProgressBar, button: Button, level: int) -> void:
	# 1. Dit schaalt de balk AUTOMATISCH mee met het getal (0%, 25%, 50%, 75%, 100%)
	bar.value = level * 25
	
	# 2. Dit verandert de complete kleur van de balk direct mee!
	match level:
		0:
			bar.modulate = Color.RED
			button.text = "UPGRADE (0/4)"
		1:
			bar.modulate = Color.ORANGE
			button.text = "LEVEL 1 (1/4)"
		2:
			bar.modulate = Color.YELLOW
			button.text = "LEVEL 2 (2/4)"
		3:
			bar.modulate = Color.GREEN
			button.text = "LEVEL 3 (3/4)"
		4:
			bar.modulate = Color.DODGER_BLUE
			button.text = "MAXIMAAL!"



# --- UPGRADE KNOPPEN ---

func _on_skill_1_button_pressed() -> void:
	var cost: int = 25
	if current_meta.currency_1 >= cost and current_meta.skill_1_level < 4:
		current_meta.currency_1 -= cost
		current_meta.skill_1_level += 1
		
		var save_system = load("res://Systems/SaveSystem.gd").new()
		save_system.save_meta_progress(current_meta)
		update_skill_tree_visuals()


func _on_skill_2_button_pressed() -> void:
	var cost: int = 40
	if current_meta.currency_2 >= cost and current_meta.skill_2_level < 4:
		current_meta.currency_2 -= cost
		current_meta.skill_2_level += 1
		
		var save_system = load("res://Systems/SaveSystem.gd").new()
		save_system.save_meta_progress(current_meta)
		update_skill_tree_visuals()


func _on_main_menu_button_pressed() -> void:
	var save_system = load("res://Systems/SaveSystem.gd").new()
	save_system.save_meta_progress(current_meta)
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
