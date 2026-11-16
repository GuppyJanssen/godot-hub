class_name EnemyStats
## EnemyStats – rekent de waarden van een vijand uit als FACTIE × TYPE.
##
## Geen autoload nodig. Zet dit script in res://Systems/.
##
## Het idee: je vult niet elke vijand apart in, maar
##   - een rij per TYPE    (unit_light, unit_grunt, unit_heavy)  met de basiswaarden
##   - een rij per FACTIE  (faction_a, faction_b ... faction_ab) met de modifiers
## Een vijand = de basis van zijn type, aangepast met de modifiers van zijn factie:
##   eindwaarde = base_<stat> van het type × (1 + <stat>_modifier van het type + <stat>_modifier van de factie)
##
## Uitzonderingen: bestaat er een eigen rij enemy_<factie>_<type> (bijvoorbeeld enemy_d_heavy)
## en is de stat daar ingevuld, dan gaat die rij voor.
##
## Voorbeeld:
##   var hp: float = EnemyStats.value("a", "grunt", "max_health", 50.0)
##   var kleur: Color = EnemyStats.color("a")
##
## Staan de rijen nog niet in de sheet, dan krijg je gewoon de 'fallback' terug.

## Hoe de rijen in de SSOT heten. Pas aan als jullie een andere naamgeving kiezen.
const UNIT_PREFIX := "unit_"         # unit_grunt
const FACTION_PREFIX := "faction_"   # faction_a
const ENEMY_PREFIX := "enemy_"       # enemy_a_grunt (uitzondering)

## Kolom op de factie-rij met de kleur, als hex (bijvoorbeeld #4CAF50).
const COLOR_COLUMN := "faction_color"

## Kleuren om mee te testen zolang de sheet er nog geen heeft.
const DEFAULT_COLORS := {
	"a": Color(0.55, 1.00, 0.55),   # groen
	"b": Color(0.70, 0.80, 1.00),   # staalblauw
	"c": Color(1.00, 0.95, 0.50),   # geel
	"d": Color(0.60, 0.95, 1.00),   # ijsblauw
	"e": Color(0.85, 0.70, 1.00),   # paars
	"f": Color(1.00, 0.65, 0.45),   # oranje
	"g": Color(0.75, 1.00, 0.35),   # gifgroen
	"h": Color(0.70, 0.55, 0.90),   # donkerpaars
	"i": Color(1.00, 0.60, 0.85),   # roze
}


static func unit_row(unit_type: String) -> String:
	return UNIT_PREFIX + unit_type.to_lower()


static func faction_row(faction: String) -> String:
	return FACTION_PREFIX + faction.to_lower()


static func enemy_row(faction: String, unit_type: String) -> String:
	return ENEMY_PREFIX + faction.to_lower() + "_" + unit_type.to_lower()


## Staat er iets over deze vijand in de SSOT (een type-rij of een eigen rij)?
static func exists(faction: String, unit_type: String) -> bool:
	return Ssot.has_row(unit_row(unit_type)) or Ssot.has_row(enemy_row(faction, unit_type))


## Een getal voor deze vijand, bijvoorbeeld "max_health" of "speed".
static func value(faction: String, unit_type: String, stat: String, fallback: float = 0.0) -> float:
	# 1. Een eigen rij voor precies deze vijand gaat voor.
	var own_row: String = enemy_row(faction, unit_type)
	if StatCalc.applies(own_row, stat):
		return StatCalc.value(own_row, stat, fallback)
	
	# 2. Anders: de basis van het type, met de modifiers van type en factie.
	var type_row: String = unit_row(unit_type)
	if not StatCalc.applies(type_row, stat):
		return fallback
	
	var base: float = fallback
	if Ssot.has_value(type_row, "base_" + stat):
		base = Ssot.get_number(type_row, "base_" + stat, fallback)
	else:
		base = Ssot.get_number(type_row, stat, fallback)
	
	var type_modifier: float = Ssot.get_number(type_row, stat + "_modifier", 0.0)
	var faction_modifier: float = Ssot.get_number(faction_row(faction), stat + "_modifier", 0.0)
	return base * (1.0 + type_modifier + faction_modifier)


## Een tekst voor deze vijand, bijvoorbeeld "damage_type".
## Kijkt eerst naar de eigen rij, dan naar de factie, dan naar het type.
static func text(faction: String, unit_type: String, column: String, fallback: String = "") -> String:
	for row in [enemy_row(faction, unit_type), faction_row(faction), unit_row(unit_type)]:
		if Ssot.has_value(row, column):
			return Ssot.get_text(row, column, fallback)
	return fallback


## De kleur van een factie: uit de SSOT als die er staat, anders een testkleur, anders wit.
static func color(faction: String) -> Color:
	var hex: String = Ssot.get_text(faction_row(faction), COLOR_COLUMN, "")
	if hex != "" and Color.html_is_valid(hex):
		return Color.html(hex)
	return DEFAULT_COLORS.get(faction.to_lower(), Color.WHITE)
