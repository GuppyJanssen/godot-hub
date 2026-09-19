extends CanvasLayer

var debug_panel: Panel
var current_meta = null

# Knoppen bewaren om de tekst live te kunnen updaten [AAN/UIT]
var btn_spd: Button
var btn_dmg: Button
var btn_inv: Button

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	debug_panel = Panel.new()
	debug_panel.size = Vector2(320, 240)
	debug_panel.position = Vector2(20, 20)
	debug_panel.visible = false
	add_child(debug_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	debug_panel.add_child(vbox)
	
	# Knop 1: Currency Cheat
	var btn_cur = Button.new()
	btn_cur.text = "GIVE ALL CURRENCIES (+1000)"
	btn_cur.pressed.connect(_cheat_currencies)
	vbox.add_child(btn_cur)
	
	# Knop 2: Speed Cheat Toggle
	btn_spd = Button.new()
	btn_spd.pressed.connect(_toggle_speed)
	vbox.add_child(btn_spd)
	
	# Knop 3: Damage Cheat Toggle
	btn_dmg = Button.new()
	btn_dmg.pressed.connect(_toggle_damage)
	vbox.add_child(btn_dmg)
	
	# Knop 4: Invincibility Toggle
	btn_inv = Button.new()
	btn_inv.pressed.connect(_toggle_invincibility)
	vbox.add_child(btn_inv)
	
	# Zet de knopteksten direct goed bij het opstarten
	_update_button_texts()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		debug_panel.visible = not debug_panel.visible
		if debug_panel.visible:
			_update_button_texts() # Ververs de status zodra je het menu opent
		get_viewport().set_input_as_handled()


func _update_button_texts() -> void:
	# Update de teksten live zodat je ziet wat aan of uit staat
	btn_spd.text = "SPEED BOOST: 2.0x [AAN]" if Game.debug_speed_multiplier > 1.0 else "SPEED BOOST: 1.0x [UIT]"
	btn_dmg.text = "DAMAGE BOOST: 5.0x [AAN]" if Game.debug_damage_multiplier > 1.0 else "DAMAGE BOOST: 1.0x [UIT]"
	btn_inv.text = "INVINCIBILITY: [AAN]" if Game.debug_is_invincible else "INVINCIBILITY: [UIT]"


func _cheat_currencies() -> void:
	var save_system = load("res://Systems/SaveSystem.gd").new()
	current_meta = save_system.get_loaded_meta_progress()
	
	current_meta.currency_1 += 1000
	current_meta.currency_2 += 1000
	current_meta.currency_3 += 1000
	current_meta.currency_4 += 1000
	current_meta.currency_5 += 1000
	current_meta.currency_6 += 1000
	
	save_system.save_meta_progress(current_meta)
	
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("update_skill_tree_visuals"):
		current_scene.current_meta = current_meta
		current_scene.update_skill_tree_visuals()
	print("GLOBAL DEBUG: Currencies bijgeschreven!")


func _toggle_speed() -> void:
	# Als hij al aanstond (2.0), zetten we hem terug naar normaal (1.0), en andersom!
	if Game.debug_speed_multiplier > 1.0:
		Game.debug_speed_multiplier = 1.0
	else:
		Game.debug_speed_multiplier = 2.0
	_update_button_texts()
	print("GLOBAL DEBUG: Speed multiplier gewijzigd naar: ", Game.debug_speed_multiplier)


func _toggle_damage() -> void:
	if Game.debug_damage_multiplier > 1.0:
		Game.debug_damage_multiplier = 1.0
	else:
		Game.debug_damage_multiplier = 5.0
	_update_button_texts()
	print("GLOBAL DEBUG: Damage multiplier gewijzigd naar: ", Game.debug_damage_multiplier)


func _toggle_invincibility() -> void:
	Game.debug_is_invincible = not Game.debug_is_invincible
	_update_button_texts()
	print("GLOBAL DEBUG: Invincibility staat nu op: ", Game.debug_is_invincible)
