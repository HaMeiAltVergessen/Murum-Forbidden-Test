# Puzzle-System für Godot 4.4

Vollständiges Puzzle-Architektur-System mit 4 implementierten Rätseln.

## 📁 Struktur

```
puzzles/
├── base/                      # Basis-Klassen (wiederverwendbar)
│   ├── puzzle_switch.gd       # Basis für alle Schalter
│   ├── puzzle_controller.gd   # Basis für alle Controller
│   └── puzzle_target.gd       # Basis für Türen/Barrieren
├── controllers/               # Spezifische Puzzle-Controller
│   ├── sequence_puzzle_controller.gd      # R1: Schalter-Sequenz
│   ├── dual_plate_puzzle_controller.gd    # R2: Druckplatten-Gegner
│   ├── chain_puzzle_controller.gd         # R3: Kristall-Kette
│   └── timed_door_controller.gd           # R4: Zeitfenster-Tür
├── scenes/                    # Fertige Puzzle-Szenen
│   ├── sequence_puzzle.tscn
│   ├── pressure_plate_puzzle.tscn
│   ├── crystal_chain_puzzle.tscn
│   ├── timed_door_puzzle.tscn
│   └── puzzle_block.tscn
├── pressure_plate.gd          # Druckplatten-Komponente
├── puzzle_crystal.gd          # Kristall-Komponente (mit Piercing)
├── timed_switch.gd            # Zeitbasierter Schalter
├── timed_door.gd              # Zeitbasierte Tür
└── puzzle_block.gd            # Visuelles Feedback (schwarz → weiß)
```

## 🎮 Implementierte Rätsel

### R1 - Schalter-Sequenz
**Konzept:** Drei Schalter müssen in der richtigen Reihenfolge (1-2-3) mit Staff Throw getroffen werden.

**Features:**
- Grünes Feedback bei korrektem Treffer
- Rotes Blinken + Reset bei falscher Reihenfolge
- Automatische Sequenz-Validierung

**Test:** Staff Throw auf Schalter 1, dann 2, dann 3 werfen.

---

### R2 - Druckplatten-Gegner
**Konzept:** Zwei Druckplatten müssen gleichzeitig von Gegnern besetzt werden.

**Features:**
- Nur Gegner aktivieren die Platten (nicht Spieler)
- Runenstoß schiebt Gegner auf Platten
- Gegner bleiben auf Platten (AI-Integration)

**Test:** Zwei Untote mit Runenstoß auf beide Platten schieben.

---

### R3 - Kristall-Kette
**Konzept:** Vier Kristalle müssen in einem einzigen Staff Throw getroffen werden.

**Features:**
- Staff durchbohrt Kristalle (pierce_delay: 0.1s)
- Chain-Timeout: 0.5s zwischen Treffern
- Cyan-Glow bei Aktivierung

**Test:** Staff Throw horizontal durch alle 4 Kristalle werfen.

---

### R4 - Zeitfenster-Tür
**Konzept:** Schalter öffnet Tür für 3 Sekunden.

**Features:**
- Wiederholbare Aktivierung
- Leerenschritt-Integration (Void Step)
- Timer-basierte Auto-Schließung

**Test:** Schalter aktivieren, innerhalb 3s zur Tür laufen (oder Void Step nutzen).

---

## 🔧 Visuelle Feedback-Systeme

### PuzzleBlock
Schwarze Blöcke die weiß werden wenn Rätsel gelöst werden.

**Setup:**
```gdscript
# In Scene-Editor:
- Erstelle PuzzleBlock instance
- Setze puzzle_controller auf NodePath zum Controller
- Block färbt sich automatisch weiß bei puzzle_solved Signal
```

**Im TestRoom:** 4 Blöcke oben links (Position 100-400, Y:100)

---

## 🎨 Collision Layers

### Wichtig für Staff Throw Integration:
- **Layer 8:** Interactable (PuzzleSwitch)
- **Layer 9:** Detection (PressurePlate)
- **Layer 11:** Projectiles (Staff Throw, für Kristalle)

### Konfiguration:
```gdscript
# PuzzleSwitch: Automatisch monitoring = true, monitorable = true
# PuzzleCrystal: collision_mask inkludiert Layer 11
# PressurePlate: Body detection für CharacterBody2D
```

---

## 📦 Integration in eigene Level

### 1. Puzzle-Szene instanzieren
```
Puzzles Node2D hinzufügen
└── R1_SequencePuzzle instance
```

### 2. PuzzleBlock verbinden
```gdscript
PuzzleBlock.puzzle_controller = NodePath("../Puzzles/R1_SequencePuzzle/SequencePuzzleController")
```

### 3. Optional: Custom Target
```gdscript
# Controller hat puzzle_solved Signal
controller.puzzle_solved.connect(my_door.unlock)
```

---

## 🔊 Audio Hooks (Optional)

Falls AudioManager vorhanden:
- `puzzle/switch_activate` - Schalter aktiviert
- `puzzle/plate_pressed` - Platte gedrückt
- `puzzle/crystal_hit` - Kristall getroffen
- `puzzle/door_open` - Tür öffnet
- `puzzle/puzzle_solved` - Rätsel gelöst
- `puzzle/puzzle_failed` - Rätsel fehlgeschlagen
- `puzzle/block_solved` - Block färbt sich weiß

Falls nicht vorhanden: System funktioniert ohne Audio.

---

## 🧪 TestRoom Integration

**Location:** `levels/test_room.tscn`

**Positionen:**
- R1 Sequence: (200, 350) - Links oben
- R2 Pressure Plates: (450, 750) - Links mitte, auf Platform1
- R3 Crystal Chain: (900, 600) - Mitte, auf Platform2
- R4 Timed Door: (1300, 400) - Rechts, auf Platform3

**Puzzle Blocks:** (100-400, 100) - Oben links, 4 schwarze Blöcke

---

## 🚀 Erweitungsoptionen

### Neue Rätsel erstellen:
1. Erstelle neuen Controller (extends PuzzleController)
2. Überschreibe `check_solution() -> bool`
3. Emitte `solve()` wenn Bedingung erfüllt
4. Erstelle Scene mit Controller + Komponenten
5. Instanziere in Level

### Beispiel:
```gdscript
extends PuzzleController
class_name MyCustomPuzzleController

func check_solution() -> bool:
    return my_condition_met

func _on_something_happened():
    if check_solution():
        solve()
```

---

## 📝 Godot 4.4 Spezifisch

### Wichtige Änderungen vs 4.3:
- `monitoring = true` explizit setzen in Area2D._ready()
- `monitorable = true` explizit setzen
- Timer: `one_shot = true` explizit definieren
- Signals: Typisierte Parameter für IDE-Support
- `collision_mask` und `collision_layer` explizit nutzen

---

## ✅ Checkliste für Puzzle-Testing

- [ ] Staff Throw trifft PuzzleSwitch
- [ ] Runenstoß schiebt Enemy auf PressurePlate
- [ ] Staff durchbohrt alle Kristalle in einer Linie
- [ ] Timed Door schließt nach 3 Sekunden
- [ ] PuzzleBlock färbt sich weiß bei Lösung
- [ ] Audio-Feedback (falls aktiviert)
- [ ] Visuelle Effekte (Farben, Partikel)
- [ ] Reset funktioniert bei Fehlschlag

---

## 🐛 Bekannte Limitierungen

1. **R2 Pressure Plates:** Gegner-AI muss angepasst werden, damit sie auf Platten bleiben (aktuell: Proof of Concept)
2. **R3 Crystal Chain:** Staff muss perfekt horizontal geworfen werden (keine Kurven)
3. **R4 Timed Door:** Kein visueller Timer-Countdown (nur interne Logik)

---

Erstellt für **Murum-Forbidden-Test** | Godot 4.4
