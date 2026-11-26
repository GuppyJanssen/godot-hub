class_name TargetPicker
## TargetPicker – kiest voor een vijand welk doel van een ANDERE factie hij aanvalt.
##
## Regels (afgesproken met Daan, 26 nov 2026):
##   1. Afmaken: zit hij al op een doel dat onder target_finish_health (world, 0.07 = 7%) zit, dan
##      schiet hij dat eerst kapot. Dit gaat zelfs vóór de speler.
##   2. De speler gaat voor bij alle facties (zodra ze van hem weten: alarm of "hunt"). Dat regelt
##      test_body.gd; deze klasse kiest alleen tussen units en gebouwen van andere facties.
##   3. Anders: dichtstbijzijnde, maar elk doel dat hooguit target_switch_range (world) verder weg
##      is telt ook mee. Daarvan wint het doel waar mijn damage type het best tegen werkt
##      (damage_type_modifier van het doel x shield_damage_modifier zolang het nog schild heeft),
##      dan het zwakste (laagste deel levens over), dan het dichtstbijzijnde.
##      Zelfde regel als "dichtstbij, wissel naar zwakte" in de Imperial Arena-sheet.
##   De lock-on van de speler gebruikt dit NIET: die blijft op zijn doel zitten.
##   4. Gebiedsschade (bommen, kamikaze) raakt ook de eigen factie; aoe_ok() bekijkt of het de moeite is.
##
## Ontwikkelaarsnotities:
## - Vijandig = een node in de groep "targets" met een factie die niet leeg is en niet de mijne.
##   Hybrides tellen als eigen factie (ab vecht ook tegen a en b).
## - Geen zichtlijn-check hier (scheelt raycasts); de schutter controleert zicht bij het schieten.
## - Kosten: één loop over "targets" per vijand per zoekronde (test_body: elke 0.2 s). Bij 40 vijanden
##   is dat ~8000 afstandsberekeningen per seconde, verwaarloosbaar. Wordt het ooit te veel: een
##   gedeeld rooster zoals bij de loot.

const SETTINGS_ROW := "world"


## Hoort 'other' bij een andere factie dan 'my_faction' (en leeft hij nog)?
static func is_hostile_to(my_faction: String, other: Node) -> bool:
	if my_faction == "" or not is_instance_valid(other) or not other is Node2D:
		return false
	if other.is_queued_for_deletion() or not "faction" in other:
		return false
	var theirs: String = str(other.faction)
	if theirs == "" or theirs == my_faction:
		return false
	return health_fraction(other) > 0.0


## Hoeveel levens heeft dit doel nog, als deel (1 = vol, 0 = dood).
static func health_fraction(node: Node) -> float:
	if not is_instance_valid(node):
		return 0.0
	if "current_health" in node and "max_health" in node:
		return clampf(float(node.current_health) / maxf(1.0, float(node.max_health)), 0.0, 1.0)
	if "spawner_current_health" in node and "spawner_max_health" in node:
		return clampf(float(node.spawner_current_health) / maxf(1.0, float(node.spawner_max_health)), 0.0, 1.0)
	return 1.0


## Hoe goed werkt dit damage type tegen dit doel? 1 = normaal, hoger = zwakte.
static func effectiveness(damage_type: String, target: Node) -> float:
	var f: float = DamageCalc.factor(damage_type, target)
	if "shield" in target and target.shield != null and float(target.shield.current) > 0.0:
		f *= DamageCalc.shield_factor(damage_type)
	return f


## Het beste doel van een andere factie binnen 'radius' rond 'me', of null.
static func pick(me: Node2D, my_faction: String, damage_type: String, radius: float) -> Node2D:
	if radius <= 0.0 or not is_instance_valid(me) or not me.is_inside_tree():
		return null
	var candidates: Array = []
	var nearest: float = INF
	for node in me.get_tree().get_nodes_in_group("targets"):
		if node == me or not is_hostile_to(my_faction, node):
			continue
		var d: float = me.global_position.distance_to(node.global_position)
		if d > radius:
			continue
		candidates.append([node, d])
		nearest = minf(nearest, d)
	if candidates.is_empty():
		return null
	var reach: float = nearest + switch_range()
	var best: Node2D = null
	var best_eff: float = -1.0
	var best_hp: float = 2.0
	var best_d: float = INF
	for entry in candidates:
		var d: float = entry[1]
		if d > reach:
			continue
		var node: Node2D = entry[0]
		var eff: float = effectiveness(damage_type, node)
		var hp: float = health_fraction(node)
		var better: bool = false
		if not is_equal_approx(eff, best_eff):
			better = eff > best_eff
		elif not is_equal_approx(hp, best_hp):
			better = hp < best_hp
		else:
			better = d < best_d
		if better:
			best = node
			best_eff = eff
			best_hp = hp
			best_d = d
	return best


## Mag deze gebiedsschade (ontploffing) hier? Friendly fire hoort erbij, maar de vijand proberen
## te raken weegt zwaarder: het mag, tenzij de schade aan de eigen factie groter is dan
## friendly_fire_tolerance (world) keer de schade aan vijanden (de speler en andere facties).
## Voorbeeld: tolerance 1.5, vijanden krijgen samen 40, eigen factie 50: mag (50 <= 60).
## 'shooter' zelf telt niet mee (een kamikaze gaat sowieso dood).
static func aoe_ok(shooter: Node, my_faction: String, center: Vector2, radius: float, damage: float,
		damage_type: String) -> bool:
	if radius <= 0.0 or damage <= 0.0 or not is_instance_valid(shooter) or not shooter.is_inside_tree():
		return true
	var enemy_total: float = 0.0
	var friend_total: float = 0.0
	var player: Node = Game.active_player
	if is_instance_valid(player) and player is Node2D and player.global_position.distance_to(center) <= radius:
		enemy_total += damage * DamageCalc.factor(damage_type, player)
	for node in shooter.get_tree().get_nodes_in_group("targets"):
		if node == shooter or not node is Node2D or not "faction" in node:
			continue
		if node.global_position.distance_to(center) > radius or health_fraction(node) <= 0.0:
			continue
		var hit: float = damage * DamageCalc.factor(damage_type, node)
		var theirs: String = str(node.faction)
		if theirs == my_faction:
			friend_total += hit
		elif theirs != "":
			enemy_total += hit
	return friend_total <= enemy_total * friendly_fire_tolerance()


## Hoeveel keer de vijandschade een ontploffing aan de eigen factie mag doen (SSOT world).
static func friendly_fire_tolerance() -> float:
	return maxf(0.0, Ssot.get_number(SETTINGS_ROW, "friendly_fire_tolerance", 1.5))


## Moet dit doel eerst afgemaakt worden? (onder target_finish_health levens)
static func should_finish(target: Node) -> bool:
	var limit: float = clampf(Ssot.get_number(SETTINGS_ROW, "target_finish_health", 0.07), 0.0, 1.0)
	var hp: float = health_fraction(target)
	return hp > 0.0 and hp < limit


## Hoeveel verder dan het dichtstbijzijnde doel een zwakker doel mag zijn (pixels).
static func switch_range() -> float:
	return maxf(0.0, Ssot.get_number(SETTINGS_ROW, "target_switch_range", 150.0))
