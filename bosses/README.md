# Boss Fight Framework

Wiederverwendbares Boss-Fight-System mit Phasen-Management, Attack-Pattern-Rotation, dynamischer Kamera und Victory-Sequenz.

## Architektur

### Base Boss Template
- **boss_base.tscn** - Template-Szene für alle Bosse
- **boss_base.gd** - Framework-Logik (abstrakte Klasse)

### Komponenten

#### PhaseManager (`components/phase_manager.gd`)
- HP-basiertes Phasen-System
- Automatische Phase-Übergänge bei HP-Thresholds
- Invulnerability während Transitions

#### AttackPatternManager (`components/attack_pattern_manager.gd`)
- Attack-Pattern-Rotation
- Cooldown-Management
- Pattern-Wechsel pro Phase

#### BossCameraController (`components/boss_camera_controller.gd`)
- Boss-spezifischer Zoom
- Dynamischer Focus (Midpoint Boss + Player)
- Camera Shake Effekte

#### VictorySequence (`components/victory_sequence.gd`)
- Death-Animation
- Loot-Drops (Gold + Items)
- Unlock-Flags setzen
- Victory-Screen

### Health Component
- **health_component_generic.gd** - Wiederverwendbare HP-Komponente
- Damage-Handling
- Invulnerability-System
- Signals für HP-Änderungen

### UI
- **ui/boss_health_bar.tscn** - Boss HP Bar
- **ui/boss_health_bar.gd** - HP Bar Controller
  - Boss Name
  - HP Anzeige
  - Phase Indicator
  - Farb-Feedback (grün -> orange -> rot)

## Boss erstellen

1. **Scene erstellen**: Neue Scene, erbt von `boss_base.tscn`
2. **Script erstellen**: Erbt von `BaseBoss`
3. **Stats konfigurieren**:
   ```gdscript
   boss_name = "Boss Name"
   max_health = 1500.0
   gold_reward = 750
   unlock_flag = "boss_defeated"
   ```
4. **Attack Patterns definieren**:
   ```gdscript
   phase_1_pattern = ["attack1", "attack2"]
   phase_2_pattern = ["attack1", "attack3", "attack2"]
   phase_3_pattern = ["attack3", "attack3", "special"]
   ```
5. **Attacks implementieren**:
   ```gdscript
   func execute_attack(attack_name: String) -> void:
       match attack_name:
           "attack1":
               await perform_attack1()
           "attack2":
               await perform_attack2()
   ```

## Beispiel: Lythrun Boss

Siehe `lythrun/lythrun_boss.gd` für minimale Implementierung.

## Phase-System

Phases wechseln automatisch bei HP-Thresholds:
- Phase 1: 100% - 60% HP
- Phase 2: 60% - 30% HP
- Phase 3: 30% - 0% HP

Thresholds sind konfigurierbar in `PhaseManager.phase_thresholds`.

## Signals

### BaseBoss
- `health_changed(current_hp, max_hp)`
- `phase_changed(new_phase)`
- `defeated`
- `fight_started`

### PhaseManager
- `phase_changed(old_phase, new_phase)`
- `phase_transition_started(new_phase)`
- `phase_transition_ended(new_phase)`

### AttackPatternManager
- `attack_started(attack_name)`
- `attack_ended(attack_name)`
- `pattern_changed(new_pattern)`

## Utility Methods

### BaseBoss
- `set_invulnerable(bool)` - Setzt Invulnerability
- `get_player()` - Gibt Player-Node zurück
- `face_player()` - Boss schaut zum Spieler
- `execute_attack(name)` - Führt Attack aus (überschreiben!)

## Placeholder Assets

Aktuell sind folgende Placeholder vorhanden:
- `vfx/boss/boss_death_explosion.tscn`
- `hitboxes/boss_slam_hitbox.tscn`
- `hitboxes/boss_aoe_ring.tscn`
- `projectiles/boss_staff_projectile.tscn`

Diese sollten später durch richtige VFX/Hitboxes ersetzt werden.

## TODO

- [ ] Lythrun Boss vollständig implementieren (aktuell nur Stub)
- [ ] Echte Animationen für Lythrun erstellen
- [ ] VFX für Phase-Transitions
- [ ] Boss-Victory-Screen UI
- [ ] Audio-Integration (Boss-Musik, SFX)
- [ ] Weitere Bosse: Lin, World-III-Boss
