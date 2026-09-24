extends Control

var current_meta: MetaProgress = null

# GECORRIGEERD: Bepaalt hoeveel levels er per klik worden gekocht (1 of 10)
var buy_amount: int = 1

# GECORRIGEERD: We hebben de 6 losse crashende onready-labels verwijderd! 
# We synchroniseren de valuta-balken in de Skill Tree nu direct via de Live HUD of de schijf-resource.
var currency_labels_ref: Array = []

@onready var tree_camera: Camera2D = $TreeCamera
@onready var skill_slots_container: Node = find_child("*Skill_Slots*", true, false)
@onready var skill_lines_container: Node = find_child("*Skill_Lines*", true, false)


# GECORRIGEERD: UI-Label om de speler te tonen of +1 of +10 actief is
@onready var bulk_status_label: Label = find_child("BulkStatusLabel", true, false) as Label

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
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		if event.is_pressed() and not event.is_echo():
			# GECORRIGEERD: Sluit de Skill Tree en stop het event direct (MARK AS HANDLED)
			# Dit voorkomt dat de escape-toets doorvliegt naar het F1 Debug-menu!
			get_tree().root.set_input_as_handled()
			_on_back_to_main_menu_pressed()
			return


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
	
	# --- GECORRIGEERD: Dynamische SSoT-sync met de nieuwe HUD-labels! ---
	# We zoeken de actieve live Hud node op het scherm op om zijn labels te lenen
	var live_hud = get_tree().root.find_child("Hud", true, false)
	
	if is_instance_valid(live_hud) and "currency_labels" in live_hud and live_hud.currency_labels.size() >= 6:
		# Als de live HUD in beeld staat, schrijven we de cijfers direct live naar die labels!
		live_hud.currency_labels[0].text = "Olrite: " + str(current_meta.currency_1)
		live_hud.currency_labels[1].text = "Metal: " + str(current_meta.currency_2) # Gecorrigeerd: 'Metal' i.p.v. metal
		live_hud.currency_labels[2].text = "Keepium: " + str(current_meta.currency_3)
		live_hud.currency_labels[3].text = "Element 1: " + str(current_meta.currency_4)
		live_hud.currency_labels[4].text = "Element 2: " + str(current_meta.currency_5)
		live_hud.currency_labels[5].text = "Element 3: " + str(current_meta.currency_6)
	
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


func _on_back_to_main_menu_pressed() -> void:
	print("SKILL TREE: Terugkeren naar het hoofdmenu...")
	# Sla de meta-progressie voor alle zekerheid nog een keer op voordat we scéne wisselen
	var save_system = load("res://Systems/SaveSystem.gd").new()
	if save_system and current_meta:
		save_system.save_meta_progress(current_meta)
		
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
