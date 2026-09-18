extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.



func _on_continue_button_pressed() -> void:
	# We vertellen de game dat we een bestaande run willen hervatten!
	Game.should_load_run = true
	# Laad direct het level in
	get_tree().change_scene_to_file("res://World/Levels/world_level_spawn_area.tscn")

func _on_skill_tree_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Systems/SkillTree.tscn")

func _on_new_run_button_pressed() -> void:
	Game.should_load_run = false # Frisse start!
	get_tree().change_scene_to_file("res://World/Levels/world_level_spawn_area.tscn")

func _on_new_game_button_pressed() -> void:
	# Deze knop stuurt de speler direct weer terug naar de Slot-keuze
	get_tree().change_scene_to_file("res://Systems/pre_menu.tscn")

#knop sluit spel af
func _on_exit_button_pressed() -> void:
		get_tree().quit()
