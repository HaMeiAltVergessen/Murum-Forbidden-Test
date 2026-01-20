# Fallen-System für Godot 4.4

Vollständiges Fallen-Architektur-System mit 3 implementierten Fallen-Typen.

## 📁 Struktur

```
traps/
├── base/                      # Basis-Klassen
│   └── trap_base.gd           # Basis für alle Fallen
├── falling_rock.gd            # F2: Fallende Steine
├── arrow_trap.gd              # F3: Pfeilfallen
├── arrow_projectile.gd        # F3: Pfeil-Projektil
├── quicksand_pit.gd           # F4: Treibsand/Abgrund
├── scenes/                    # Fertige Fallen-Szenen
│   ├── falling_rock.tscn
│   ├── arrow_trap.tscn
│   ├── arrow_projectile.tscn
│   └── quicksand_pit.tscn
└── README.md
```

## 🎮 Implementierte Fallen

### F2 - Fallende Steine (FallingRock)
**Konzept:** Stein hängt an Decke, fällt wenn Spieler in Proximity kommt.

**Features:**
- **Proximity Trigger:** 100px Radius
- **Warning Phase:** 0.5s mit visuellen/Audio-Feedback
- **Damage on Landing:** 35 Schaden in 50px Radius
- **Camera Shake:** Bei Warning + Landing
- **Collision Detection:** RigidBody2D mit contact_monitor

**States:**
```
IDLE → WARNING (0.5s) → FALLING → LANDED
```

**Counter:**
- Weglaufen während Warning Phase
- Leerenschritt aus Damage-Radius

**Test:** Unter Stein laufen → Warning → Weglaufen/Teleportieren

---

### F3 - Pfeilfallen (ArrowTrap + ArrowProjectile)
**Konzept:** Feuert Pfeile in regelmäßigen Abständen, Pfeile können geblockt/parried werden.

**Features:**
- **3 Trigger-Modi:**
  - `PRESSURE_PLATE`: Aktiviert wenn Spieler auf Platte steht
  - `PROXIMITY`: Aktiviert wenn Spieler in Range (300px)
  - `ALWAYS_ACTIVE`: Feuert permanent
- **Fire Rate:** 1.0s Standard (konfigurierbar)
- **Arrow Speed:** 400px/s
- **Arrow Damage:** 15 Standard
- **Parry-Mechanik:** Block/Parry kehrt Pfeil um (1.5x Damage für Enemies)

**ArrowProjectile:**
```gdscript
# Normale Hit
player.HealthComponent.take_damage(15)

# Parry (Player blocking)
direction *= -1
damage = int(damage * 1.5)
collision_mask → Enemies
```

**Counter:**
- Timing: Zwischen Pfeilen durchlaufen
- Parry: Blocken → Pfeil kehrt um
- Dodge Roll: I-frames während Roll

**Test:**
- ArrowTrap2 (300, 600): Pressure Plate aktiviert
- ArrowTrap1 (1700, 800): Proximity, schießt nach links

---

### F4 - Treibsand/Abgrund (QuicksandPit)
**Konzept:** Zieht Spieler zum Zentrum, dealt Damage over Time.

**Features:**
- **Pull Strength:** 50px/s zum Zentrum
- **Damage:** 10/s (jeden Tick)
- **Instant Death:** Nach 5 Sekunden im Pit
- **Radius:** 80px Standard
- **Pit Types:** QUICKSAND, ABYSS, LAVA (visuell unterscheidbar)

**Mechanik:**
```gdscript
# Jeden Frame (_physics_process):
player.velocity += direction_to_center * pull_strength * delta

# Jede Sekunde (Timer):
player.HealthComponent.take_damage(10)

# Nach 5 Sekunden:
player.die()  # Instant death
```

**Counter:**
- Dash/Dodge: Hohe Velocity überschreibt Pull
- Leerenschritt: Teleport aus Pit
- Schnell durchlaufen: Bevor zu viel Damage

**Test:** QuicksandPit1 (1000, 900) - Bodenplattform

---

## 🔧 Godot 4.4 Spezifisch

### RigidBody2D (FallingRock):
```gdscript
contact_monitor = true  # MUSS explizit gesetzt werden
max_contacts_reported = 4
freeze = true  # Initial frozen
body_entered.connect(_on_body_collision)
```

### Area2D (alle Fallen):
```gdscript
monitoring = true  # Explizit setzen
monitorable = true/false
body_entered.connect(_on_body_entered)
```

### Timer:
```gdscript
var timer := Timer.new()
timer.one_shot = true/false  # Explizit definieren
timer.wait_time = 1.0
timer.timeout.connect(_on_timeout)
add_child(timer)
timer.start()
```

---

## 🎨 Collision Layers

### Konfiguration:
- **Layer 1:** World (Wände/Boden)
- **Layer 2:** Player
- **Layer 3:** Enemies
- **Layer 10:** Traps
- **Layer 11:** Projectiles (Pfeile)

### Falling Rock:
```gdscript
collision_layer = 10  # Traps
collision_mask = 1    # World (to detect landing)
```

### Arrow Projectile:
```gdscript
collision_layer = 11  # Projectiles
collision_mask = 1 | 2  # World + Player

# Nach Parry:
collision_mask = 1 | 3  # World + Enemies
```

### Quicksand Pit:
```gdscript
collision_layer = 10  # Traps
collision_mask = 2    # Player
```

---

## 📦 Integration in eigene Level

### 1. Falling Rock platzieren
```
- Position an Decke (Y < 400)
- ProximityDetector zeigt 100px Radius
- Stein fällt automatisch bei Trigger
```

### 2. Arrow Trap konfigurieren
```gdscript
@export var trigger_mode: TriggerMode
# 0 = PRESSURE_PLATE (Platte bei +80px X)
# 1 = PROXIMITY (300px Radius)
# 2 = ALWAYS_ACTIVE

@export var arrow_direction: Vector2 = Vector2.RIGHT
```

### 3. Quicksand Pit platzieren
```
- Radius: 80px Standard
- Platziere auf Boden (nicht schwebend)
- Pit zieht Spieler zum Center
```

---

## 🚀 Counter-Mechaniken

### Leerenschritt (Void Step)
```gdscript
# Player-Script
func void_step():
    global_position += direction * 200.0
    # Ignoriert:
    # - Falling Rock Damage (wenn aus Radius)
    # - Quicksand Pull (teleport out)
    # - Arrow Hit (I-frames während teleport)
```

### Parry/Block System
```gdscript
# ArrowProjectile checks:
if player.has_method("is_blocking") and player.is_blocking():
    _parry(player)  # Reverse direction, 1.5x damage
```

### Dash/Dodge
```gdscript
# Player dash überschreibt Quicksand Pull:
dash_speed (350) > pull_strength (50)
# Dodge Roll gibt I-frames (0.3s)
```

---

## 🧪 TestRoom Integration

**Location:** `levels/test_room.tscn`

**Positionen:**
- **FallingRock1:** (700, 200) - Oben mitte
- **FallingRock2:** (1100, 250) - Oben rechts
- **ArrowTrap1:** (1700, 800) - Rechte Wand, schießt links (Proximity)
- **ArrowTrap2:** (300, 600) - Linke Seite, schießt rechts (Pressure Plate)
- **QuicksandPit1:** (1000, 900) - Boden mitte

---

## 🔊 Audio Hooks (Optional)

Falls AudioManager vorhanden:
- `traps/stone_rumble` - Falling Rock Warning
- `traps/rock_impact` - Falling Rock Landing
- `traps/arrow_fire` - Arrow Trap fires
- `traps/arrow_impact` - Arrow hits wall
- `traps/quicksand_enter` - Player enters pit
- `traps/quicksand_exit` - Player exits pit

Falls nicht vorhanden: System funktioniert ohne Audio.

---

## ⚡ Performance-Tipps

### FallingRock:
- Nutze `destroy_after_landing = true` für temporäre Steine
- `destroy_delay = 5.0` - Stein verschwindet nach 5s

### ArrowTrap:
- Pfeile haben `lifetime = 5.0` - auto-destroy nach 5s
- Nutze `PRESSURE_PLATE` Modus um Fallen zu deaktivieren wenn nicht benötigt

### QuicksandPit:
- Nutze `instant_death_time` für schwierige Fallen
- Pull nur während `_physics_process` wenn Spieler inside

---

## 🐛 Bekannte Limitierungen

1. **FallingRock:** Kein Multiple-Hit (trifft nur einmal beim Landing)
2. **ArrowProjectile:** Parry erfordert `is_blocking()` Methode im Player
3. **QuicksandPit:** Pull-Stärke kann durch hohe Velocities überschrieben werden

---

## 📝 Erweitern

### Neue Falle erstellen:
```gdscript
extends TrapBase  # oder Area2D/Node2D
class_name MyCustomTrap

func _on_body_entered(body: Node2D):
    if body.is_in_group("player"):
        deal_damage(body)
```

### Custom Arrow Types:
```gdscript
extends ArrowProjectile
class_name FireArrow

func _ready():
    super._ready()
    damage = 25
    # Custom fire trail particles
```

---

Erstellt für **Murum-Forbidden-Test** | Godot 4.4
