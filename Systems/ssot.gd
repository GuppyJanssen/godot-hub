extends Node
## Ssot – leest de ene CSV (Single Source of Truth) op KOLOMNAAM.
##
## Autoload: Project → Project Settings → Globals → voeg dit script toe als "Ssot".
##
## Regels:
## - Elke rij heeft een uniek id (kolom ID_COLUMN) en een soort (kolom TYPE_COLUMN).
## - LEEG = geldt niet voor deze rij. De waarde bestaat dan niet (has_value geeft false).
## - 0    = geldt wel, maar doet niets. De waarde bestaat en is 0.
## - Nieuwe kolom in de sheet? Die is meteen op te vragen, zonder codewijziging.
##
## Voorbeeld:
##   var schade: float = Ssot.get_number("weapon_pistol", "base_damage")
##   if Ssot.has_value("enemy_grunt", "base_loot_splatter"): ...

## Pas deze drie aan als jullie bestand of kolommen anders heten.
## De CSV: export van de tab "CSV tab" in de sheet "One doc to rule them all".
const CSV_PATH := "res://Systems/ssot.csv"
const ID_COLUMN := "entry_id"
const TYPE_COLUMN := "data_type"

## Wordt uitgezonden nadat de CSV (opnieuw) is ingelezen.
signal loaded

var _rows: Dictionary = {}      # id -> Dictionary (kolomnaam -> tekst)
var _by_type: Dictionary = {}   # soort -> Array met id's, in de volgorde van de sheet
var _columns: PackedStringArray = PackedStringArray()


func _ready() -> void:
	load_csv(CSV_PATH)


## Leest de CSV in. Geeft true terug als het gelukt is.
func load_csv(path: String = CSV_PATH) -> bool:
	_rows.clear()
	_by_type.clear()
	_columns = PackedStringArray()

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Ssot: kan de CSV niet openen: %s" % path)
		return false

	# Regel 1 = de kolomnamen.
	var header: PackedStringArray = file.get_csv_line()
	for h in header:
		_columns.append(h.strip_edges().trim_prefix("﻿"))
	if not _columns.has(ID_COLUMN):
		push_error("Ssot: kolom '%s' ontbreekt in de CSV." % ID_COLUMN)
		return false

	var line_nr: int = 1
	while not file.eof_reached():
		var cells: PackedStringArray = file.get_csv_line()
		line_nr += 1

		var row: Dictionary = {}
		for i in mini(cells.size(), _columns.size()):
			var value: String = cells[i].strip_edges()
			# Lege cel = de sleutel bestaat niet. Zo blijven leeg en 0 uit elkaar.
			if value != "" and _columns[i] != "":
				row[_columns[i]] = value

		if not row.has(ID_COLUMN):
			continue  # lege regel of regel zonder id

		var id: String = row[ID_COLUMN]
		if _rows.has(id):
			push_warning("Ssot: id '%s' staat dubbel (regel %d). De laatste telt." % [id, line_nr])
		else:
			var type: String = row.get(TYPE_COLUMN, "")
			if not _by_type.has(type):
				_by_type[type] = []
			_by_type[type].append(id)
		_rows[id] = row

	print("Ssot: %d rijen en %d kolommen ingelezen." % [_rows.size(), _columns.size()])
	loaded.emit()
	return true


## Bestaat er een rij met dit id?
func has_row(id: String) -> bool:
	return _rows.has(id)


## De hele rij als Dictionary (alleen de ingevulde kolommen). Leeg als het id niet bestaat.
func get_row(id: String) -> Dictionary:
	return _rows.get(id, {})


## Alle id's van één soort, bijvoorbeeld get_ids("weapon").
func get_ids(type: String) -> Array:
	var ids: Array = _by_type.get(type, [])
	return ids.duplicate()


## Alle kolomnamen uit de CSV.
func get_columns() -> PackedStringArray:
	return _columns


## Is deze kolom ingevuld voor deze rij? (Leeg = false, 0 = true.)
func has_value(id: String, column: String) -> bool:
	return get_row(id).has(column)


## Tekst uit een cel. Geeft 'fallback' als de cel leeg is.
func get_text(id: String, column: String, fallback: String = "") -> String:
	return get_row(id).get(column, fallback)


## Getal uit een cel. Geeft 'fallback' als de cel leeg is of geen getal bevat.
## Een Nederlandse komma (2,5) wordt ook begrepen.
func get_number(id: String, column: String, fallback: float = 0.0) -> float:
	var row: Dictionary = get_row(id)
	if not row.has(column):
		return fallback
	var text: String = row[column]
	text = text.replace(",", ".")
	# Staat er een procentteken (10%), dan wordt het 0.1.
	var is_percent: bool = text.ends_with("%")
	text = text.trim_suffix("%").strip_edges()
	if not text.is_valid_float():
		push_warning("Ssot: '%s' in %s/%s is geen getal." % [row[column], id, column])
		return fallback
	if is_percent:
		return text.to_float() / 100.0
	return text.to_float()


## Heel getal uit een cel (afgerond).
func get_int(id: String, column: String, fallback: int = 0) -> int:
	return roundi(get_number(id, column, float(fallback)))


## Ja/nee uit een cel. TRUE, WAAR, ja, yes en 1 tellen als ja.
func get_bool(id: String, column: String, fallback: bool = false) -> bool:
	var row: Dictionary = get_row(id)
	if not row.has(column):
		return fallback
	var text: String = row[column]
	return text.to_lower() in ["true", "waar", "ja", "yes", "1"]
