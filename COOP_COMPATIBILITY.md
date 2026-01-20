# 🔴 COOP-KOMPATIBILITÄT UPDATE

## Problem behoben!
Das Puzzle- und Fallen-System war ursprünglich nur für Single-Player ausgelegt. **JETZT VOLLSTÄNDIG COOP-KOMPATIBEL!**

---

## ✅ Behobene Probleme

### 1. Spieler-Erkennung
**Vorher:** Nur `is_in_group("player")` → Nur P1 erkannt
**Jetzt:** `is_in_group("player") or is_in_group("player2")` → **Beide Spieler** erkannt

**Betroffene Dateien:**
- `puzzles/base/puzzle_switch.gd` ✅
- `puzzles/pressure_plate.gd` ✅
- `puzzles/puzzle_crystal.gd` ✅
- `traps/base/trap_base.gd` ✅
- Alle spezifischen Traps ✅

---

### 2. Projektil-Erkennung
**Vorher:** Nur `staff_projectile` → Nur P1 Staff Throw
**Jetzt:** `staff_projectile OR shadow_scythe` → **Beide Projektile** erkannt

**Betroffene Dateien:**
- `puzzles/base/puzzle_switch.gd` Line 102 ✅
- `puzzles/puzzle_crystal.gd` Line 64 ✅

```gdscript
# JETZT:
if area.is_in_group("staff_projectile") or area.is_in_group("staff_projectiles") or area.is_in_group("shadow_scythe"):
    var owner_player = area.get_meta("owner_player", null) if area.has_meta("owner_player") else area.owner
    activate(owner_player)
```

---

### 3. Signal-Signaturen mit Activator-Tracking
**Vorher:** Signals ohne Aktivator-Info
**Jetzt:** Alle Signals tracken **wer** aktiviert hat

**Neue Signal-Signaturen:**
```gdscript
# PuzzleSwitch
signal switch_activated(switch_id: int, activator: Node2D)  # NEU: activator Parameter

# PressurePlate
signal plate_pressed(activator: CharacterBody2D)  # Schon vorhanden
signal plate_released(last_activator: CharacterBody2D)  # NEU: last_activator

# PuzzleCrystal
signal crystal_hit(projectile_owner: Node2D)  # NEU: projectile_owner

# TrapBase
signal entity_damaged(entity: Node2D, damage: int)  # NEU: entity statt nur damage
```

---

### 4. Controller-Updates
Alle Controller akzeptieren jetzt die neuen Signal-Parameter:

**SequencePuzzleController:**
```gdscript
func _on_switch_hit(switch_id: int, activator: Node2D) -> void:
    print("Switch %d hit by %s" % [switch_id, activator.name if activator else "unknown"])
```

**ChainPuzzleController:**
```gdscript
func _on_crystal_hit(projectile_owner: Node2D, crystal: Node) -> void:
    print("Crystal hit by %s" % (projectile_owner.name if projectile_owner else "unknown"))
```

**TimedDoorController:**
```gdscript
func _on_switch_activated(_switch_id: int, _activator: Node2D) -> void:
    # Activator tracked
```

---

### 5. Multi-Body-Tracking (Pressure Plates)
**Vorher:** Single body tracking
**Jetzt:** `bodies_on_plate: Array[CharacterBody2D]` → **Mehrere Bodies gleichzeitig**

```gdscript
# pressure_plate.gd Line 26
var bodies_on_plate: Array[CharacterBody2D] = []

func _on_body_entered(body: Node2D):
    if char_body not in bodies_on_plate:
        bodies_on_plate.append(char_body)
```

---

### 6. Trap-Flexibilität
**Vorher:** Nur Player-Damage
**Jetzt:** Konfigurier bar für **Players UND/ODER Enemies**

```gdscript
# trap_base.gd
@export var affect_players: bool = true  # NEU
@export var affect_enemies: bool = false  # NEU

func deal_damage(body: Node2D):
    var is_player = body.is_in_group("player") or body.is_in_group("player2")
    var is_enemy = body.is_in_group("enemies") or body.is_in_group("enemy")

    if (is_player and affect_players) or (is_enemy and affect_enemies):
        # Deal damage
```

---

## 🎮 Coop-Gameplay Features

### Beide Spieler können jetzt:
- ✅ Puzzle-Switches aktivieren (P1 + P2)
- ✅ Projektile nutzen (Staff Throw + Shadow Scythe)
- ✅ Druckplatten aktivieren (beide gleichzeitig möglich)
- ✅ Kristalle treffen (beide Projektil-Typen durchbohren)
- ✅ Fallen triggern (beide nehmen Damage)
- ✅ Zeitfenster-Türen nutzen (Leerenschritt + Phase Shift)

### Kooperative Rätsel möglich:
```gdscript
# Beispiel: Beide Spieler müssen gleichzeitig auf Platten stehen
@export var requires_both_players: bool = true

func check_puzzle_solved():
    if requires_both_players:
        var has_p1 = bodies_on_plate.any(func(b): return b.is_in_group("player"))
        var has_p2 = bodies_on_plate.any(func(b): return b.is_in_group("player2"))
        return has_p1 and has_p2
```

---

## 📦 Wichtige Gruppen-Namen

### Spieler:
- **P1 (Murum):** `"player"`
- **P2 (Lythrun):** `"player2"` (ohne Unterstrich!)

### Projektile:
- **P1 Staff Throw:** `"staff_projectile"` oder `"staff_projectiles"`
- **P2 Shadow Scythe:** `"shadow_scythe"`

### Entities:
- **Enemies:** `"enemies"` oder `"enemy"`
- **World:** `"world"` (für Wände/Boden)

---

## 🔧 Metadata für Projektil-Ownership

Projektile sollten ihren Owner als Metadata speichern:

```gdscript
# In Staff Throw / Shadow Scythe Spawn:
var projectile = projectile_scene.instantiate()
projectile.set_meta("owner_player", self)  # self = Player Node
projectile.add_to_group("staff_projectile")  # oder "shadow_scythe"
get_parent().add_child(projectile)
```

Dann können Puzzles tracken wer das Projektil geworfen hat:
```gdscript
var owner_player = area.get_meta("owner_player", null) if area.has_meta("owner_player") else area.owner
```

---

## 🎯 Testing Checklist

### Puzzle-System:
- [ ] P1 kann Switches mit Staff Throw treffen
- [ ] P2 kann Switches mit Shadow Scythe treffen
- [ ] Beide Spieler können Druckplatten aktivieren
- [ ] Beide Projektile durchbohren Kristalle
- [ ] Zeitfenster-Tür funktioniert mit beiden Mobility-Skills

### Fallen-System:
- [ ] Beide Spieler nehmen Damage von Falling Rocks
- [ ] Beide Spieler nehmen Damage von Arrow Traps
- [ ] Arrow Parry funktioniert für beide
- [ ] Quicksand zieht beide Spieler
- [ ] Fallen können optional auch Enemies treffen (`affect_enemies = true`)

---

## 📝 Migration Guide

Falls alte Level angepasst werden müssen:

1. **Projektile:** Stelle sicher dass Shadow Scythe zur Gruppe `"shadow_scythe"` hinzugefügt wird
2. **Metadata:** Füge `set_meta("owner_player", self)` beim Projektil-Spawn hinzu
3. **Traps:** Optional `affect_enemies = true` für strategische Fallen
4. **Dual-Player Puzzles:** Nutze `requires_both_players = true` für echte Coop-Mechaniken

---

## ✨ Zukunftssichere Architektur

Das System ist jetzt designed für:
- ✅ Beliebig viele Spieler (erweiterbar auf P3, P4...)
- ✅ Verschiedene Projektil-Typen
- ✅ Flexible Entity-Targeting (Players/Enemies/Custom)
- ✅ Metadata-basiertes Ownership-Tracking
- ✅ Kooperative und kompetitive Mechaniken

**Erstellt für Murum-Forbidden-Test | Godot 4.4**
