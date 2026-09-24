extends CanvasLayer
# BEDIENING: Het Ultieme Gecentraliseerde Global Master Dashboard Panel

var panel: PanelContainer
var vbox: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 100
	_build_debug_ui()

func _unhandled_input(event: InputEvent) -> void:
	# GECORRIGEERD: Luistert STRIKT en alleen naar de fysieke F1-toets. Sluit Esc-overlaps volledig uit!
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		visible = not visible
		get_viewport().set_input_as_handled()
		if visible:
			_update_dashboard()

func _build_debug_ui() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(50, 50)
	panel.custom_minimum_size = Vector2(500, 650)
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	_update_dashboard()

func _update_dashboard() -> void:
	for child in vbox.get_children():
		child.queue_free()
		
	var title = Label.new()
	title.text = "=== SSoT LIVE PHYSICS DASHBOARD ==="
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var current_auto_raw = 0.0
	# GECORRIGEERD: We pakken direct de wereldwijde actieve speler!
	if is_instance_valid(Game) and Game.active_player:
		current_auto_raw = float(Game.active_player.current_weapon_stats.get("is_full_auto", 0.0))

	_add_dashboard_row("God Mode", "Status: Live", "Toggle: " + ("AAN" if Game.debug_is_invincible else "UIT"), _toggle_invincible)
	_add_dashboard_row("One Punch", "Status: Live", "Toggle: " + ("AAN" if Game.debug_damage_multiplier > 1.0 else "UIT"), _toggle_damage)
	_add_dashboard_row("Weapon Mode", "Stand", "Toggle: [" + ("AUTO" if current_auto_raw > 0.5 else "SEMI") + "]", _toggle_weapon_mode)
	_add_dashboard_row("Mirror Spawn", "Transitielogica", "Modus: [" + ("MIRROR" if Game.debug_use_mirror_spawn else "CENTER") + "]", _toggle_mirror_spawn)
	
	_add_dashboard_row("Max Speed", "Multiplier", "Mult: [" + str(Game.debug_max_speed_multiplier) + "x]", _cycle_max_speed)
	_add_dashboard_row("Acceleration", "Multiplier", "Mult: [" + str(Game.debug_acceleration_multiplier) + "x]", _cycle_accel)
	_add_dashboard_row("Friction", "Multiplier", "Mult: [" + str(Game.debug_friction_multiplier) + "x]", _cycle_friction)
	
	_add_dashboard_row("Bullet Speed", "Multiplier", "Mult: [" + str(Game.debug_bullet_speed_multiplier) + "x]", _cycle_bullet_speed)
	_add_dashboard_row("Bullet Size", "Multiplier", "Mult: [" + str(Game.debug_bullet_size_multiplier) + "x]", _cycle_bullet_size)
	_add_dashboard_row("Muzzles Spawn", "Live Aantal", "Aantal: [" + str(Game.debug_muzzle_count) + "]", _cycle_muzzles)

	var money_label = Label.new()
	money_label.text = "--- ECONOMIE CHEATS ---"
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(money_label)
	
	var econ_hbox = HBoxContainer.new()
	vbox.add_child(econ_hbox)
	
	var btn_rich = Button.new()
	btn_rich.text = "💰 WE'RE RICH! (9999)"
	btn_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_rich.pressed.connect(_make_rich)
	econ_hbox.add_child(btn_rich)
	
	var btn_del_money = Button.new()
	btn_del_money.text = "🗑️ RESET TO 0"
	btn_del_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_del_money.pressed.connect(_reset_money)
	econ_hbox.add_child(btn_del_money)

func _add_dashboard_row(label_name: String, status_text: String, button_text: String, click_callable: Callable) -> void:
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	var lbl_title = Label.new()
	lbl_title.text = label_name + ":"
	lbl_title.custom_minimum_size = Vector2(110, 0)
	hbox.add_child(lbl_title)
	
	var lbl_status = Label.new()
	lbl_status.text = status_text
	lbl_status.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(lbl_status)
	
	var btn = Button.new()
	btn.text = button_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(click_callable)
	hbox.add_child(btn)

func _toggle_invincible() -> void:
	Game.debug_is_invincible = not Game.debug_is_invincible
	_update_dashboard()

func _toggle_mirror_spawn() -> void:
	Game.debug_use_mirror_spawn = not Game.debug_use_mirror_spawn
	print("F1 SANDBOX: Mirror Spawn gewijzigd naar: ", Game.debug_use_mirror_spawn)
	_update_dashboard()

func _toggle_damage() -> void:
	Game.debug_damage_multiplier = 9999.0 if Game.debug_damage_multiplier == 1.0 else 1.0
	_update_dashboard()

func _toggle_weapon_mode() -> void:
	# GECORRIGEERD: Klapt de modus direct om in de wereldwijd geregistreerde speler!
	if is_instance_valid(Game) and Game.active_player:
		var current_raw = float(Game.active_player.current_weapon_stats.get("is_full_auto", 0.0))
		Game.active_player.current_weapon_stats["is_full_auto"] = 1.0 if current_raw < 0.5 else 0.0
	_update_dashboard()

func _cycle_max_speed() -> void: _cycle_multiplier("debug_max_speed_multiplier")
func _cycle_accel() -> void: _cycle_multiplier("debug_acceleration_multiplier")
func _cycle_friction() -> void: _cycle_multiplier("debug_friction_multiplier")
func _cycle_bullet_speed() -> void: _cycle_multiplier("debug_bullet_speed_multiplier")
func _cycle_bullet_size() -> void: _cycle_multiplier("debug_bullet_size_multiplier")

func _cycle_multiplier(prop_name: String) -> void:
	var cur = float(Game.get(prop_name))
	if cur == 0.3: Game.set(prop_name, 1.0)
	elif cur == 1.0: Game.set(prop_name, 2.0)
	elif cur == 2.0: Game.set(prop_name, 5.0)
	elif cur == 5.0: Game.set(prop_name, 10.0)
	else: Game.set(prop_name, 0.3)
	_update_dashboard()

func _cycle_muzzles() -> void:
	var cur = int(Game.debug_muzzle_count)
	if cur == 14: Game.debug_muzzle_count = 1
	elif cur == 1: Game.debug_muzzle_count = 2
	elif cur == 2: Game.debug_muzzle_count = 4
	else: Game.debug_muzzle_count = 14
	_update_dashboard()

func _make_rich() -> void: _set_money_values(9999)
func _reset_money() -> void: _set_money_values(0)

func _set_money_values(target_amount: int) -> void:
	# 1. Schrijf keihard naar de centrale basis-resource op de schijf
	var p_data = load("res://Resources/Player_Data.tres")
	if p_data:
		p_data.currency_olrite = target_amount
		p_data.currency_metal = target_amount
		p_data.currency_keepium = target_amount
		p_data.currency_element1 = target_amount
		p_data.currency_element2 = target_amount
		p_data.currency_element3 = target_amount
		
	# 2. GECORRIGEERD: Overschrijf direct de actieve buffers EN de live-resource van het schip
	if is_instance_valid(Game) and Game.active_player:
		var p = Game.active_player
		p.run_currency_olrite = target_amount
		p.run_currency_metal = target_amount
		p.run_currency_keepium = target_amount
		p.run_currency_element1 = target_amount
		p.run_currency_element2 = target_amount
		p.run_currency_element3 = target_amount
		
		# SSSoT WATERDICHT GUARD: Brand de waarden direct in elkaars actieve registers!
		if p.stats:
			p.stats.currency_olrite = target_amount
			p.stats.currency_metal = target_amount
			p.stats.currency_keepium = target_amount
			p.stats.currency_element1 = target_amount
			p.stats.currency_element2 = target_amount
			p.stats.currency_element3 = target_amount
			
			# FORCEER DIRECT: Vertel de ResourceSaver van Godot dat hij deze data NU moet opslaan!
			ResourceSaver.save(p.stats, "res://Resources/Player_Data.tres")

	# 3. Overschrijf ook direct de Meta-Save voor het Skill Tree menu
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var meta = save_system.get_loaded_meta_progress()
	if meta:
		meta.currency_1 = target_amount
		meta.currency_2 = target_amount
		meta.currency_3 = target_amount
		meta.currency_4 = target_amount
		meta.currency_5 = target_amount
		meta.currency_6 = target_amount
		save_system.save_meta_progress(meta)
		
	_force_hud_refresh()
	_update_dashboard()


func _force_hud_refresh() -> void:
	var active_hud = get_tree().current_scene.find_child("*hud*", true, false)
	if not active_hud: active_hud = get_tree().root.find_child("*hud*", true, false)
	if active_hud and active_hud.has_method("_ready"):
		active_hud._ready()
