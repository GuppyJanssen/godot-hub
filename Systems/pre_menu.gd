extends Control

# --- INGEBOUWDE GODOT FUNCTIES ---

func _ready() -> void:
	# Voor de zekerheid zetten we het actieve slot leeg zodra we in dit menu komen
	Game.active_save_slot = ""
	print("Kies een Save Slot om verder te gaan...")


# --- LOGICA VOOR DE KNOPPEN ---

func _on_slot_1_button_pressed() -> void:
	# We zetten het actieve slot in de Autoload op Slot_1
	Game.active_save_slot = "Slot_1"
	print("Actief save slot ingesteld op: ", Game.active_save_slot)
	# Wissel direct door naar het vertrouwde Main Menu
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")


func _on_slot_2_button_pressed() -> void:
	Game.active_save_slot = "Slot_2"
	print("Actief save slot ingesteld op: ", Game.active_save_slot)
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")


func _on_slot_3_button_pressed() -> void:
	Game.active_save_slot = "Slot_3"
	print("Actief save slot ingesteld op: ", Game.active_save_slot)
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
