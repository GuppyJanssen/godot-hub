class_name EnemyGun
## EnemyGun – wapens voor vijanden (commando's): welk wapen, schieten en laten vallen.
##
## SSOT:
##   weapon_pool                  op de FACTIE-rij: wapens waaruit een vijand van deze factie kiest,
##                                entry_id's met / ertussen (weapon_pistol/weapon_shotgun). Leeg = geen wapen.
##   uses_weapon                  op de TYPE-rij (of eigen vijand-rij): 1 = dit type krijgt een wapen
##                                uit de pool (commando), 0 of leeg = niet.
##   weapon_drop_chance           op de TYPE-rij: kans dat het wapen valt als hij sterft, 0 t/m 1.
##   weapon_fire_interval_factor  op de TYPE-rij: zoveel keer trager dan de speler met hetzelfde wapen
##                                schiet. 2 = half zo vaak. Leeg = 2.
##
## Ontwikkelaarsnotities:
## - Het gekozen wapen wordt bewaard met de vijand (test_body.gd, get_run_state), zodat een commando
##   na het terugkomen in een kamer hetzelfde wapen heeft.
## - Kogels zijn de gewone weapon_output-kogels met from_enemy = true.

const BULLET_SCENE := "res://Entities/Weapon Output/weapon_output.tscn"
const DEFAULT_FIRE_FACTOR := 2.0


## Krijgt dit type een wapen?
static func uses_weapon(faction: String, unit_type: String) -> bool:
	return faction != "" and EnemyStats.value(faction, unit_type, "uses_weapon", 0.0) > 0.0


## Kiest een willekeurig wapen uit de pool van de factie. "" als de pool leeg is.
static func pick_weapon(faction: String) -> String:
	var pool: Array = []
	for part in Ssot.get_text(EnemyStats.faction_row(faction), "weapon_pool", "").split("/"):
		var id: String = part.strip_edges()
		if id == "":
			continue
		if Ssot.has_row(id):
			pool.append(id)
		else:
			push_warning("EnemyGun: wapen '%s' uit weapon_pool van factie %s staat niet in de SSOT." % [id, faction])
	return "" if pool.is_empty() else pool[randi() % pool.size()]


## Seconden tussen twee schoten van deze vijand met dit wapen.
static func fire_interval(weapon: SsotWeapon, faction: String, unit_type: String) -> float:
	var factor: float = EnemyStats.value(faction, unit_type, "weapon_fire_interval_factor", DEFAULT_FIRE_FACTOR)
	return maxf(0.05, weapon.fire_interval * maxf(factor, 0.1))


## Schiet één salvo vanaf 'shooter' richting 'target_pos'.
static func fire(shooter: Node2D, weapon: SsotWeapon, target_pos: Vector2, muzzle_distance: float) -> void:
	var scene: PackedScene = load(BULLET_SCENE)
	var parent: Node = shooter.get_tree().current_scene
	if scene == null or parent == null:
		return
	var aim: float = (target_pos - shooter.global_position).angle()
	for i in maxi(1, weapon.bullets_per_shot):
		var bullet = scene.instantiate()
		bullet.from_enemy = true
		bullet.damage = weapon.damage
		bullet.size_scale = weapon.size
		bullet.speed = weapon.projectile_speed
		bullet.damage_type = weapon.damage_type
		bullet.range_override = weapon.weapon_range
		bullet.pierce_left = weapon.pierce_count
		bullet.bounce_left = weapon.bounce_count
		bullet.knockback_force = weapon.knockback_force
		bullet.explosion_damage = weapon.explosion_damage
		bullet.explosion_radius = weapon.explosion_radius
		var spread: float = deg_to_rad(randf_range(-weapon.spread_degrees, weapon.spread_degrees))
		bullet.global_rotation = aim + spread
		bullet.global_position = shooter.global_position + Vector2.from_angle(aim) * muzzle_distance
		bullet.modulate = Color(1.0, 0.55, 0.45)  # vijandkogels iets roder, zodat je ze herkent
		if "velocity" in shooter and shooter.velocity is Vector2:
			bullet.shooter_velocity = shooter.velocity
		parent.add_child(bullet)
