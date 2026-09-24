extends Control
# BEDIENING: Skill Tree Regisseur (Volledig Gecorrigeerd, SSoT & Bulk-Toggle)

var current_meta: MetaProgress = null

# GECOORDINEERD: Bepaalt hoeveel levels er per klik worden gekocht (1 of 10)
var buy_amount: int = 1

# --- GECORRIGEERD (Prio 1): Hardcoded paden naar jullie exacte scene-labels! ---
@onready var c1_label: Label = $FixedUI/Node2D/HBoxContainer/CurrencyLabel1
@onready var c2_label: Label = $FixedUI/Node2D/HBoxContainer/CurrencyLabel2
@onready var c3_label: Label = $FixedUI/Node2D/HBoxContainer/CurrencyLabel3
@onready var c4_label: Label = $FixedUI/Node2D/VBoxContainer/CurrencyLabel4
@onready var c5_label: Label = $FixedUI/Node2D/VBoxContainer/CurrencyLabel5
@onready var c6_label: Label = $FixedUI/Node2D/VBoxContainer/CurrencyLabel6

@onready var tree_camera: Camera2D = $TreeCamera
@onready var skill_slots_container: Node = $Skill_Slots
@onready var skill_lines_container: Node = $Skill_Lines

# GECOORDINEERD: UI-Label om de speler te tonen of +1 of +10 actief is
@onready var bulk_status_label: Label = $FixedUI/Node2D/BulkStatusLabel if has_node("FixedUI/Node2D/BulkStatusLabel") else null

var min_zoom: float = 0.5
var max_zoom: float = 2.0
var zoom_speed: float = 0.1
var is_dragging: bool = false


func _ready() -> void:
	get_viewport().gui_release_focus()
	_refresh_from_disk()
	
	if is_instance_valid(tree_camera):
		tree_camera.global_position = Vector2(960, 540)
	
	# Dynamische signaalkoppeling voor de klik-knoppen van álle slots in de map
	if is_instance_valid(skill_slots_container):
		for slot in skill_slots_container.get_children():
			var button = slot.find_child("*Button*", true, false)
			var bar = slot.find_child("*Bar*", true, false)
			if bar: bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if button and not button.pressed.is_connected(_on_any_skill_button_pressed):
				button.pressed.connect(_on_any_skill_button_pressed.bind(slot.name))
				
	_update_bulk_label_text()


func _refresh_from_disk() -> void:
	var save_system = load("res://Systems/SaveSystem.gd").new()
	if save_system and save_system.has_method("get_loaded_meta_progress"):
		current_meta = save_system.get_loaded_meta_progress()
	update_skill_tree_visuals()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(tree_camera): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_dragging = event.is_pressed()
	if event is InputEventMouseMotion and is_dragging:
		tree_camera.global_position -= event.relative / tree_camera.zoom
	if event is InputEventMouseButton and event.is_pressed():
		var current_zoom = tree_camera.zoom.x
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_zoom = clamp(current_zoom + zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_zoom = clamp(current_zoom - zoom_speed, min_zoom, max_zoom)
		tree_camera.zoom = Vector2(current_zoom, current_zoom)


# GECOORDINEERD: Deze functie koppelen jullie aan de nieuwe Bulk-Toggle Knop in de UI!
func _on_bulk_toggle_button_pressed() -> void:
	buy_amount = 10 if buy_amount == 1 else 1
	print("SKILL TREE: Bulk-modus gewijzigd naar: +", buy_amount)
	_update_bulk_label_text()


func _update_bulk_label_text() -> void:
	if is_instance_valid(bulk_status_label):
		bulk_status_label.text = "Modus: +" + str(buy_amount)


func _on_any_skill_button_pressed(slot_name: String) -> void:
	if not current_meta: return
	if not is_instance_valid(skill_slots_container): return
	
	var slot_node = skill_slots_container.find_child(slot_name, true, false)
	if not slot_node or not (slot_node is SkillSlot): return
	var s_id = slot_node.skill_id
	
	if not s_id in MasterDatabase.skill_data: return
	var csv_row = MasterDatabase.skill_data[s_id]
	var cost_per_point = int(csv_row["base_stats"].get("cost_per_click", 5))
	
	if not current_meta.skills_data.has(s_id):
		current_meta.skills_data[s_id] = 0
		
	var current_level = int(current_meta.skills_data[s_id])
	if current_level >= 100: return
	
	# PREVENTIEVE CALCULATIE: Bepaal hoeveel levels we daadwerkelijk kunnen kopen tot de max van 100
	var actual_buy_qty: int = buy_amount
	if current_level + actual_buy_qty > 100:
		actual_buy_qty = 100 - current_level
		
	if actual_buy_qty <= 0: return
	
	# Bereken de totale bulk-kosten vooraf om saldo-crashes te voorkomen
	var total_bulk_cost: int = cost_per_point * actual_buy_qty
	
	# PREVENTIEVE PORTERMONNEE SAFE GUARD
	if current_meta.currency_1 >= total_bulk_cost:
		current_meta.currency_1 -= total_bulk_cost
		current_meta.skills_data[s_id] = current_level + actual_buy_qty
		
		var save_system = load("res://Systems/SaveSystem.gd").new()
		if save_system and save_system.has_method("save_meta_progress"):
			save_system.save_meta_progress(current_meta)
		update_skill_tree_visuals()
	else:
		print("SKILL TREE: Onvoldoende Olrite voor bulk aankoop van +", actual_buy_qty, " (Vereist: ", total_bulk_cost, ")")


func update_skill_tree_visuals() -> void:
	if not current_meta: return
	
	# PREVENTIEVE CRASH GUARD: Controleer of alle labels fysiek bestaan voordat we ze beschrijven
	if is_instance_valid(c1_label): c1_label.text = "Olrite: " + str(current_meta.currency_1)
	if is_instance_valid(c2_label): c2_label.text = "Gold: " + str(current_meta.currency_2)
	if is_instance_valid(c3_label): c3_label.text = "Keepium: " + str(current_meta.currency_3)
	if is_instance_valid(c4_label): c4_label.text = "Element 1: " + str(current_meta.currency_4)
	if is_instance_valid(c5_label): c5_label.text = "Element 2: " + str(current_meta.currency_5)
	if is_instance_valid(c6_label): c6_label.text = "Element 3: " + str(current_meta.currency_6)
	
	if not is_instance_valid(skill_slots_container): return
	var all_slots = skill_slots_container.get_children()
	for slot in all_slots:
		if not (slot is SkillSlot): continue
		var s_id = slot.skill_id
		var bar = slot.find_child("*Bar*", true, false)
		var button = slot.find_child("*Button*", true, false)
		
		var level = 0
		if current_meta.skills_data.has(s_id):
			var raw_val = current_meta.skills_data[s_id]
			level = int(raw_val["level"]) if raw_val is Dictionary else int(raw_val)
			
		if is_instance_valid(bar):
			bar.value = level
		if is_instance_valid(button):
			button.text = slot.name + " (" + str(level) + "/100)"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("ui_text_clear_carets_and_selection") or (event is InputEventKey and event.pressed and event.keycode == KEY_F1):
		if is_instance_valid(DebugOverlay):
			DebugOverlay.visible = not DebugOverlay.visible
			get_viewport().set_input_as_handled()
			if not DebugOverlay.visible:
				_refresh_from_disk()


func _on_main_menu_button_pressed() -> void:
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
