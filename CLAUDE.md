# Murum - Projektdokumentation

2D Action-Roguelike in Godot 4 (GDScript). 1920x1080, Viewport-Stretch.
Hauptszene: `ui/menus/main_menu.tscn`. Zwei spielbare Charaktere: Murum (P1) + Lythrun (P2, Coop).

## Verzeichnisstruktur

```
core/autoloads/       17 Autoload-Singletons (GameManager, EventBus, etc.)
player/               Murum (murum.gd) + Lythrun (lythrun_player.gd)
player/combat_system/ 20+ Kampfsysteme (combo, parry, rebound, machtbruch, etc.)
player/abilities/     Spezialfaehigkeiten (wolkenbruch, echo, myrkurs_echo, urgathon_will)
enemies/              base_enemy.gd + World-1-Gegner (geist, hermit, guardian_statue, etc.)
bosses/               boss_base.gd + Lythrun-Boss mit adaptiver AI
worlds/               Weltstruktur: world_1_ruins mit 4 Sektionen, 15+ Raeume
levels/               test_room.tscn, item_room.tscn
environment/          Tueren, Checkpoints, NPCs, Pickups, Interactables
traps/                Fallen-System (W1: Pfeil, Stein, Treibsand, Stachel, Pendel)
traps/world_2/        W2 Sci-Fi Fallen (Turret, Elektropanel, Gravitation, Laser, Kraftfeld, Drohne)
traps/world_3/        W3 Horror Fallen (Void-Riss, Auge, Ranke, Phasen-Plattform, Zeitverzerrung)
puzzles/              Druckplatten, Kristalle, Bloecke, Zeittueren
ui/                   HUD, Menues, Inventar, Shop, Notifications
systems/              Cutscene, Dialog, Input-Remapping
data/                 JSON-Datenbanken (Items, Achievements, Shops, Dialoge)
components/           health_component_generic, hitbox, hurtbox
vfx/                  Partikeleffekte (Parry, Wolkenbruch, Leap, etc.)
camera/               Coop-Kamera, Split-Screen-Manager
```

## Autoload-Singletons (Ladereihenfolge in project.godot)

| Singleton | Datei | Funktion |
|-----------|-------|----------|
| GameManager | `core/autoloads/game_manager.gd` | Spielstatus (MENU/PLAYING/PAUSED/GAME_OVER), Respawn, Fortschritt |
| EventBus | `core/autoloads/event_bus.gd` | Zentraler Signal-Bus (100+ Signals) |
| AudioManager | `core/autoloads/audio_manager.gd` | Sound/Musik |
| CombatManager | `core/autoloads/combat_manager.gd` | Kampf-Koordination |
| GlobalTimeEffects | `core/autoloads/global_time_effects.gd` | Hitstop, Zeitlupe |
| SettingsManager | `core/autoloads/settings_manager.gd` | Einstellungen |
| SaveManager | `core/autoloads/save_manager.gd` | 3 Save-Slots (MAX_SLOTS=3), JSON in user://saves/slot_X.json |
| WorldManager | `core/autoloads/world_manager.gd` | Raum-Transitionen, Welt-Progression, Checkpoints |
| InventoryManager | `core/autoloads/inventory_manager.gd` | Items/Relikte/Consumables, P2-Mirror |
| ShopManager | `core/autoloads/shop_manager.gd` | Haendler-System |
| InputManager | `core/autoloads/input_manager.gd` | Input-Verwaltung |
| CoopManager | `core/autoloads/coop_manager.gd` | P2-Beitritt, Split-Screen |
| HUDManager | `core/autoloads/hud_manager.gd` | HUD-Verwaltung, show/hide |
| StatisticsManager | `core/autoloads/statistics_manager.gd` | 14 Gameplay-Statistiken (Kills, Tode, Schaden, etc.) |
| AchievementManager | `core/autoloads/achievement_manager.gd` | 11 Achievements, JSON-Definitionen aus data/achievements.json |
| ChallengeRunManager | `core/autoloads/challenge_run_manager.gd` | 33 Siegel-Modifikatoren, Tiefe-System, Schwellensicht |
| RewardManager | `core/autoloads/reward_manager.gd` | Belohnungs-Pools pro Raumtyp & Welt |
| BoonManager | `core/autoloads/boon_manager.gd` | 5 Pachron-Pfade (25 Boons), Run-volatil |
| BoonEffectHandler | `core/autoloads/boon_effect_handler.gd` | Alle 25 Boon-Effekte (T1–T5) + 10 Sync-Effekte via EventBus |
| SyncSkillManager | `core/autoloads/sync_skill_manager.gd` | 10 Pachron-Sync-Skills (Paar-Kombinationen), Run-volatil |
| MusicScenePlayer | `core/autoloads/music_scene_player.tscn` | Musik pro Szene |

## Kampfsystem (P1 Murum)

| System | Datei | Beschreibung |
|--------|-------|-------------|
| Combo | `player/combat_system/combo_tracker.gd` | 3-Hit-Combos mit Finisher |
| Parry/Block | `player/combat_system/parry_block_system.gd` | Raeumlich: Ring (Perfect Parry) + Sphere (Block) |
| Rebound | `player/combat_system/` | 3 Parries → Rebound-Counter |
| Machtbruch | `player/combat_system/machtbruch.gd` | Aufladbare AoE-Explosion (3 Stufen) |
| Machtstoss | `player/combat_system/machtstoss.gd` | Knockback-Welle mit Cooldown |
| Urteil | `player/combat_system/urteil.gd` | Todesmal → Explosion bei Tod |
| Echo | `player/combat_system/echo.gd` | Temporaerer Mana-Regen bei Treffern |
| Resonanz | `player/combat_system/resonance_system.gd` | Meter → Resonanz-Modus (Schadens-Boost) |
| Launcher | `player/combat_system/launcher_system.gd` | Gegner in die Luft schleudern |
| Air Combo | `player/combat_system/air_combo_system.gd` | Luftkampf-Combos |
| Luftgott | `player/combat_system/luftgott_system.gd` | Air Reset nach Air Combo |
| Leap Ender | `player/combat_system/leap_ender_system.gd` | Sprung-Finisher |
| Wolkenbruch | `player/abilities/wolkenbruch.gd` | Luft-Slam (normal/powered) |
| Dodge Roll | `player/dodge_roll_system.gd` | i-Frames Ausweichen |
| Weapon Glow | `player/combat_system/weapon_glow_system.gd` | Waffen leuchten bei Combos |
| Phase Shift | `player/combat_system/phase_shift_system.gd` | (P2 Lythrun) |
| Shadow Dash | `player/combat_system/shadow_dash_system.gd` | (P2 Lythrun) |
| Shadow Scythe | `player/combat_system/shadow_scythe_system.gd` | (P2 Lythrun) |
| Void Systems | `player/combat_system/void_*.gd` | (P2 Lythrun) Orbs, Parry, Rift |

## Siegel-System (33 Modifikatoren) — "Ebenen des Deliriums"

Verwaltet von `ChallengeRunManager`. 6 Kategorien mit gewichteter Tiefe (max 59 Punkte):

| Kategorie | Anzahl | Tiefe/Stueck | Farbe | Beispiele |
|-----------|--------|-------------|-------|-----------|
| Kern-Qualen | 8 | 1 | Gold | zaeher_alptraum, endlose_schatten, schmerz, schwindendes_bewusstsein |
| Albtraum-Qualen | 6 | 3 | Lila | fluesternde_schattenhorden, risse_der_vergangenheit, der_wahre_traum |
| Koerper-Qualen | 8 | 1 | Rot | schwere_last, schlafwanderer, gespaltene_persoenlichkeit |
| Myrkur-Qualen | 3 | 3 | Dunkel-Lila | myrkurs_blick, myrkurs_schleier, myrkurs_gelaechter |
| Voch Numta-Qualen | 3 | 2 | Blass-Gold | urteil_der_voch_numta, zerbrochene_statue |
| Urgathon-Qualen | 5 | 2 | Cyan | versiegelt_in_stille, die_vergessenen |

**Tiefenstufen** (7 Stufen): "Der ruhige Traum" (0) → "Die versiegelte Wahrheit" (30+)
**Schwellensicht**: Aktiviert ab 50% Tiefe — kosmisches Horror-Overlay (`ui/hud/schwellensicht_overlay.gd`)

**UI**: Kreisfoermiges Siegel mit 3 Ringen (`ui/menus/challenge_run_menu.gd`)
- Aussen (r=320): Kern + Albtraum (14 Knoten)
- Mitte (r=220): Koerper (8 Knoten)
- Innen (r=130): Myrkur + Voch Numta + Urgathon (11 Knoten)

## Fallen-System (pro Welt thematisch)

### Welt 1: Ruinen (Fantasy)
| Falle | Datei | Mechanik |
|-------|-------|----------|
| Pfeilfalle | `traps/arrow_trap.gd` | 3 Modi (Druckplatte/Proximity/Immer), parry-bar (1.5x reflekt) |
| Fallender Stein | `traps/falling_rock.gd` | Proximity-Trigger, Warning, 35 DMG Radius |
| Treibsand | `traps/quicksand_pit.gd` | Pull + 10 DMG/s + Soforttod nach 5s |
| Stachelfalle | `environment/hazards/spike_trap.gd` | Zyklisch: OFF→WARNING→ACTIVE, 20 DMG |
| Pendelklinge | `traps/pendulum_blade.gd` | 2 Modi (RHYTHMIC/TRIGGERED), 25 DMG, nicht parry-bar |
| Leichenfalle | `enemies/world_1_ruins/corpse_trap.gd` | Zerstoerbar, spawnt Glimmerseeds |

### Welt 2: Das Kollektiv (Sci-Fi)
| Falle | Datei | Mechanik |
|-------|-------|----------|
| Energieturret | `traps/world_2/energy_turret.gd` | Rotiert+zielt, parry-bare Bolts, Stun→Boden→Emerge |
| Elektropanel | `traps/world_2/electro_panel.gd` | Zyklisch elektrifiziert, Sync-Groups, 20 DMG |
| Gravitationsanomalie | `traps/world_2/gravity_anomaly.gd` | Sci-Fi Treibsand, staerker (250 Pull, 4s Tod) |
| Laserwand | `traps/world_2/laser_wall.gd` | Sweept durch Raum (H/V/Rotating), 2s Warning |
| Kraftfeld | `traps/world_2/force_field.gd` | Blockiert physisch + DoT, Schalter-deaktivierbar |
| Sicherheitsdrohne | `traps/world_2/security_drone.gd` | Patrouilliert, feuert Bursts, zerstoerbar (respawnt) |

### Welt 3: Der Abgrund (Kosmischer Horror)
| Falle | Datei | Mechanik |
|-------|-------|----------|
| Void-Riss | `traps/world_3/void_rift_trap.gd` | Teleportiert Spieler zu zufaelligem Punkt, 10 DMG |
| Kosmisches Auge | `traps/world_3/cosmic_eye.gd` | DoT-Strahl bei Sichtlinie, zerstoerbar (HP=40) |
| Schattenranke | `traps/world_3/shadow_tendril.gd` | Grab (4x Angriff befreien), P2 kann Ranke zerstoeren |
| Phasen-Plattform | `traps/world_3/phase_platform.gd` | SOLID→WARNING→PHASED Zyklus, Gruppen-Sync |
| Zeitverzerrung | `traps/world_3/time_distortion.gd` | Zone verlangsamt Spieler auf 40% (Gegner normal) |

## Run-Map (Hades-Style Knoten-Netz)

### Grundregeln (alle Welten)
- Hades-Style Knoten-Netz mit Reihen (NICHT Slay the Spire Spalten)
- Belohnungs-Vorschau: Icons ueber waehlbaren Knoten
- Kampf-Knoten enthalten IMMER Raetsel- und/oder Fallen-Elemente (keine reinen Kampfraeume)
- 1 Rast-Hub pro Welt (Mitte), volle Heilung, NPCs

### Knotentypen
- **K+R** = Kampf+Raetsel (Haupttyp)
- **E+R** = Elite+Raetsel (haerter, Pre-Boss)
- **S** = Schatz (Wahl aus 3 Items)
- **RAST** = Mini-Hub mit NPCs, volle Heilung
- **Er** = Ereignis (Text-Event, ab Welt 2)
- **BOSS** = Fester Abschlussknoten

### Welt 1: Das Niemandsland (Fantasy)
- Thema: Schuld & Legende, neblige Steppe, Tempel
- 3 Reihen + Boss, 8-9 Knoten, ~10-15 Min
- Gegner: Geist, Hermit, Glimmerseed, Ashworm Small
- Raetsel: Druckplatten, Kristalle, Zeitschalter
- Fallen: Pfeilfallen, fallende Steine
- Boss: "Die Schwuere der Vier" (Krieger, Magier, Priester, Schuetzin)
- Rast: "Zuflucht der Verlorenen"

### Welt 2: Das Kollektiv (Sci-Fi)
- Thema: Identitaet vs. Kontrolle, Neon-Slums, Orbit
- 4 Reihen + Boss, 12-13 Knoten, ~15-20 Min
- Gegner: NOCH NICHT DEFINIERT (Sci-Fi-Einheiten)
- Raetsel: Sequenz, Dual-Platten (Coop!), Zeittueren
- Fallen: Energiefelder, schnellere Pfeilfallen, Ketten-Steine
- Boss: "Das Kollektiv der Einen Stimme" (Raumschiff-Koerper)
- 1 Ereignis pro Run

### Welt 3: Der Abgrund (Kosmischer Horror)
- Thema: Selbstkonfrontation, verzerrter Raum
- 6 Reihen + Boss, 18-20 Knoten, ~25-30 Min
- Gegner: Alle aus W1+W2 + neue Abgrund-Varianten
- Raetsel: Alle kombiniert, Chain-Puzzles, Master-Doors
- Fallen: Alle gleichzeitig, schneller
- Boss: "Murum (Spiegel)" — identische Spiegelung, Endless-Runner
- Rast: "Der Letzte Lichtfunke"
- 2 Ereignisse pro Run
- Schwellensicht ab Reihe 3

## Welt-/Raumstruktur (bestehende Raeume)

```
worlds/world_1_ruins/
├── section_1_entrance/    room_01_entry, room_02_corridor, room_03_villageEntrance
├── section_2_villages/    room_04-10 (Dorf, Inn, Schmied, Paar, etc.)
├── section_3_tempel_outside/  room_02_village_path, room_11_temple_entrance
└── section_4_tempel/      TutorialRoom01-03, room_12_grand_hall, room_15_boss_urgathon
```

**Raumwechsel**: `WorldManager.change_room(world, section, room, spawn_point)`
**Checkpoints**: `environment/checkpoint.gd` — Speicherpunkte in Raeumen
**Tueren**: `environment/door.gd`, `environment/doors/boss_door.gd`
**Arena-System**: `worlds/arena_controller.gd` + `worlds/wave_spawner.gd` fuer Wellen-Kaempfe
**Wave-Config**: `worlds/run_rooms/combat_wave_holder.gd` — Inspector-konfigurierbare ArenaWaveConfig pro Raum (bis 3 Wellen)
**Run-Map-Overlay**: `ui/run_map/run_map_overlay.gd` — Weltkarte-Item oeffnet Karten-Overlay (CanvasLayer, Toggle via EventBus)

## Gegner & Bosse

**Basis**: `enemies/base_enemy.gd` (alle Gegner erben davon)
**World 1 Gegner**: Geist, Hermit, Guardian Statue, Glimmerseed, Corpse Trap
**Placeholder**: Ashworm (small/medium/large), Dark Fantasy, Monster Creature

### Welt 2 Gegner — Das Kollektiv (Sci-Fi) [DESIGNED, NICHT IMPLEMENTIERT]
| Gegner | Typ | HP | Mechanik | Coop |
|--------|-----|-----|----------|------|
| Sentinel Drone | Regular, Ranged | 35 | Networked Targeting (2+ Drones synchron) | Split Targeting |
| Enforcer | Regular, Melee Tank | 60 | Directional Armor (Front 60%, Back 0%) | Flanking noetig |
| Mender | Regular, Support | 25 | Heilt Verbuendete 8 HP/s, flieht | Kill-Priority-Koordination |
| Disruptor | Regular, Debuff | 40 | Frequenz-Feld (ROT=P1, LILA=P2 slow) | Abwechselnd durchs Feld |
| Vanguard | Elite | 200 | 80HP Schild (Front), 3-Hit Combo, Rally Cry | Front-Aggro + Back-DPS |
| Hivemind Nexus | Elite | 150 | Stationaer, spawnt Minions, immun bei 2+ Adds | Adds clearen → Boss bursten |

### Welt 3 Gegner — Der Abgrund (Kosmischer Horror) [DESIGNED, NICHT IMPLEMENTIERT]
| Gegner | Typ | HP | Mechanik | Coop |
|--------|-----|-----|----------|------|
| Phase Wraith | NEU, Melee | 50 | Phast durch Waende, materialisiert hinter Ziel | Back-to-Back stehen |
| Hollow Vessel | Korrumpierter Geist | 45 | Afterimage Split alle 3 Angriffe | Fake finden → Bonus-DMG |
| Abyssal Anchor | NEU, Control | 55 | Gravity Well (200px), doppelt bei 2 Spielern | Nie beide ins Feld |
| Breach Hulk | Korrumpierter Enforcer | 85 | Void Burst + Tendril Grab + Void Trail | P2 befreit P1 |
| Echo Siren | NEU, Debuff | 35 | Scream invertiert Steuerung 4s | Partner deckt Getroffenen |
| Hollow Mender | Korrumpierter Mender | 35 | Anti-Heal Beam, Heilung→Schaden | Sofort jagen + toeten |
| The Tethered | Elite, Dual | 240 | Warden+Beast an Kette, Kill Order matters | Jeder nimmt ein Wesen |
| The Witness | Elite, Caster | 180 | Gaze Beam wechselt P1↔P2, Blink=DMG-Window | Gaze Juggling |

**Sprite-Prompts**: `docs/enemy_sprite_prompts.md` (18 Sheets, 80 Frames)
**Design-Dokument**: `.claude/plans/cozy-puzzling-phoenix.md`
**Lythrun-Boss**: `bosses/lythrun/lythrun_boss.gd` mit `adaptive_ai.gd` und Phase-Manager
**Boss-Komponenten**: `bosses/components/` — AttackPatternManager, PhaseManager, VictorySequence, BossCameraController

### Run-Bosse
- **Welt 1**: "Die Heldengruppe" — 5-Helden-Gruppenkampf (Ritter, Kleriker, Blutjaeger, Barbar, Nekromant) [IMPLEMENTIERT]
  - `bosses/hero_group/` — HeroGroupController + HeroGroupMember Basisklasse + 5 Held-Subklassen
  - Taktische Kill-Reihenfolge, Last-Standing-Phasen, Necro-Resurrect
- **Welt 2**: "Das Kollektiv der Einen Stimme" — 5-Core-Modulkampf + Central Hub [IMPLEMENTIERT]
  - `bosses/kollektiv/` — KollektivController + KollektivCore Basisklasse + 5 Cores + Central Hub
  - 5 Cores: Energy (Reaktor), Defense (Waffen), Mobility (Navigation), Fabricator (Drohnen), Cognition (KI, geschirmt)
  - 4 Drohnentypen: Melee, Kamikaze, Ranged, Repair Bot
  - Eskalationssystem: Je mehr Cores zerstoert, desto aggressiver
  - Finale Phase: Alle Cores tot → Central Hub (80 HP) → Umgebungschaos
  - Kill-Order-Strategie: Spieler entscheidet Reihenfolge
- **Welt 3**: "Murum (Spiegel)" — Inverted Boss Fight als Auto-Scrolling Runner [IMPLEMENTIERT]
  - `bosses/mirror/` — MirrorController + MirrorBoss (CharacterBody2D) + RunnerCamera
  - Auto-Scrolling Runner durch 4 Abschnitte (Der Fall → Spiegelkampf → Abgrund → Finale)
  - MomentumSystem (0-100) statt HP: Parry/Combo steigert, Schaden senkt
  - 4 Finisher-Fenster bei MAX Momentum zum Besiegen (kein klassisches HP)
  - ChunkSpawner: 12 handcrafted Chunks (3 pro Abschnitt), procedural aneinandergereiht
  - Boss-Angriffe: Dark Orbs (parry-bar), Melee-Combo, Gravitaetsschnitt, Urteil-Spiegel
  - Entities: DarkOrb, SplittingPlatform, TimeFragment, UrteilMark
  - Defeat-Sequenz: Dialog + Boss-Dissolve + Fade to Black
  - P2 optional: Stirbt bei Todeszone, kein Game Over

### Veraltete Boss-Konzepte (NICHT MEHR GUELTIG)
- ~~Urgathon als Welt-1-Boss~~ → ersetzt durch "Die Heldengruppe"
- ~~"Die Schwuere der Vier"~~ → weiterentwickelt zu "Die Heldengruppe" (5 Helden statt 4 Geister)
- ~~Myrkur als Welt-3-Boss~~ → ersetzt durch "Murum (Spiegel)"

## UI-Screens

| Screen | Dateien |
|--------|---------|
| Hauptmenue | `ui/menus/main_menu.gd/.tscn` |
| Pause | `ui/menus/pause_menu.gd/.tscn` |
| Optionen | `ui/menus/options_submenu.gd/.tscn` |
| Steuerung | `ui/menus/controls_section.gd/.tscn` |
| Statistiken | `ui/menus/statistics_screen.gd/.tscn` |
| Achievements | `ui/menus/achievements_screen.gd/.tscn` |
| Challenge/Siegel | `ui/menus/challenge_run_menu.gd/.tscn` |
| Tod | `ui/death_screen.gd/.tscn` |
| Inventar | `ui/inventory/inventory.gd/.tscn` |
| Shop | `ui/shop/shop.gd/.tscn` |
| HUD | `ui/hud.gd/.tscn` + P1/P2 HUDs, Abilities, Combo, Resonanz, etc. |

## Save-System

- **3 Slots** (SaveManager.MAX_SLOTS = 3), JSON-Format
- Pfad: `user://saves/slot_X.json`
- Speichert: Player-State, Inventar, Progression, Statistiken, Achievements, Challenge-Run-State
- Auto-Save aktiv
- `SaveManager.save_current_game()` / `load_current_game()` / `has_save_file()`

## Wichtige Patterns & Konventionen

- **Sprache**: Code auf Englisch, Ingame-Texte auf Deutsch
- **Commit-Messages**: Deutsch, beschreibend
- **GDScript-Style**: snake_case, Typed GDScript (`: Type`), Sections mit `# ============` Bloecken
- **Signals**: Immer ueber `EventBus.signal_name.emit(...)` (zentraler Bus, keine direkten Verbindungen)
- **Raum-Pfade**: `worlds/{world_id}/{section_id}/{room_id}`
- **Items**: JSON in `data/items/` (consumables.json, relics.json, key_items.json, shadow_items.json)
- **Dialoge**: .tres Ressourcen in `data/dialogs/`
- **Musik**: .tres Ressourcen in `data/music/`

## Roguelike-Systeme

**Kernkonzept**: Hybrid-Roguelike. Feste handcrafted Raeume, Roguelike-Knoten-Netz-Struktur.

### Bereits implementiert
- [x] **UpgradeManager** (`core/autoloads/upgrade_manager.gd`) — 8 permanente Upgrades mit Magicka
- [x] **Limbus-Haendler** — Upgrades kaufen (HP, Schaden, Mana-Regen, Speed, Echo, Ability-Damage, etc.)
- [x] **Zusaetzliche Leben** beim Haendler fuer 2 Magicka kaufen
- [x] **Siegel-System** (33 Modifikatoren) — Schwierigkeitsmodifikation
- [x] **P2-Upgrade-Integration** — Alle Upgrades gelten fuer P1 UND P2 (`is Murum or is Lythrun` Checks)
- [x] **P2 Ability-Damage-Bonus** — Urgathons Erbe gilt fuer alle 4 P2-Abilities (Void Orbs, Void Parry, Void Rift, Shadow Scythe)
- [x] **P2 Kill-Heal** (Blut der Schlacht) — Mana/HP bei Kills
- [x] **P2 Echo der Macht** — Echo-Chance bei Angriffen in LythrunCombatSystem
- [x] **Run-Map-Generator** (`core/autoloads/run_manager.gd`) — Knoten-Netz pro Welt via RunMapData
- [x] **Run-Map-UI** — Weltkarte als kaufbares Key-Item (3 Magicka), CanvasLayer-Overlay (`ui/run_map/run_map_overlay.gd`)
- [x] **Raum-Pools** (`worlds/run_rooms/run_room_pool.gd`) — 11 handcrafted Raeume fuer Welt 1
- [x] **Wellen-Configs** (`worlds/run_rooms/combat_wave_holder.gd`) — Inspector-konfigurierbare ArenaWaveConfig pro Raum
- [x] **Run-Ende-Screen** — Belohnungen, Statistiken, Gegner-Zaehler, Zeit
- [x] **Limbus-Hub-Szene** — Dunkler Raum + Siegel-Altar + Licht-Tuer + Haendler
- [x] **Raelear-Boons ueberarbeitet** — Eigene .tscn (`player/abilities/raelear_clone.tscn`), Glimmerseed-AI, Chase+Explode/Mirror
- [x] **Raum-Reset** — `_clear_run_room_states()` bei neuem Run und Weltwechsel
- [x] Welt-1-Boss: "Die Heldengruppe" (5-Helden-Gruppenkampf)
- [x] Welt-2-Boss: "Das Kollektiv der Einen Stimme" (5-Core-Modulkampf + Central Hub)
- [x] Welt-3-Boss: "Murum (Spiegel)" (Auto-Scrolling Runner, 4 Abschnitte, Momentum-System)

### Noch zu implementieren
- [ ] Welt-2- und Welt-3-Gegner (Sci-Fi/Horror, DESIGNED — Sprites ausstehend, dann Implementierung)
- [ ] VFX-Polish (Placeholder-ColorRects durch echte Partikeleffekte ersetzen)
- [ ] Boss-Polish (Intro-Cutscene, Victory-Sequence, SFX, Balancing)
- [ ] Mirror-Boss-Polish (Despawning Platforms, mehr Chunk-Varianten)
- [ ] CC-Reduktion Upgrade-Effekt (einziger nicht-implementierter Upgrade-Effekt)
- [x] **Pachron Sync Skills** — 10 Paar-Kombinations-Skills (T5+T3+ Voraussetzung, 30%/60%/80% Chance)
  - `SyncSkillManager` Autoload, `data/boons/sync_skills.json`, 10 Sync-Dialog-Dateien
  - UI: Goldene Extra-Option im Boon-Choice-Screen, Dual-Pachron-Dialog
- [x] **W2/W3 Fallen-System** — 12 neue Fallen (1 W1 + 6 W2 + 5 W3)
  - W1: Pendelklinge (2 Modi), Treibsand P2-Bugfix
  - W2: Energieturret (Stun→Boden), Elektropanel, Gravitationsanomalie, Laserwand, Kraftfeld, Sicherheitsdrohne
  - W3: Void-Riss (Teleport), Kosmisches Auge (DoT-Strahl), Schattenranke (Grab+Coop), Phasen-Plattform, Zeitverzerrung

## Bekannte TODOs

- Gameplay-Effekte der meisten Siegel-Modifikatoren sind data-only (nicht implementiert)
- Nur World 1 (Ruins) existiert mit handcrafted Raeumen
- Gegner sind teilweise Placeholder (Ashworm, Dark Fantasy, Monster Creature)
- Welt 2 (Sci-Fi) und Welt 3 (Kosmischer Horror) Gegner designed (14 Gegner), Sprites ausstehend
- Raelear-Klone nutzen Murums Sprite aber noch ohne VFX-Polish
