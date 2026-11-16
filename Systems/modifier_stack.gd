extends Node
## Mods – houdt alle tijdelijke en gekochte aanpassingen op stats bij.
##
## Autoload: voeg dit script toe als "Mods".
##
## Alles wat een stat van de speler verandert (skills, run-items, effecten van een treffer)
## zet hier een regel neer. StatCalc telt ze op bij de waarde uit de SSOT.
##
## Elke regel heeft:
## - source : wie hem zette, bijvoorbeeld "skill:skill_1" of "item:overdrive"
## - stat   : de naam van de stat zonder base_ of _modifier, bijvoorbeeld "speed"
## - flat   : vaste bonus die bij de basiswaarde komt (+250 snelheid)
## - percent: bonus als deel van 1 (0.1 = +10%)
## - group  : soort upgrade ("wapen", "schip", "physics"...), voor het uitschakelen
##
## Voorbeeld:
##   Mods.set_modifier("item:boost", "speed", 0.0, 0.2)   # +20% snelheid
##   Mods.remove_source("item:boost")                      # weer weg
##   Mods.disable_group("wapen", 3.0)                      # EMP: wapen-upgrades 3 s uit

## Wordt uitgezonden bij elke wijziging. Handig om stats opnieuw uit te rekenen.
signal changed

var _entries: Dictionary = {}    # "source|stat" -> Dictionary
var _disabled: Dictionary = {}   # group -> seconden die nog over zijn


func _process(delta: float) -> void:
	if _disabled.is_empty():
		return
	var something_ended: bool = false
	for group in _disabled.keys():
		_disabled[group] -= delta
		if _disabled[group] <= 0.0:
			_disabled.erase(group)
			something_ended = true
	if something_ended:
		changed.emit()


## Zet of vervangt één aanpassing. Dezelfde source + stat overschrijft de vorige.
func set_modifier(source: String, stat: String, flat: float = 0.0, percent: float = 0.0, group: String = "") -> void:
	_entries[source + "|" + stat] = {
		"source": source,
		"stat": stat,
		"flat": flat,
		"percent": percent,
		"group": group,
	}
	changed.emit()


## Haalt alle aanpassingen van één bron weg.
func remove_source(source: String) -> void:
	var removed: bool = false
	for key in _entries.keys():
		if _entries[key]["source"] == source:
			_entries.erase(key)
			removed = true
	if removed:
		changed.emit()


## Haalt alle aanpassingen weg waarvan de bron met deze tekst begint,
## bijvoorbeeld remove_sources_starting_with("skill:").
func remove_sources_starting_with(prefix: String) -> void:
	var removed: bool = false
	for key in _entries.keys():
		var source: String = _entries[key]["source"]
		if source.begins_with(prefix):
			_entries.erase(key)
			removed = true
	if removed:
		changed.emit()


## Alles wissen (nieuwe run, terug naar het menu).
func clear() -> void:
	_entries.clear()
	_disabled.clear()
	changed.emit()


## Som van alle vaste bonussen voor een stat.
func flat_total(stat: String) -> float:
	return _total(stat, "flat")


## Som van alle procentuele bonussen voor een stat (0.1 = +10%).
func percent_total(stat: String) -> float:
	return _total(stat, "percent")


## Zet een hele groep upgrades tijdelijk uit (kwetsbaarheden: EMP, slime, zuur...).
## Een nieuwe treffer verlengt de tijd, maar verkort hem nooit.
func disable_group(group: String, seconds: float) -> void:
	var current: float = _disabled.get(group, 0.0)
	_disabled[group] = maxf(current, seconds)
	changed.emit()


## Zet een groep meteen weer aan.
func enable_group(group: String) -> void:
	if _disabled.erase(group):
		changed.emit()


func is_group_disabled(group: String) -> bool:
	return _disabled.has(group)


## Hoeveel seconden een groep nog uit staat (0 = staat aan).
func disabled_time_left(group: String) -> float:
	return _disabled.get(group, 0.0)


func _total(stat: String, field: String) -> float:
	var total: float = 0.0
	for entry in _entries.values():
		if entry["stat"] != stat:
			continue
		if entry["group"] != "" and _disabled.has(entry["group"]):
			continue
		total += entry[field]
	return total
