class_name SkillDecay
## SkillDecay – het verval van skills, per moeilijkheid.
##
## Geen autoload nodig. Deze functies rekenen alleen; ze slaan zelf niets op.
##
## - Easy  : skills lopen niet terug.
## - Normal: skills lopen pas NA de run terug, op basis van hoe lang de run duurde.
## - Hard  : skills lopen TIJDENS de run terug.
##
## Formule uit het ontwerp: levels per seconde = (decay_per_minute × decay_modifier) / 60
## Let op: decay_modifier is hier een vermenigvuldiger (1 = neutraal, 60 = 1 level per seconde).
##
## Voorbeeld, aan het eind van een run op Normal:
##   if SkillDecay.decays_after_run(RunState.difficulty):
##       levels = SkillDecay.apply(levels, RunState.run_seconds)
##
## Voorbeeld, tijdens een run op Hard (in _process van de speler of de kamer):
##   if SkillDecay.decays_during_run(RunState.difficulty):
##       levels = SkillDecay.apply(levels, delta)

enum Difficulty { EASY, NORMAL, HARD }

## Waarden als de SSOT niets zegt.
const DEFAULT_DECAY_PER_MINUTE := 1.0
const DEFAULT_DECAY_MODIFIER := 1.0
## Id van de rij met algemene instellingen in de SSOT, als die er is.
const SETTINGS_ROW := "player"


static func decays_during_run(difficulty: int) -> bool:
	return difficulty == Difficulty.HARD


static func decays_after_run(difficulty: int) -> bool:
	return difficulty == Difficulty.NORMAL


## Hoeveel levels één skill per seconde verliest.
## Kijkt eerst naar de rij van de skill zelf, daarna naar de algemene rij, daarna naar de standaard.
static func levels_per_second(skill_id: String) -> float:
	var per_minute: float = Ssot.get_number(skill_id, "decay_per_minute",
			Ssot.get_number(SETTINGS_ROW, "decay_per_minute", DEFAULT_DECAY_PER_MINUTE))
	var modifier: float = Ssot.get_number(skill_id, "decay_modifier",
			Ssot.get_number(SETTINGS_ROW, "decay_modifier", DEFAULT_DECAY_MODIFIER))
	return (per_minute * modifier) / 60.0


## Laat alle skills 'seconds' seconden vervallen en geeft de nieuwe levels terug.
## 'levels' is een Dictionary skill_id -> level (mag een kommagetal zijn).
## 'extra_multiplier' is voor effecten als de parasiet (2.0 = twee keer zo snel).
static func apply(levels: Dictionary, seconds: float, extra_multiplier: float = 1.0) -> Dictionary:
	var result: Dictionary = {}
	for skill_id in levels:
		var level: float = float(levels[skill_id])
		var lost: float = levels_per_second(skill_id) * seconds * extra_multiplier
		result[skill_id] = maxf(0.0, level - lost)
	return result


## Hoeveel seconden het duurt tot deze skill op 0 staat. Handig voor een tekst in de skill tree.
static func seconds_until_empty(skill_id: String, level: float) -> float:
	var per_second: float = levels_per_second(skill_id)
	if per_second <= 0.0:
		return INF
	return level / per_second
