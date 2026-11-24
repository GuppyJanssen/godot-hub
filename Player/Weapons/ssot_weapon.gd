class_name SsotWeapon
extends RefCounted
## SsotWeapon – alle waarden van één wapen, uitgerekend uit de SSOT.
##
## Een nieuw wapen is alleen een nieuwe rij in de sheet: hier hoeft geen code bij.
##
## Voorbeeld:
##   var pistol: SsotWeapon = SsotWeapon.from_ssot("weapon_pistol")
##   print(pistol.damage, " schade, elke ", pistol.fire_interval, " s")
##
## Kolommen die hij leest (leeg = de standaard die hieronder staat):
##   base_damage, base_fire_rate (tijd tussen schoten in seconden), base_fire_range,
##   base_bullet_speed, base_burst_count (kogels per schot), base_muzzle_count,
##   base_bullet_spread (graden), weapon_type ("auto" = full-auto), base_size,
##   base_pierce_count, base_bounce_count, base_knockback_force, base_recoil_force,
##   energy_cost_per_dps, base_damage_type, damage_type_2
## Bij elke base_-kolom mag ook een _modifier-kolom staan.

## De tijd tussen schoten komt nooit onder deze waarde, hoeveel skills er ook in zitten.
const MIN_FIRE_INTERVAL := 0.05

var id: String = ""
var ingame_name: String = ""
var damage: float = 1.0
var fire_interval: float = 0.5      # seconden tussen twee schoten
var weapon_range: float = 300.0
var projectile_speed: float = 600.0
var bullets_per_shot: int = 1
var muzzle_count: int = 1
var spread_degrees: float = 0.0
var full_auto: bool = false
var pierce_count: int = 0
var bounce_count: int = 0
var knockback_force: float = 0.0
var recoil_force: float = 0.0
var energy_cost_per_dps: float = 0.0
var damage_type: String = "kinetic"
var damage_type_2: String = ""
var size: float = 1.0


## Maakt een wapen uit een SSOT-rij.
## 'for_player' = true telt skills en items mee (Mods). Voor wapens van vijanden: false.
static func from_ssot(weapon_id: String, for_player: bool = true) -> SsotWeapon:
	var w: SsotWeapon = SsotWeapon.new()
	w.id = weapon_id
	if not Ssot.has_row(weapon_id):
		push_error("SsotWeapon: wapen '%s' staat niet in de SSOT." % weapon_id)
		return w

	w.ingame_name = Ssot.get_text(weapon_id, "ingame_name", weapon_id)
	w.damage = _stat(weapon_id, "damage", 1.0, for_player)
	w.fire_interval = maxf(MIN_FIRE_INTERVAL, _stat(weapon_id, "fire_rate", 0.5, for_player))
	w.weapon_range = _stat(weapon_id, "fire_range", 300.0, for_player)
	w.projectile_speed = _stat(weapon_id, "bullet_speed", 700.0, for_player)
	w.pierce_count = roundi(_stat(weapon_id, "pierce_count", 0.0, for_player))
	w.bounce_count = roundi(_stat(weapon_id, "bounce_count", 0.0, for_player))
	w.knockback_force = _stat(weapon_id, "knockback_force", 0.0, for_player)
	w.recoil_force = _stat(weapon_id, "recoil_force", 0.0, for_player)
	w.energy_cost_per_dps = _stat(weapon_id, "energy_cost_per_dps", 0.0, for_player)

	w.size = _stat(weapon_id, "size", 1.0, for_player)
	w.bullets_per_shot = maxi(1, roundi(_stat(weapon_id, "burst_count", 1.0, for_player)))
	w.muzzle_count = maxi(1, roundi(_stat(weapon_id, "muzzle_count", 1.0, for_player)))
	# Spreiding telt skills mee: zo kan een accuracy-skill hem later kleiner maken.
	w.spread_degrees = maxf(0.0, _stat(weapon_id, "bullet_spread", 0.0, for_player))
	w.full_auto = Ssot.get_text(weapon_id, "weapon_type", "").strip_edges().to_lower() == "auto"
	w.damage_type = Ssot.get_text(weapon_id, "base_damage_type", "kinetic")
	w.damage_type_2 = Ssot.get_text(weapon_id, "damage_type_2", "")

	# Een skill kan een wapen full-auto maken (Bereik + full-auto op 100%):
	# zet daarvoor in Mods een vaste bonus van 1 op de stat "full_auto".
	if for_player and Mods.flat_total("full_auto") >= 1.0:
		w.full_auto = true
	return w


## Schade per schot, alle kogels en lopen samen.
func damage_per_shot() -> float:
	return damage * bullets_per_shot * muzzle_count


## Schade per seconde bij continu vuren.
func dps() -> float:
	return damage_per_shot() / fire_interval


## Energie per schot. Omdat de prijs per DPS geldt, betaalt een snel wapen per schot minder
## en per seconde evenveel als een traag wapen met dezelfde DPS.
func energy_per_shot() -> float:
	return energy_cost_per_dps * damage_per_shot()


## Alles wat een kogel moet weten, als Dictionary. Dit gaat naar de kogel bij het schieten.
func bullet_data() -> Dictionary:
	return {
		"weapon_id": id,
		"damage": damage,
		"speed": projectile_speed,
		"range": weapon_range,
		"pierce_count": pierce_count,
		"bounce_count": bounce_count,
		"knockback_force": knockback_force,
		"damage_type": damage_type,
		"damage_type_2": damage_type_2,
	}


static func _stat(weapon_id: String, stat: String, fallback: float, for_player: bool) -> float:
	if for_player:
		return StatCalc.player_value(weapon_id, stat, fallback)
	return StatCalc.value(weapon_id, stat, fallback)
