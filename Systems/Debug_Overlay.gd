extends CanvasLayer
# BEDIENING: Het Ultieme Gecentraliseerde Global Master Dashboard Panel

var panel: PanelContainer
var vbox: VBoxContainer
var seed_label: Label = null
var _seed_label_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 100
	_build_debug_ui()

# Het seed-label wordt een paar keer per seconde ververst, zodat het klopt na een kamerwissel.
func _process(delta: float) -> void:
	if not visible:
		return
	_seed_label_timer -= delta
	if _seed_label_timer <= 0.0:
		_seed_label_timer = 0.25
		_refresh_seed_label()


# Seed, kamer, wie de kamer bezet (de fabrieken die er staan) en wie hem nu in de oorlog bezit.
func _refresh_seed_label() -> void:
	if not is_instance_valid(seed_label):
		return
	var ring: int = LevelManager.current_layer
	var room: int = LevelManager.current_room_index
	var war_owner: String = FactionWar.get_room_owner(ring, room)
	var pop_owner: String = str(RunState.get_room_change(ring, room, "pop_owner", ""))
	if RunState.is_cleared(ring, room):
		pop_owner = ""
	seed_label.text = "Seed: %d  |  Ring %d, kamer %d\nBezet door: %s  |  Oorlog nu: %s" % [
		RunState.run_seed, ring, room,
		_faction_label(pop_owner), _faction_label(war_owner)]


# "a" -> "a (Organic)", "" -> "leeg".
func _faction_label(faction: String) -> String:
	if faction == "":
		return "leeg"
	var label: String = Ssot.get_text(EnemyStats.faction_row(faction), "ingame_name", "")
	return faction + (" (" + label + ")" if label != "" else "")


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
	
	# Seed van de run en wie deze kamer in de factie-oorlog bezit (handig om een seed te testen).
	seed_label = Label.new()
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(seed_label)
	_refresh_seed_label()
	
	var current_auto_raw = 0.0
	# GECORRIGEERD: We pakken direct de wereldwijde actieve speler!
	if is_instance_valid(Game) and Game.active_player:
		current_auto_raw = float(Game.active_player.current_weapon_stats.get("is_full_auto", 0.0))

	_add_dashboard_row("God Mode", "Geen schade/energie", "Toggle: " + ("AAN" if Game.debug_is_invincible else "UIT"), _toggle_invincible)
	_add_dashboard_row("Refill", "HP, schild, energie", "Alles vol", _refill_player)
	_add_dashboard_row("Oorlogskaart", "Factie-oorlog", "Kaart: " + ("AAN" if _war_map_visible() else "UIT"), _toggle_war_map)
	_add_dashboard_row("Oorlog tempo", "Tijd versnellen", "Snelheid: [" + str(FactionWar.debug_time_scale) + "x]", _cycle_war_speed)
	_add_dashboard_row("One Punch", "Status: Live", "Toggle: " + ("AAN" if Game.debug_damage_multiplier > 1.0 else "UIT"), _toggle_damage)
	_add_dashboard_row("Weapon Mode", "Stand", "Toggle: [" + ("AUTO" if current_auto_raw > 0.5 else "SEMI") + "]", _toggle_weapon_mode)
	_add_dashboard_row("Mirror Spawn", "Transitielogica", "Modus: [" + ("MIRROR" if Game.debug_use_mirror_spawn else "CENTER") + "]", _toggle_mirror_spawn)
	
	_add_dashboard_row("Max Speed", "Multiplier", "Mult: [" + str(Game.debug_max_speed_multiplier) + "x]", _cycle_max_speed)
	_add_dashboard_row("Acceleration", "Multiplier", "Mult: [" + str(Game.debug_acceleration_multiplier) + "x]", _cycle_accel)
	_add_dashboard_row("Friction", "Multiplier", "Mult: [" + str(Game.debug_friction_multiplier) + "x]", _cycle_friction)
	
	_add_dashboard_row("Bullet Speed", "Multiplier", "Mult: [" + str(Game.debug_bullet_speed_multiplier) + "x]", _cycle_bullet_speed)
	_add_dashboard_row("Bullet Size", "Multiplier", "Mult: [" + str(Game.debug_bullet_size_multiplier) + "x]", _cycle_bullet_size)
	_add_dashboard_row("Weapon Range", "Multiplier", "Mult: [" + str(Game.debug_range_multiplier) + "x]", _cycle_range)
	_add_dashboard_row("Muzzles Spawn", "Live Aantal", "Aantal: [" + ("SSOT" if Game.debug_muzzle_count <= 0 else str(Game.debug_muzzle_count)) + "]", _cycle_muzzles)

	# Wapens: elk wapen uit de SSOT als knop. Het wapen komt naast de speler op de grond te liggen,
	# zodat je het oppakken en ruilen (alle vier de vakken vol = E) kunt testen.
	var weapons_label = Label.new()
	weapons_label.text = "--- WAPENS (op de grond naast je) ---"
	weapons_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(weapons_label)
	var weapons_grid = GridContainer.new()
	weapons_grid.columns = 3
	vbox.add_child(weapons_grid)
	for weapon_id in Ssot.get_ids("weapon_base"):
		var btn_weapon = Button.new()
		btn_weapon.text = Ssot.get_text(weapon_id, "ingame_name", weapon_id)
		btn_weapon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_weapon.pressed.connect(_spawn_weapon.bind(str(weapon_id)))
		weapons_grid.add_child(btn_weapon)

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

# Legt een wapen naast de speler op de grond (F1-knop).
func _spawn_weapon(weapon_id: String) -> void:
	var player = Game.active_player
	if not is_instance_valid(player):
		return
	WeaponPickup.spawn(get_tree().current_scene, weapon_id, player.global_position + Vector2(90, 0))


# Zet HP, schild en energie van de speler op maximaal.
func _refill_player() -> void:
	var player = Game.active_player
	if not is_instance_valid(player) or not player.stats:
		return
	player.stats.current_health = player.stats.max_health
	player.stats.current_shield = player.stats.max_shield
	player.stats.current_energy = player.stats.max_energy
	Game.set_meta("transit_health", player.stats.current_health)
	Game.set_meta("transit_shield", player.stats.current_shield)
	Game.set_meta("transit_energy", player.stats.current_energy)
	print("F1: HP, schild en energie bijgevuld.")


# De kaart van de factie-oorlog (FactionWarMap, ook met F2). Bestaat alleen in de editor en debug-exports.
func _war_map() -> Node:
	return get_node_or_null("/root/FactionWarMap")


func _war_map_visible() -> bool:
	var war_map: Node = _war_map()
	return war_map != null and war_map.visible


func _toggle_war_map() -> void:
	var war_map: Node = _war_map()
	if war_map != null:
		war_map.toggle()
	_update_dashboard()


# Oorlog sneller laten lopen: 1x, 10x, 60x (net als F3 op de kaart).
func _cycle_war_speed() -> void:
	var war_map: Node = _war_map()
	if war_map != null:
		war_map.cycle_speed()
	else:
		FactionWar.debug_time_scale = 1.0 if FactionWar.debug_time_scale >= 60.0 else (60.0 if FactionWar.debug_time_scale >= 10.0 else 10.0)
	_update_dashboard()


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
func _cycle_range() -> void: _cycle_multiplier("debug_range_multiplier")

func _cycle_multiplier(prop_name: String) -> void:
	var cur = float(Game.get(prop_name))
	if cur == 0.3: Game.set(prop_name, 1.0)
	elif cur == 1.0: Game.set(prop_name, 2.0)
	elif cur == 2.0: Game.set(prop_name, 5.0)
	elif cur == 5.0: Game.set(prop_name, 10.0)
	else: Game.set(prop_name, 0.3)
	_update_dashboard()

func _cycle_muzzles() -> void:
	# 0 = SSOT (het wapen bepaalt het), daarna 1, 2, 4 en weer terug naar SSOT.
	var cur = int(Game.debug_muzzle_count)
	if cur == 0: Game.debug_muzzle_count = 1
	elif cur == 1: Game.debug_muzzle_count = 2
	elif cur == 2: Game.debug_muzzle_count = 4
	else: Game.debug_muzzle_count = 0
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
