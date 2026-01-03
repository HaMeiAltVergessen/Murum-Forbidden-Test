# 🎯 COLLISION LAYERS FIX - P2 trifft sich selbst

**Datum:** 2026-01-03
**Problem:** Lythrun (P2) trifft sich selbst statt Enemies
**Ursache:** Scene-Datei hatte falsche Collision Layers hardcoded

---

## 🔍 PROBLEM

### Symptom (aus Logs):
```
[Void Strike] Hit detected! Body: Lythrun, Groups: [&"player", &"player2"], Layers: body=2, hitbox=32
[Void Strike SUCCESS] Dealt 7.2 damage to Lythrun (direct method)
[Lythrun] HP: 73/80  # P2 verliert HP!
```

### Root Cause:
- **Lythrun war auf Layer 2** (P1's Layer!) statt Layer 3 (P2's Layer)
- **Hitbox Mask hatte Layer 2** → traf P2 selbst
- **Scene-Datei (.tscn) hatte hardcoded Werte**, die nicht überschrieben wurden

---

## ✅ FIX

### 1. **lythrun_player.tscn - Hauptplayer**

**VORHER:**
```
collision_layer = 2   # ❌ P1's Layer!
collision_mask = 17   # 1 (World) + 16 (P1 Projectiles)
```

**NACHHER:**
```
collision_layer = 4   # ✓ Layer 3 (P2)
collision_mask = 217  # World(1) + Enemies(8) + P1Proj(16) + Pickups(64) + Hazards(128)
```

### 2. **lythrun_player.tscn - HurtboxComponent**

**VORHER:**
```
collision_layer = 2   # ❌ P1's Layer
collision_mask = 6
```

**NACHHER:**
```
collision_layer = 1024  # ✓ Layer 11 (PlayerHurtbox)
collision_mask = 40     # Enemies(8) + P2Proj(32)
```

### 3. **lythrun_player.tscn - CombatSystem/HitboxComponent**

**VORHER:**
```
collision_layer = 3   # ❌ Falsch
collision_mask = 71   # ❌ Zu viel
```

**NACHHER:**
```
collision_layer = 32  # ✓ Layer 6 (P2 Projectiles)
collision_mask = 8    # ✓ Enemies only (co-op mode)
```

### 4. **lythrun_player.gd - Inline Hitboxes**

**Geändert:**
- Void Strike Hitbox: Entfernt `set_collision_mask_value(2, true)` (P1)
- `set_coop_collision()`: Hitbox Layer korrigiert von 9 → 6

---

## 📊 COLLISION LAYER SCHEMA

### Layer-to-Value Mapping (Godot 4.x Bitmasken):

| Layer | Bit | Value (2^n) | Verwendung |
|-------|-----|-------------|------------|
| 1 | 0 | 1 | World (Wände, Boden) |
| 2 | 1 | 2 | Player 1 (Murum) |
| 3 | 2 | 4 | Player 2 (Lythrun) ✓ |
| 4 | 3 | 8 | Enemies |
| 5 | 4 | 16 | P1 Projectiles |
| 6 | 5 | 32 | P2 Projectiles |
| 7 | 6 | 64 | Pickups |
| 8 | 7 | 128 | Hazards |
| 10 | 9 | 512 | (unused) |
| 11 | 10 | 1024 | PlayerHurtbox |

### P2 (Lythrun) Konfiguration:

**Main Body:**
- Layer: 4 (Player 2)
- Mask: 217 = 1+8+16+64+128
  - Collides WITH: World, Enemies, P1 Projectiles, Pickups, Hazards
  - Does NOT collide: P1 (Layer 2), P2 Projectiles (Layer 6)

**Hurtbox:**
- Layer: 1024 (PlayerHurtbox)
- Mask: 40 = 8+32
  - Can be hit BY: Enemies (Layer 4), P2 Projectiles (Layer 6, for self-hit detection)

**Hitbox (CombatSystem):**
- Layer: 32 (P2 Projectiles)
- Mask: 8 (Enemies only)
  - Can hit: Enemies (Layer 4)
  - Cannot hit: P1 (Layer 2) in co-op mode
  - PvP Mode: CoopManager.set_pvp_collision() adds Layer 2 to mask

**Inline Hitboxes (Void Strike, etc.):**
- Layer: 32 (P2 Projectiles)
- Mask: 8 (Enemies only)
  - Same as CombatSystem Hitbox

---

## 🧪 ERWARTETE ERGEBNISSE

### Nach Fix sollte passieren:

**1. P2 greift Enemy an:**
```
[Void Strike] Hitbox created - Layer: 32, Mask: 8
[Void Strike] Hit detected! Body: Untote1, Groups: [enemies], Layers: body=8, hitbox=32
[Void Strike SUCCESS] Dealt X damage to Untote1 (direct method)
[BaseEnemy] Untote1 took X damage from Lythrun
```

**2. P2 greift P1 NICHT an (co-op mode):**
```
# Kein Hit auf P1, weil Mask = 8 (nur Enemies)
```

**3. Enemy greift P2 an:**
```
# Enemy Projectile Layer 8 (oder Hitbox) trifft P2 Hurtbox (Mask 40 includes Layer 8)
[Lythrun] HP: X/80
```

---

## 🔄 PVP MODE

Im PvP Mode setzt `CoopManager.set_pvp_collision()`:

**P2's Hitboxes können dann P1 treffen:**
```gdscript
# CoopManager.set_pvp_collision() adds:
hitbox.set_collision_mask_value(2, true)   # Can hit Player1
hitbox.set_collision_mask_value(10, true)  # Can hit PlayerHurtbox
```

---

## 📝 WICHTIGE NOTIZEN

1. **Scene-Datei hat Priorität:** `.tscn` Werte werden beim Instantiieren geladen, BEVOR `_ready()` läuft
   - Lösung: Scene-Datei korrigieren, nicht nur Code

2. **1-indexed vs 0-indexed:**
   - `set_collision_layer_value(N, bool)` ist 1-indexed
   - Layer 3 = `set_collision_layer_value(3, true)` = Bit 2 = Value 4

3. **Mask ist Bitmask:**
   - `collision_mask = 217` = multiple layers gleichzeitig
   - Berechnung: Sum of all layer values you want to collide with

4. **CoopManager überschreibt nur Masks:**
   - `CoopManager.set_coop_collision()` ändert nur `collision_mask`
   - Layers bleiben wie in Scene oder `_ready()` gesetzt

---

**Status:** ✅ Behoben
**Nächster Test:** P2 soll Enemies treffen, nicht sich selbst
