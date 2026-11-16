class_name WeaponShooter
extends Node2D
## WeaponShooter – vuurt elk wapen uit de SSOT af: pistool, gatling, shotgun en alles wat nog komt.
##
## Zet deze Node2D als kind op het schip, op de plek van de loop. Hij schiet naar rechts
## (de +X-richting van deze node), dus draai hem mee met het schip.
##
## In de Inspector:
## - Weapon Id   : het id van de rij in de SSOT, bijvoorbeeld "weapon_pistol"
## - Bullet Scene: de scene van de kogel
## - Muzzles     : (optioneel) Marker2D's waar de kogels uit komen. Leeg = deze node zelf.
##                 Dit is de haak voor de ship designer: andere muzzles = ander schip.
##
## In de speler:
##   func _physics_process(delta):
##       shooter.try_fire(Input.is_action_just_pressed("shoot"), Input.is_action_pressed("shoot"))
##
## De kogel krijgt zijn waarden via een functie setup(data: Dictionary), als hij die heeft.
## Wat er in 'data' zit, staat in SsotWeapon.bullet_data().

## Na elk schot. 'recoil' is de terugslag (richting × kracht), 'energy_cost' de energie die het kost.
signal fired(recoil: Vector2, energy_cost: float)

@export var weapon_id: String = "weapon_pistol"
@export var bullet_scene: PackedScene
@export var muzzles: Array[Marker2D] = []
## Uit = wapen van een vijand: skills en items van de speler tellen dan niet mee.
@export var for_player: bool = true

var weapon: SsotWeapon
var _cooldown: float = 0.0


func _ready() -> void:
	reload_weapon()
	# Verandert er een skill of item, dan rekent het wapen zijn waarden opnieuw uit.
	if for_player:
		Mods.changed.connect(reload_weapon)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


## Wissel van wapen.
func set_weapon(new_weapon_id: String) -> void:
	weapon_id = new_weapon_id
	reload_weapon()


## Haalt de waarden opnieuw uit de SSOT.
func reload_weapon() -> void:
	weapon = SsotWeapon.from_ssot(weapon_id, for_player)


## Kan er nu geschoten worden?
func can_fire() -> bool:
	return _cooldown <= 0.0 and weapon != null and bullet_scene != null


## Probeert te schieten. Geeft true terug als er geschoten is.
## - just_pressed: de knop is dit frame ingedrukt
## - held        : de knop wordt vastgehouden
## Een semi-auto wapen schiet alleen bij just_pressed, een full-auto wapen ook bij held.
func try_fire(just_pressed: bool, held: bool) -> bool:
	if not can_fire():
		return false
	var wants_to_fire: bool = just_pressed or (held and weapon.full_auto)
	if not wants_to_fire:
		return false
	fire()
	return true


## Schiet meteen, zonder op de knop te letten (voor vijanden en geschut).
func fire() -> void:
	if weapon == null or bullet_scene == null:
		return
	_cooldown = weapon.fire_interval

	var spread: float = deg_to_rad(weapon.spread_degrees)
	for muzzle_index in weapon.muzzle_count:
		var muzzle: Node2D = _muzzle(muzzle_index)
		for bullet_index in weapon.bullets_per_shot:
			var angle: float = muzzle.global_rotation
			if weapon.bullets_per_shot > 1:
				# Meerdere kogels: netjes verdeeld over de spreiding (shotgun).
				var t: float = float(bullet_index) / float(weapon.bullets_per_shot - 1)
				angle += lerpf(-spread / 2.0, spread / 2.0, t)
			elif spread > 0.0:
				# Eén kogel met spreiding: een beetje willekeurig.
				angle += randf_range(-spread / 2.0, spread / 2.0)
			_spawn_bullet(muzzle.global_position, angle)

	var recoil: Vector2 = -Vector2.from_angle(global_rotation) * weapon.recoil_force
	fired.emit(recoil, weapon.energy_per_shot())


func _muzzle(index: int) -> Node2D:
	if muzzles.is_empty():
		return self
	var marker: Marker2D = muzzles[index % muzzles.size()]
	if marker == null:
		return self
	return marker


func _spawn_bullet(spawn_position: Vector2, angle: float) -> void:
	var bullet: Node = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	if bullet is Node2D:
		var bullet_2d: Node2D = bullet
		bullet_2d.global_position = spawn_position
		bullet_2d.global_rotation = angle

	var data: Dictionary = weapon.bullet_data()
	data["direction"] = Vector2.from_angle(angle)
	data["from_player"] = for_player
	if bullet.has_method("setup"):
		bullet.call("setup", data)
