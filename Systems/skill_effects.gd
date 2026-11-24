class_name SkillEffects
## SkillEffects – zorgt dat gekochte skills echt iets doen in het spel.
##
## Geen autoload nodig. Dit leest de skill-rijen uit de SSOT en zet per skill
## de juiste aanpassingen in Mods. Een nieuwe skill is dus alleen een nieuwe rij.
##
## Zo leest hij een skill-rij (data_type upgrade_skill in de sheet):
## - Een ingevulde kolom  base_<stat>      = vaste bonus PER LEVEL  (base_speed 2,5 → +2,5 snelheid per level)
## - Een ingevulde kolom  <stat>_modifier  = procent PER LEVEL      (damage_modifier 0,01 → +1% schade per level)
## - Kolom SKILL_KIND_COLUMN               = soort upgrade (wapen, schip, physics...), voor kleur en uitschakelen
## - Lege kolommen doen niets.
##
## Voorbeeld, na het laden van de save en na elke aankoop of elk verval:
##   var levels: Dictionary = SkillEffects.effective_levels(gekochte_levels, RunState.run_points)
##   SkillEffects.apply_all(levels)

## Pas aan als de soort-naam of de kolom in jullie sheet anders heet.
const SKILL_TYPE := "upgrade_skill"
const SKILL_KIND_COLUMN := "skill_kind"
const MAX_LEVEL := 100.0

## Kolommen die op _modifier eindigen of met base_ beginnen, maar GEEN stat van de speler zijn.
const IGNORED_STATS := ["decay", "decay_per_minute"]

## Een skill-kolom heet soms anders dan de stat die de speler leest. Hier wordt hij omgezet:
## base_shield (skill_shield) telt op bij max_shield, shield_regen_modifier bij shield_regen_amount.
const STAT_ALIASES := {
	"shield": "max_shield",
	"energy": "max_energy",
	"health": "max_health",
	"shield_regen": "shield_regen_amount",
}
## Staat weapon_type op "auto" in een skill-rij, dan maakt die skill op zijn maximale level
## elk wapen full-auto (de stat "full_auto", zie SsotWeapon).
const WEAPON_TYPE_COLUMN := "weapon_type"
const MAX_LEVEL_COLUMN := "fill_levels_amount"


## De gekochte levels uit de save, bewaard zodat Hard-verval niet elke seconde de schijf leest.
static var _bought_cache: Dictionary = {}


## Leest de gekochte levels uit de save en de run-punten uit RunState, en zet alles in Mods.
## Roep dit aan bij het begin van elke kamer en na een aankoop of run-punt.
static func refresh_from_save() -> void:
	var meta: MetaProgress = SaveSystem.new().get_loaded_meta_progress()
	_bought_cache = {}
	for skill_id in meta.skills_data:
		var entry: Variant = meta.skills_data[skill_id]
		_bought_cache[skill_id] = float(entry.get("level", 0)) if entry is Dictionary else 0.0
	refresh_decay()


## Zet de skills opnieuw in Mods met de levels van nu. Op Hard lopen ze tijdens de run terug
## (SkillDecay); RunState roept dit daarom elke seconde aan.
static func refresh_decay() -> void:
	var bought: Dictionary = _bought_cache
	if RunState.active and SkillDecay.decays_during_run(RunState.difficulty):
		bought = SkillDecay.apply(bought, RunState.run_seconds)
	apply_all(effective_levels(bought, RunState.run_points))


## Telt de gekochte levels en de run-punten (run-items) bij elkaar op, tot maximaal 100.
static func effective_levels(bought: Dictionary, run_points: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for skill_id in bought:
		result[skill_id] = float(bought[skill_id])
	for skill_id in run_points:
		result[skill_id] = float(result.get(skill_id, 0.0)) + float(run_points[skill_id])
	for skill_id in result:
		result[skill_id] = clampf(result[skill_id], 0.0, MAX_LEVEL)
	return result


## Zet de effecten van alle skills in Mods. Oude skill-effecten worden eerst weggehaald.
## 'levels' is een Dictionary skill_id -> level.
static func apply_all(levels: Dictionary) -> void:
	Mods.remove_sources_starting_with("skill:")
	for skill_id in Ssot.get_ids(SKILL_TYPE):
		var level: float = float(levels.get(skill_id, 0.0))
		if level > 0.0:
			apply_one(skill_id, level)


## Zet de effecten van één skill in Mods.
static func apply_one(skill_id: String, level: float) -> void:
	var source: String = "skill:" + skill_id
	Mods.remove_source(source)

	var row: Dictionary = Ssot.get_row(skill_id)
	var kind: String = str(row.get(SKILL_KIND_COLUMN, "")).to_lower()

	# Eerst verzamelen per stat, zodat base_ en _modifier van dezelfde stat samen één regel worden.
	var flat_per_stat: Dictionary = {}
	var percent_per_stat: Dictionary = {}
	for column in row:
		var column_name: String = column
		if column_name.begins_with("base_"):
			var stat: String = STAT_ALIASES.get(column_name.trim_prefix("base_"), column_name.trim_prefix("base_"))
			if not stat in IGNORED_STATS:
				flat_per_stat[stat] = Ssot.get_number(skill_id, column_name) * level
		elif column_name.ends_with("_modifier"):
			var stat: String = STAT_ALIASES.get(column_name.trim_suffix("_modifier"), column_name.trim_suffix("_modifier"))
			if not stat in IGNORED_STATS:
				percent_per_stat[stat] = Ssot.get_number(skill_id, column_name) * level

	var stats: Dictionary = {}
	for stat in flat_per_stat:
		stats[stat] = true
	for stat in percent_per_stat:
		stats[stat] = true

	if str(row.get(WEAPON_TYPE_COLUMN, "")).strip_edges().to_lower() == "auto" \
			and level >= Ssot.get_number(skill_id, MAX_LEVEL_COLUMN, MAX_LEVEL):
		flat_per_stat["full_auto"] = 1.0
		stats["full_auto"] = true

	for stat in stats:
		Mods.set_modifier(source, stat,
				float(flat_per_stat.get(stat, 0.0)),
				float(percent_per_stat.get(stat, 0.0)),
				kind)


## Hoe vol een skill zit, als trede: 0, 25, 50, 75 of 100.
## Handig voor skills die per trede iets anders doen (zoals de alles-magneet).
static func tier(level: float) -> int:
	if level >= 100.0:
		return 100
	if level >= 75.0:
		return 75
	if level >= 50.0:
		return 50
	if level >= 25.0:
		return 25
	return 0
