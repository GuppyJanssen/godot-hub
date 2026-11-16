class_name StatCalc
## StatCalc – één formule voor ALLE stats.
##
## Geen autoload nodig: roep de functies direct aan, bijvoorbeeld
##   var snelheid: float = StatCalc.player_value("player", "speed")
##   var hp: float       = StatCalc.value("enemy_grunt", "max_health")
##
## De formule (modifiers als percentage, 0 = neutraal):
##   eindwaarde = (base_x + vaste bonussen) × (1 + x_modifier + procentuele bonussen)
##
## - base_x en x_modifier komen uit de SSOT-rij.
## - Vaste en procentuele bonussen komen uit Mods (skills, run-items, effecten).
## - Bestaat er geen kolom base_x, dan wordt de kolom x zonder voorvoegsel geprobeerd.

## Open vraag met Maik: percentage (0 = neutraal) of vermenigvuldiger (1 = neutraal)?
## Zet op false als jullie voor vermenigvuldigers kiezen. Dan is de formule:
##   eindwaarde = (base_x + vaste bonussen) × x_modifier × (1 + procentuele bonussen)
const MODIFIER_IS_PERCENTAGE := true


## Waarde uit de SSOT, zonder skills of items. Voor vijanden, wapens van vijanden, de wereld.
static func value(row_id: String, stat: String, fallback: float = 0.0) -> float:
	return _calculate(row_id, stat, fallback, false)


## Waarde uit de SSOT, MET alles wat in Mods staat. Voor de speler en zijn wapens.
static func player_value(row_id: String, stat: String, fallback: float = 0.0) -> float:
	return _calculate(row_id, stat, fallback, true)


## Zoals player_value, maar nooit lager dan 'minimum'.
## Gebruik dit voor waarden die niet onder nul mogen komen, zoals de tijd tussen schoten.
static func player_value_min(row_id: String, stat: String, minimum: float, fallback: float = 0.0) -> float:
	return maxf(minimum, _calculate(row_id, stat, fallback, true))


## Geldt deze stat voor deze rij? (Leeg in de SSOT = nee.)
static func applies(row_id: String, stat: String) -> bool:
	return Ssot.has_value(row_id, "base_" + stat) or Ssot.has_value(row_id, stat)


static func _calculate(row_id: String, stat: String, fallback: float, with_mods: bool) -> float:
	var base: float = fallback
	if Ssot.has_value(row_id, "base_" + stat):
		base = Ssot.get_number(row_id, "base_" + stat, fallback)
	elif Ssot.has_value(row_id, stat):
		base = Ssot.get_number(row_id, stat, fallback)

	var flat: float = 0.0
	var percent: float = 0.0
	if with_mods:
		flat = Mods.flat_total(stat)
		percent = Mods.percent_total(stat)

	if MODIFIER_IS_PERCENTAGE:
		var row_modifier: float = Ssot.get_number(row_id, stat + "_modifier", 0.0)
		return (base + flat) * (1.0 + row_modifier + percent)

	var row_multiplier: float = Ssot.get_number(row_id, stat + "_modifier", 1.0)
	return (base + flat) * row_multiplier * (1.0 + percent)
