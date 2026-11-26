class_name DamageCalc
## DamageCalc – één plek waar elke treffer zijn damage type meetelt (resistances en zwaktes).
##
## Waar het staat in de SSOT: kolom damage_type_modifier, als lijst "type:factor" gescheiden door /.
##   Voorbeeld: "acid:0.5/laser:1.5"  → acid doet de helft, laser anderhalf keer zoveel.
##   1 = normaal, 0 = immuun, leeg of niet genoemd = 1.
## Op welke rij:
##   - Vijanden en gebouwen: eerst de eigen vijand-rij, dan de factie-rij, dan de type-rij
##     (EnemyStats.text). Zo staat het meestal één keer op de factie (faction_a: organic ...).
##   - De speler: rij player_base.
##
## Gebruik bij elke treffer (kogels, ontploffingen, rammen, aanraken, later wolkjes en asteroïden):
##   target.take_damage(DamageCalc.scaled(schade, damage_type, target), ...)
##
## SCHILDEN: sommige damage types zijn sterk (of zwak) tegen schilden. Rij world, kolom
## shield_damage_modifier, zelfde vorm ("magnetic:2/laser:1.25"). Alleen het deel van de treffer dat
## op het schild komt telt dat mee; wat erdoor komt gaat gewoon van de levens af.
## scaled() onthoudt het damage type op het doel (meta), zodat take_damage het bij het schild kan
## gebruiken via shield_factor_for(). Wie take_damage zelf aanroept: eerst mark(doel, type).
##
## TWEE TYPES (hybrides): base_damage_type mag twee types hebben, bijvoorbeeld "acid/magnetic". De schade
## gaat dan half om half: de factor is het gemiddelde van beide types (ook tegen schilden).
##
## Ontwikkelaarsnotities:
## - "corrosive" is hetzelfde als "acid" en "kinetic" hetzelfde als "physical" (normalize). Physical = geen element.
## - Een samengesteld type blijft overal één tekst ("acid/magnetic"); alleen factor() en shield_factor()
##   splitsen hem. Hooguit MAX_TYPES delen, zodat een rare tekst geen lange lus wordt.
## - De lijst wordt één keer per tekst ontleed en bewaard (_cache); daarna is het een opzoeking.
## - Factoren worden begrensd (0..10) zodat een typfout als 50 niet alles kapotmaakt.

const COLUMN := "damage_type_modifier"
const PLAYER_ROW := "player_base"
const MAX_FACTOR := 10.0
const SHIELD_COLUMN := "shield_damage_modifier"
const LAST_TYPE_META := "last_damage_type"
const HIT_BY_META := "hit_by_faction"
const MAX_TYPES := 4

static var _cache: Dictionary = {}


## Eén naam per damage type. Twee types ("acid/magnetic") blijven twee, elk genormaliseerd.
static func normalize(type: String) -> String:
	if "/" in type:
		return "/".join(types_of(type))
	var clean: String = SsotWeapon.normalize_damage_type(type)
	if clean == "corrosive":
		return "acid"
	return clean


## De losse types in een (samengesteld) damage type. Nooit leeg: leeg = ["physical"].
static func types_of(type: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for part in type.split("/", false):
		if out.size() >= MAX_TYPES:
			break
		var one: String = SsotWeapon.normalize_damage_type(part)
		if one == "corrosive":
			one = "acid"
		if not out.has(one):
			out.append(one)
	if out.is_empty():
		out.append("physical")
	return out


## Gemiddelde factor van alle types uit een tabel (1 = niet genoemd).
static func _mean_factor(table: Dictionary, damage_type: String) -> float:
	var parts: PackedStringArray = types_of(damage_type)
	var total: float = 0.0
	for part in parts:
		total += float(table.get(part, 1.0))
	return total / float(parts.size())


## De factor voor dit doel en dit damage type (1 = normaal).
static func factor(damage_type: String, target: Node) -> float:
	if not is_instance_valid(target):
		return 1.0
	return _mean_factor(_parse(_text_for(target)), damage_type)


## Onthoudt het damage type van de treffer die zo komt (voor het schild).
static func mark(target: Node, damage_type: String) -> void:
	if is_instance_valid(target):
		target.set_meta(LAST_TYPE_META, normalize(damage_type))


## Factor van dit damage type tegen schilden (1 = normaal).
static func shield_factor(damage_type: String) -> float:
	return _mean_factor(_parse(Ssot.get_text("world", SHIELD_COLUMN, "")), damage_type)


## Factor tegen het schild voor de treffer die nu binnenkomt (en vergeet het type daarna).
static func shield_factor_for(target: Node) -> float:
	if not is_instance_valid(target) or not target.has_meta(LAST_TYPE_META):
		return 1.0
	var damage_type: String = str(target.get_meta(LAST_TYPE_META))
	target.remove_meta(LAST_TYPE_META)
	return shield_factor(damage_type)


## Het damage type waarmee een vijand of gebouw zelf aanvalt (rammen, aanraken, ontploffen):
## base_damage_type van zijn rij (eigen vijand-rij, dan factie, dan type). Leeg = physical.
static func attack_type(attacker: Node) -> String:
	if not is_instance_valid(attacker) or not "faction" in attacker:
		return "physical"
	var unit: String = ""
	if "unit_type" in attacker:
		unit = str(attacker.unit_type)
	elif "building_type" in attacker:
		unit = str(attacker.building_type)
	return normalize(EnemyStats.text(str(attacker.faction), unit, "base_damage_type", ""))


## Onthoudt welke factie het doel zo raakt (een vijand die door een andere factie geraakt wordt,
## slaat dan geen alarm over de speler). Lees het uit met take_hit_by().
static func mark_attacker(target: Node, attacker_faction: String) -> void:
	if is_instance_valid(target) and attacker_faction != "":
		target.set_meta(HIT_BY_META, attacker_faction)


## De factie die het doel net raakte ("" = de speler of iets neutraals), en vergeet het daarna.
static func take_hit_by(target: Node) -> String:
	if not is_instance_valid(target) or not target.has_meta(HIT_BY_META):
		return ""
	var who: String = str(target.get_meta(HIT_BY_META))
	target.remove_meta(HIT_BY_META)
	return who


## Schade na resistances, als heel getal voor take_damage. Iets > 0 blijft minimaal 1,
## tenzij het doel immuun is (factor 0).
static func scaled(amount: float, damage_type: String, target: Node) -> int:
	if amount <= 0.0:
		return 0
	mark(target, damage_type)
	var f: float = factor(damage_type, target)
	if f <= 0.0:
		return 0
	return maxi(1, roundi(amount * f))


static func _text_for(target: Node) -> String:
	if target == Game.active_player or target.is_in_group("player"):
		return Ssot.get_text(PLAYER_ROW, COLUMN, "")
	if "faction" in target:
		var unit: String = ""
		if "unit_type" in target:
			unit = str(target.unit_type)
		elif "building_type" in target:
			unit = str(target.building_type)
		return EnemyStats.text(str(target.faction), unit, COLUMN, "")
	return ""


static func _parse(text: String) -> Dictionary:
	if _cache.has(text):
		return _cache[text]
	var table: Dictionary = {}
	for part in text.split("/", false):
		var pair: PackedStringArray = part.split(":", false)
		if pair.size() != 2:
			push_warning("DamageCalc: '%s' is geen type:factor in %s." % [part, COLUMN])
			continue
		var value: String = pair[1].strip_edges().replace(",", ".")
		if not value.is_valid_float():
			push_warning("DamageCalc: '%s' is geen getal in %s." % [pair[1], COLUMN])
			continue
		table[normalize(pair[0])] = clampf(value.to_float(), 0.0, MAX_FACTOR)
	_cache[text] = table
	return table
