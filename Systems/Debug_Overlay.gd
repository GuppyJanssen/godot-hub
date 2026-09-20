extends CanvasLayer

var debug_panel: Panel
var current_meta = null

# Bestaande cheats
var btn_dmg: Button
var btn_inv: Button
var btn_auto: Button
var btn_rate: Button
var btn_range: Button
var btn_mag: Button
var btn_bsize: Button
var btn_bspeed: Button

# DRIE APARTE ACCELERATIE (MEEEAAAUUWW) KNOPPEN
var btn_acc_x1: Button
var btn_acc_x4: Button
var btn_acc_x10: Button

# TWEE APARTE MAX SPEED (MEER SPEED) KNOPPEN
var btn_max_x1: Button
var btn_max_x10: Button

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	debug_panel = Panel.new()
	debug_panel.size = Vector2(340, 600) # Paneel op 600 gezet voor alle knoppen
	debug_panel.position = Vector2(20, 20)
	debug_panel.visible = false
	add_child(debug_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	debug_panel.add_child(vbox)
	
	# Knop 1: Currency Cheat
	var btn_cur = Button.new()
	btn_cur.text = "We're Rich!"
	btn_cur.pressed.connect(_cheat_currencies)
	vbox.add_child(btn_cur)
	
	# --- ACCELERATIE (MEEEAAAUUWW) KNOPPEN ---
	btn_acc_x1 = Button.new()
	btn_acc_x1.pressed.connect(func(): Game.debug_acceleration_multiplier = 1.0; _update_button_texts())
	vbox.add_child(btn_acc_x1)
	
	btn_acc_x4 = Button.new()
	btn_acc_x4.pressed.connect(func(): Game.debug_acceleration_multiplier = 4.0; _update_button_texts())
	vbox.add_child(btn_acc_x4)
	
	btn_acc_x10 = Button.new()
	btn_acc_x10.pressed.connect(func(): Game.debug_acceleration_multiplier = 10.0; _update_button_texts())
	vbox.add_child(btn_acc_x10)
	
	# --- MAX SPEED (MEER SPEED) KNOPPEN ---
	btn_max_x1 = Button.new()
	btn_max_x1.pressed.connect(func(): Game.debug_max_speed_multiplier = 1.0; _update_button_texts())
	vbox.add_child(btn_max_x1)
	
	btn_max_x10 = Button.new()
	btn_max_x10.pressed.connect(func(): Game.debug_max_speed_multiplier = 10.0; _update_button_texts())
	vbox.add_child(btn_max_x10)
	
	# Rest van de gevechtsknoppen
	btn_dmg = Button.new()
	btn_dmg.pressed.connect(_toggle_damage)
	vbox.add_child(btn_dmg)
	
	btn_inv = Button.new()
	btn_inv.pressed.connect(_toggle_invincibility)
	vbox.add_child(btn_inv)
	
	btn_auto = Button.new()
	btn_auto.pressed.connect(_toggle_full_auto)
	vbox.add_child(btn_auto)
	
	btn_rate = Button.new()
	btn_rate.pressed.connect(_cycle_fire_rate)
	vbox.add_child(btn_rate)
	
	btn_range = Button.new()
	btn_range.pressed.connect(_cycle_weapon_range)
	vbox.add_child(btn_range)
	
	btn_mag = Button.new()
	btn_mag.pressed.connect(_toggle_loot_magnet)
	vbox.add_child(btn_mag)
	
	btn_bsize = Button.new()
	btn_bsize.pressed.connect(_cycle_bullet_size)
	vbox.add_child(btn_bsize)
	
	btn_bspeed = Button.new()
	btn_bspeed.pressed.connect(_cycle_bullet_speed)
	vbox.add_child(btn_bspeed)
	
	_update_button_texts()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		debug_panel.visible = not debug_panel.visible
		if debug_panel.visible:
			_update_button_texts()
		get_viewport().set_input_as_handled()


func _update_button_texts() -> void:
	# Update de MEEEAAAUUWW (Acceleratie) knoppen
	btn_acc_x1.text = "MEEEAAAUUWW: 1x (Normaal) [AAN]" if Game.debug_acceleration_multiplier == 1.0 else "MEEEAAAUUWW: 1x"
	btn_acc_x4.text = "MEEEAAAUUWW: 4x [AAN]" if Game.debug_acceleration_multiplier == 4.0 else "MEEEAAAUUWW: 4x"
	btn_acc_x10.text = "MEEEAAAUUWW: 10x [AAN]" if Game.debug_acceleration_multiplier == 10.0 else "MEEEAAAUUWW: 10x"
	
	# Update de MEER SPEED (Max Speed) knoppen
	btn_max_x1.text = "MEER SPEED: 1x (Normaal) [AAN]" if Game.debug_max_speed_multiplier == 1.0 else "MEER SPEED: 1x"
	btn_max_x10.text = "MEER SPEED: 10x (SONIC) [AAN]" if Game.debug_max_speed_multiplier == 10.0 else "MEER SPEED: 10x"
	
	btn_dmg.text = "ONE PUNCH! [AAN]" if Game.debug_damage_multiplier > 1.0 else "ONE PUNCH! [UIT]"
	btn_inv.text = "INVINCIBILE: [AAN]" if Game.debug_is_invincible else "INVINCIBILE: [UIT]"
	
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and "active_weapon_data" in player and player.active_weapon_data:
		var w_data = player.active_weapon_data
		btn_auto.text = "WEAPON MODE: [FULL-AUTO]" if w_data.is_full_auto else "WEAPON MODE: [SEMI-AUTO]"
		btn_rate.text = "BASE FIRE RATE: " + str(w_data.base_fire_rate) + "s"
		btn_range.text = "WEAPON RANGE: " + str(w_data.weapon_range) + "px"
		btn_bsize.text = "BULLET SIZE: " + str(w_data.size_multiplier) + "x"
		btn_bspeed.text = "BULLET SPEED: " + str(w_data.speed) + " px/s"
		
	if player and "stats" in player and player.stats:
		btn_mag.text = "LOOT MAGNET: [AAN]" if player.stats.loot_magnet_applied else "LOOT MAGNET: [UIT]"


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
	_update_button_texts()

func _toggle_damage() -> void:
	Game.debug_damage_multiplier = 1.0 if Game.debug_damage_multiplier > 1.0 else 5.0
	_update_button_texts()

func _toggle_invincibility() -> void:
	Game.debug_is_invincible = not Game.debug_is_invincible
	_update_button_texts()

func _toggle_full_auto() -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and "active_weapon_data" in player and player.active_weapon_data:
		player.active_weapon_data.is_full_auto = not player.active_weapon_data.is_full_auto
	_update_button_texts()

func _cycle_fire_rate() -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and "active_weapon_data" in player and player.active_weapon_data:
		var w_data = player.active_weapon_data
		w_data.base_fire_rate = 0.1 if w_data.base_fire_rate == 0.3 else (0.03 if w_data.base_fire_rate == 0.1 else (1.0 if w_data.base_fire_rate == 0.03 else 0.3))
	_update_button_texts()

func _cycle_weapon_range() -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and "active_weapon_data" in player and player.active_weapon_data:
		var w_data = player.active_weapon_data
		w_data.weapon_range = 200.0 if w_data.weapon_range == 600.0 else (2000.0 if w_data.weapon_range == 200.0 else 600.0)
	_update_button_texts()

func _toggle_loot_magnet() -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and "stats" in player and player.stats:
		player.stats.loot_magnet_applied = not player.stats.loot_magnet_applied
	_update_button_texts()

func _cycle_bullet_size() -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and "active_weapon_data" in player and player.active_weapon_data:
		var w_data = player.active_weapon_data
		w_data.size_multiplier = 3.0 if w_data.size_multiplier == 1.0 else (0.3 if w_data.size_multiplier == 3.0 else 1.0)
	_update_button_texts()

func _cycle_bullet_speed() -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and "active_weapon_data" in player and player.active_weapon_data:
		var w_data = player.active_weapon_data
		w_data.speed = 200.0 if w_data.speed == 700.0 else (2500.0 if w_data.speed == 200.0 else 700.0)
	_update_button_texts()
