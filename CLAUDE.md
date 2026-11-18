# CLAUDE.md – godot-hub (2D space rogue-lite)

Claude Code leest dit bestand aan het begin van elke sessie in deze map.
Houd het kort en actueel. Bijgewerkt: 17 november 2026 (avond).

- Ontwerp: https://claude.ai/artifact/JjvwFyx6Jtb8dEDUjxFCj9
- Ideeën, planning en takenlijst: https://claude.ai/artifact/Cvi6x9PXQSMgAGeYU4JHJB

## Project

- 2D rogue-lite in de ruimte, **Godot 4.7** (GDScript).
- Kamers zoals The Binding of Isaac: één scherm (1920×1080) per kamer, deuren open als de kamer leeg is.
- De wereld is een bol van ringen (`LevelManager.LAYER_WIDTHS` = 1, 6, 12, 24, 48, 96, 48, 24, 12, 6, 1).
- Run-loot gaat na de run naar een vaste kluis; daarmee koop je levels in de skill tree. Skills vervallen met speeltijd.
- Plan: eerst ring 1 compleet, daarna de rest als vertical slice.

## Werkafspraken

- **Taal:** antwoorden en commentaar in de code in het Nederlands. Gebruik "wil", nooit "wilt".
- **De eigenaar is beginner in programmeren.** Leg uit wat je verandert en waarom, in gewone woorden.
- **Lees eerst het echte script** voordat je iets wijzigt. Geen aannames over wat erin staat.
- **Geen code staat vast.** Stel gerust een betere aanpak voor, maar vraag het voordat je grote stukken herschrijft.
- **Kleine stappen.** Eén onderdeel tegelijk, daarna testen.
- **Test zelf.** Start Godot om te controleren of scripts zonder fouten laden voordat je zegt dat iets klaar is.
  Hoe het eruitziet en aanvoelt beoordeelt de eigenaar.
- **Bestanden verplaatsen of hernoemen** gebeurt in Godot (FileSystem-paneel), niet in de Verkenner,
  anders breken de verwijzingen in de scenes. Verplaats je iets vanuit hier, werk dan ook de paden in `.tscn` bij.
- **Maak een commit** voor en na elke ronde wijzigingen, zodat alles terug te draaien is.

## SSOT (Single Source of Truth)

- Alle waarden komen uit **één CSV**, geëxporteerd uit de Google Sheet "One doc to rule them all"
  (tabblad 2 = invullen, tabblad 1 = export).
- Doel: de code zo bouwen dat alleen de SSOT aangepast hoeft te worden, nooit de code.
- Per stat een `base_` en een `_modifier` kolom. **Modifiers zijn percentages: 0 = neutraal, 0.1 = +10%.**
- **Leeg** = geldt niet voor deze rij. **0** = geldt wel en telt mee als 0.
- Skill-ID's zijn `skill_1`, `skill_2`... met een kolom voor de omschrijving en een kolom `parent_skill_id`.
- De CSV in de repo is nog de oude versie (12 kolommen, stats als tekst in één cel). De nieuwe brede sheet moet nog komen.

## Autoloads (in deze volgorde)

| Naam | Script | Rol |
| --- | --- | --- |
| `Game` | `Systems/Game.gd` | Centrale hub: actieve speler, save-slot, run-loot (als meta), debug (F1) |
| `LevelManager` | `Systems/LevelManager.gd` | Ring en kamer |
| `DebugOverlay` | `Systems/Debug_Overlay.gd` | Debugscherm |
| `Mods` | `Systems/modifier_stack.gd` | Alles wat stats van de speler aanpast (skills, items, effecten) |
| `Ssot` | `Systems/ssot.gd` | NIEUWE CSV-lezer op kolomnaam. Leest `Systems/ssot.csv` (export van de tab "CSV tab"). De enige CSV-lezer (MasterDatabase is weg sinds 18 nov) |
| `RunState` | `Systems/run_state.gd` | De lopende run: dodenlijst, gehaalde kamers, kamer-momentopnames, speeltijd. Start/stopt/bewaart ook de factie-oorlog |
| `FactionWar` | `Systems/faction_war.gd` | Factie-oorlog op de achtergrond: per kamer eigenaar en sterkte, tikt elke seconde speeltijd |
| `FactionWarMap` | `Systems/faction_war_map.gd` | Debugkaart van de oorlog (F2, F3 = versnellen). Alleen in debug-builds |

`Systems/SaveSystem.gd` is geen autoload en wordt op veel plekken los aangemaakt met `load(...).new()`.
Het regelt nog de kluis (`meta_data.json`) en een deel van `current_run.json`.

## Wat er op 16 november 2026 gebouwd is

- **Loot-splatter:** `Entities/Loot/loot_splatter.gd` + `loot_drop.gd`. Kegel ±35°, snelheid 60–400, afremming 600.
  Waarden staan nog als `DEFAULT_` in het script; moeten naar de SSOT, per wapen.
- **RunState:** schrijft `user://<slot>/run_state.json`, naast `current_run.json`.
  Positie, HP van de speler en de loot-tellers lopen nog via het oude systeem.
- **Kamer onthouden via de groep `saveable`:** elk object dat onthouden wil worden meldt zich aan in die groep
  en heeft `get_run_id()`, `get_run_state()` en `apply_run_state(data)`. De kamer (`World/Levels/game_room.gd`)
  verzamelt en zet terug, zonder te weten wat voor objecten het zijn. Uitleg staat in dat script onder "KAMER ONTHOUDEN".
  Groep `save_only_on_quit` = alleen bewaren bij "terug naar hoofdmenu" (kogels).
  Nu aangemeld: vijanden (`test_body.gd`), fabrieken (`enemy_spawner.gd`), loot, kogels (`weapon_output.gd`).
- **Eén spawner-script** (`enemy_spawner.gd`) met Faction, Unit Type en Sprite Scale in de Inspector.
- **Factie × type:** `Systems/enemy_stats.gd`. Een vijand = basis van `unit_<type>` × modifiers van `faction_<factie>`;
  een eigen rij `enemy_<factie>_<type>` gaat voor. Vijanden zonder factie/type (oude testvijanden) krijgen
  vaste testwaarden uit `test_body.gd` (LEGACY_TEST_HEALTH, DEFAULT_LOOT_*).
- **Kogels** verdwijnen als hun bereik op is en geven hun vliegrichting door bij een treffer.
  Het bereik komt uit de SSOT (`base_fire_range`), via `current_weapon_stats["weapon_range"]` van de speler.

Nog niet aangesloten (staan klaar, worden nergens aangeroepen): `stat_calc.gd`, `skill_effects.gd`, `skill_decay.gd`,
`Player/Weapons/weapon_shooter.gd`, `World/ring_math.gd`, en alles in `Ideeen/`.

## Toegevoegd op 17 november 2026

- **Nieuwe CSV:** `Systems/ssot.csv` (Import As = Keep File, net als de oude CSV). De Google Sheet heeft tab "SSoT"
  (invullen, kopregel in rij 4) en "CSV tab" (export; één formule in A1: `=ARRAYFORMULA(SSoT!A4:EI1000)`; komen er kolommen achteraan bij, dan moet de laatste kolomletter mee, dus nieuwe rijen en
  tussengevoegde kolommen komen vanzelf mee). Claude kan de sheet bewerken via de ingebouwde browser van de desktop-app. Rij-ids: `world` (wereld- en
  oorloginstellingen), `unit_light`, `unit_heavy`, `unit_factory`, `faction_a` t/m `faction_i` en hybrides
  `faction_ab`, `faction_bc`, `faction_ca` (en zo verder per driehoek). data_type: `world_settings`, `unit_type`, `faction`.
- **Kamergrenzen:** `Systems/room_bounds.gd` (`RoomBounds.apply`) bepaalt de bewegingsruimte voor speler én vijanden
  (Zuidpool: onderkant dicht, links/rechts rondlopen; gewone ring: dicht zolang er vijanden leven).
- **Sheet opgeschoond (17 nov):** SSoT is ingedeeld in blokken met kopregels (SPELER, PLANETEN, ITEMS, WAPENS, LOOT,
  SKILLS, WERELD, VIJAND-TYPES, FACTIES, VIJAND-OVERRIDES). Kopregels hebben geen entry_id en worden door Ssot overgeslagen.
  Brainstorm-rijen staan in een eigen tabblad (niet in de CSV). Reservekopie: tabblad "SSoT backup 17-11".
  Skills: 25 rijen, ids gelijk aan de skill_id in SkillTree.tscn (skill_speed, skill_damage, skill_fire_rate, ...).
  Effect PER LEVEL: base_<stat> = vaste bonus, <stat>_modifier = procent (0.01 = +1% per level, +100% op 100).
  data_type `upgrade_skill` (SkillEffects.SKILL_TYPE). Kosten in fill_costs_per_point als "olrite:5" (SkillSlot leest dit).
  Teksten in de sheet mogen niet met + of - beginnen (Sheets maakt er een formule van).
  Let op: `decay_modifier` is wél een vermenigvuldiger (1 = neutraal), zie skill_decay.gd.
- **Vijand-overrides** (sheet rij 21-38, data_type `enemy_override`): `enemy_<factienaam>_<type>`, bijvoorbeeld
  `enemy_organic_light`. De factienaam komt uit de ingame_name van de factie-rij (A = Organic, B = Mech, C = Energy,
  AB = Cyborg); zonder naam werkt de letter (`enemy_bc_light`). Lege cel = type + factie. Light heet in-game "grunt",
  behalve bij Organic ("spore"); de Organic heavy heet "scout".
- **Factie-oorlog:** `faction_war.gd`. Rekent alleen met getallen per kamer (owner, strength, attacker...). Regels: zijwaarts
  en een beetje omhoog, nooit omlaag; lagere driehoek komt alleen omhoog via door de speler geleegde kamers; hybrides alleen
  binnen een driehoek; geleegde kamers blijven `reoccupy_delay` leeg. Instellingen uit SSOT-rij `world`, standaarden in `DEFAULTS`.
  Driehoek per ring in `RING_TRIANGLE` (aanname: ring 1-3 ABC, 4-6 DEF, 7-9 GHI). Doet nog niets met de vijanden in een kamer:
  dat komt met de plaatsingspunten (`FactionWar.get_room_owner(ring, kamer)`).
- **Vijanden zonder voorkant:** `test_body.gd` heeft `faces_player`. Uit = tolt rond met eigen snelheid, treffers geven een zetje.
  Komt uit de SSOT-kolom `behavior_faces_player` (factie-rij of eigen vijand-rij; 1/0, leeg = Inspector). Factie A = 0.
- **Gedrag van vijanden** (`test_body.gd`, uit de SSOT; eigen rij `enemy_<factie>_<type>` gaat voor factie en type):
  `behavior_searching` = `hunt` (standaard: meteen op de speler af) of `wander` (zwerft tot alarm);
  `behavior_agro` = `chase` (standaard), `kamikaze` (ontploft bij de speler, raakt alles in `base_explosion_radius`,
  laat maar 10% loot vallen) of `keep_distance` (verkenner: blijft op afstand met de speler in zicht);
  `behavior_scan_radius` = kijkafstand, 0/leeg = blind. Wie de speler ziet slaat alarm voor zijn factie (geraakt: pas na `hit_alarm_delay` = 1,5 s, zodat stil uitschakelen kan)
  in die kamer (onthouden in RunState als `alarm_<factie>`). Niet-blinde, zwervende vijanden die een kogel zien,
  gaan kijken waar die vandaan kwam. Zicht = afstand + raycast (vijanden, loot en speler blokkeren niet).
  Organic: `enemy_a_light` = blinde kamikaze, `enemy_a_heavy` = verkenner (kijkafstand 450).
- **Speler** heeft nu `take_damage(amount)` (schild eerst, daarna HP, overlijden afgehandeld); botsingen en ontploffingen gebruiken die.
- **Fabriek:** veld heet `spawn_unit_type` (welk type hij maakt); eigen levens uit `unit_factory`. In `game_room.tscn`
  maakt spawner1 grunts (light) en spawner2 een verkenner (heavy).
- **Witte flits** werkt op alle zichtbare sprites van de vijand. Oude icoon-sprite uit `test_body.tscn` gehaald.
- Fabrieken staan standaard op Unit Type `light` (de sheet gebruikt light/heavy/factory, geen grunt).

## Opgeschoond op 17 november 2026

- `Player.gd`: het eerste schietblok dat `can_fire` negeerde is weg (full-auto vuurde elk frame),
  de dubbele herlaad-wachttijd is weg, en bij overlijden gaan nu ook Element 1 t/m 3 naar de kluis.
- `game_room.gd`: omhoog en omlaag komen niet meer altijd in kamer 0 uit, maar in de kamer boven of onder
  je (`_room_index_after_ring_change`).
- `hud.gd`: maakte in de skill tree elk frame een nieuw SaveSystem aan; dat wordt nu hergebruikt.
- `pre_menu.gd`: twee ongebruikte kopieën van functies uit SaveSystem verwijderd.
- Verwijderd (ongebruikt): `heavy_spawner.gd`, `Weapon.gd`, `Player/player_stats.gd`, `world_stats.gd`,
  `Overworld.gd/.tscn`, `player.tscn*.tmp`, `fg.txt`, de `.translation`-bestanden en drie wees-`.import`-bestanden;
  plus de ongebruikte functies `LevelManager.handle_room_transition`/`_load_current_room`,
  `Game.transfer_run_loot_to_meta_bank`/`load_and_force_continue_position`, `PlayerStats.get_calculated_speed`
  en `Game.debug_is_full_auto`.
- Vijanden worden groter of kleiner volgens `base_size` in de SSOT (heavy = 1.5). Geraakte verkenners slaan pas
  na `hit_alarm_delay` (1,5 s) alarm.

## Bekende problemen

- **`neutral_spawner.gd`** (bewust bewaard: wordt omgebouwd tot plaatsingspunt) gebruikt nog de oude controle via `current_run.json` en het oude `SaveSystem`.
  Nergens in een scene geplaatst.

- **Skills doen nog niets** in het spel; de skill-ID's in `SkillTree.tscn` komen niet overeen met de CSV.
- **Run-loot staat dubbel:** als meta op `Game` en in `run_loot_*` op de speler. `RunState.loot` telt mee maar is niet leidend.
- **Half beschadigde vijanden** worden door het oude `SaveSystem.save_current_run()` onder de verkeerde kamer weggezet
  (de LevelManager wijst dan al naar de nieuwe kamer). RunState doet dit nu goed; het oude deel kan weg.
- **`SaveSystem.gd.new()`** wordt op veel plekken aangemaakt en niet opgeruimd.

## Volgende stappen (in deze volgorde)

1. Run-loot, positie en HP van de speler overzetten naar `RunState`; daarna de oude `current_run.json` uitfaseren.
2. `SaveSystem` als autoload, alleen nog voor de kluis.
3. ~~MasterDatabase vervangen door `Ssot` + `StatCalc`~~ (klaar, 18 nov).
4. Skills koppelen (`SkillEffects`) en het verval (`SkillDecay`).
5. Het seed-systeem voor kamers.

## Toegevoegd op 18 november 2026

- **MasterDatabase weg.** De speler laadt zijn wapens via `SsotWeapon.from_ssot()` (`Player._load_weapon_stats`).
  Kolommen in de sheet: `base_damage`, `base_fire_rate`, `base_fire_range`, `base_bullet_speed`, `base_burst_count`
  (kogels per schot), `base_muzzle_count`, `base_bullet_spread` (graden), `weapon_type` ("auto" = full-auto), `base_size`.
  Skills tellen mee via `StatCalc.player_value`. Eén kogel met spreiding krijgt een willekeurige afwijking.
- **Loot uit de SSOT** (rij van het type of een eigen vijand-rij): `base_loot_drop` (minimum), `loot_drop_max`,
  `loot_drop_chance` (kans op telkens één extra). Light en heavy: 3 / 10 / 0.5, factory 0 (fabrieken droppen nog niets).
  Splatter: `base_loot_splatter` = maximale snelheid; leeg = standaard uit `loot_splatter.gd`.
- **Kamers vullen (seed + factie-oorlog).** `Systems/room_populator.gd` zet bij het laden van een kamer fabrieken
  neer (`Entities/Spawners/factory.tscn`). Eigenaar uit `FactionWar.get_room_owner`, plekken en type uit
  `RunState.room_seed(ring, kamer, generatie)`. De vaste testfabrieken in `game_room.tscn` zijn weg. RunState onthoudt
  per kamer `pop_owner`, `pop_gen`, `pop_count`; na leegmaken + herbezetting komt er een nieuwe generatie.
  Instellingen in SSOT-rij `world`: `room_factory_min/max`, `room_heavy_chance`, `room_grunts_per_factory`,
  `room_heavies_per_factory` (leeg = standaard in het script). Polen (ring 0 en de laatste) blijven leeg.
- **Seed:** `RunState.run_seed` (bewaard in de save); hoofdmenu heeft een veld "Seed" (leeg = willekeurig, tekst
  wordt een getal). F1 toont seed, ring, kamer en eigenaar.
- **Loot:** `Entities/Loot/loot_drops.gd` (LootDrops) voor vijanden én fabrieken. Kolom `loot_drop_type`
  (olrite, metal, ...). Fabrieken droppen Metal (5 / 15 / 0.5).
- **Wapens:** toetsen 1 t/m 0 = de wapens in SSOT-volgorde, `[` en `]` bladeren door alle wapens. Nieuwe rijen:
  railgun, raketwerper, zuursproeier, magneetkanon, stralingsmortier, stuiterbal, golfkanon (en laserbeam ingevuld).
  Homing, explosies, zuur/straling over tijd en stuiteren bestaan nog alleen als kolommen; de kogel doet er nog niets mee.

- **Loot klontert samen** (`loot_drop.gd`): blokjes van dezelfde grondstof drijven na `loot_merge_delay` langzaam
  (`loot_merge_speed`) naar elkaar toe binnen `loot_merge_radius` (rij `world`, leeg = standaard) en worden stenen,
  klompjes en losse blokjes. Groottes per grondstof: `loot_chunk_small` / `loot_chunk_large` (olrite 15/97, metal 8/90).
- **Muzzles:** de speler schiet uit `base_muzzle_count` lopen naast elkaar; F1 kan dat overschrijven (SSOT, 1, 2, 4).
