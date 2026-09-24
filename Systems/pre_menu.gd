extends Control
# BEDIENING: Pre-Menu (Save Slot Selectiescherm)

func _ready() -> void:
	print("Kies een Save Slot om verder te gaan...")


# --- LOGICA VOOR DE KNOPPEN ---

func _on_slot_1_button_pressed() -> void:
	_activate_save_slot("Slot_1")


func _on_slot_2_button_pressed() -> void:
	_activate_save_slot("Slot_2")


func _on_slot_3_button_pressed() -> void:
	_activate_save_slot("Slot_3")


# HULPFUNCTIE: Handelt de centrale slot-activatie en scene-wissel crashvrij af
func _activate_save_slot(slot_name: String) -> void:
	if is_instance_valid(Game):
		Game.active_save_slot = slot_name
		print("Actief save slot ingesteld op: ", Game.active_save_slot)
		
		# Sla de keuze permanent op voor de volgende koude herstart
		var save_system = load("res://Systems/SaveSystem.gd").new()
		if save_system:
			save_system.save_last_used_slot(slot_name)
			if save_system.has_method("get_loaded_meta_progress"):
				var _meta = save_system.get_loaded_meta_progress()
			
	# Wissel direct door naar het Main Menu
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")


# Slaat het laatst gebruikte slot permanent op de schijf op
func save_last_used_slot(slot_name: String) -> void:
	var file = FileAccess.open("user://app_config.json", FileAccess.WRITE)
	if file:
		var config_data = {"last_slot": slot_name}
		file.store_string(JSON.stringify(config_data))
		file.close()

# Leest het laatst gebruikte slot uit van de schijf
func load_last_used_slot() -> String:
	if FileAccess.file_exists("user://app_config.json"):
		var file = FileAccess.open("user://app_config.json", FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var config_data = json.get_data()
			if config_data.has("last_slot"):
				file.close()
				return config_data["last_slot"]
		file.close()
	return ""
