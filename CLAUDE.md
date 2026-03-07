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
traps/                Pfeilfallen, Fallende Steine, Treibsand
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

## Welt-/Raumstruktur

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

## Gegner & Bosse

**Basis**: `enemies/base_enemy.gd` (alle Gegner erben davon)
**World 1 Gegner**: Geist, Hermit, Guardian Statue, Glimmerseed, Corpse Trap
**Placeholder**: Ashworm (small/medium/large), Dark Fantasy, Monster Creature
**Lythrun-Boss**: `bosses/lythrun/lythrun_boss.gd` mit `adaptive_ai.gd` und Phase-Manager
**Boss-Komponenten**: `bosses/components/` — AttackPatternManager, PhaseManager, VictorySequence, BossCameraController

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

## Roguelike-Vision (GEPLANT — noch nicht implementiert)

**Kernkonzept**: Hybrid-Roguelike. Feste handcrafted Raeume, Roguelike-Struktur von Anfang an.

### Hub: Limbus
- Dunkler Raum, Siegel-Visualisierung oben zum Einstellen, Licht-Tuer zum Starten
- Von Anfang an der zentrale Startpunkt (kein separater Story-Modus)
- 3 Save-Slots (bereits in SaveManager implementiert)

### Run-Struktur
- **Slay the Spire-artige Pfadwahl**: Spieler waehlt zwischen 2-3 naechsten Raeumen
- **Begrenzte Leben pro Run**: X Leben, alle weg = zurueck zum Limbus
- **Siegel-Modifikatoren** beeinflussen den gesamten Run (Gegner-HP, Schaden, Spawns, etc.)

### Meta-Progression (wie Hades)
- Permanente Upgrades zwischen Runs
- Waehrung aus Runs wird im Hub fuer Upgrades ausgegeben
- Mehr HP, neue Faehigkeiten, Gameplay-Verbesserungen

### Noch zu implementieren
- [ ] Limbus-Hub-Szene (dunkler Raum + Siegel + Licht-Tuer)
- [ ] Save-Slot-Auswahl-UI im Hauptmenue
- [ ] Run-Map (Slay the Spire Verzweigungsmap)
- [ ] Run-Routing-System (Raum-Pools, Pfad-Generierung)
- [ ] Leben-System (X Leben pro Run)
- [ ] Run-Ende-Screen (Belohnungen, Statistiken)
- [ ] Meta-Progression-System (permanente Upgrades)
- [ ] Meta-Waehrungs-System (Run-Belohnungen)
- [ ] Hub-Upgrade-NPCs/Stationen

## Bekannte TODOs

- Gameplay-Effekte der meisten Siegel-Modifikatoren sind data-only (nicht implementiert)
- Nur World 1 (Ruins) existiert mit Raeumen
- Gegner sind teilweise Placeholder
- Kein Procedural Generation vorhanden
- Roguelike-Umbau steht bevor (siehe oben)
