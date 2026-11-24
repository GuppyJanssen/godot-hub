extends Resource
class_name PlayerStats
## De huidige stand van de speler tijdens een run: levens, schild en energie.
##
## Ontwikkelaarsnotitie: de maxima en alle andere waarden (snelheid, afremmen, draaien, magneet,
## oppakken) komen uit de SSOT-rij player_base; zie Player.gd. Dit is alleen de stand.
## Wordt niet meer als .tres in de save gezet (zie SaveSystem: geen resources uit user://).

@export_category("Gezondheid & Energie")
@export var max_health: int = 100
@export var current_health: int = 100
@export var max_shield: int = 50
@export var current_shield: int = 50
@export var max_energy: int = 100
@export var current_energy: int = 100
