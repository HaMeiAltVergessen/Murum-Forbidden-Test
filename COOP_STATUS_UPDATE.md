# 🎯 CO-OP FIX STATUS UPDATE

**Datum:** 2026-01-03
**Branch:** `claude/fix-coop-abilities-svRvV`
**Commit:** `17e337c7`

---

## ✅ BEHOBEN: Enemy Collision Layers

### Problem:
Enemies waren auf **Layer 16** (Layer 5) statt **Layer 8** (Layer 4)!

**Resultat:** P2's Hitboxes (Mask: 8) konnten Enemies nie detektieren!

### Fix:
- **base_enemy.tscn:** Alle Collision Layers korrigiert
- **geist.tscn:** Alle Collision Layers korrigiert

### Details:

| Component | VOR (falsch) | NACH (korrekt) |
|-----------|--------------|----------------|
| Enemy Body Layer | 16 (Layer 5) | 8 (Layer 4) |
| Enemy Body Mask | 3 (nur P1+World) | 7 (P1+P2+World) |
| Enemy Hitbox Layer | 32/4 | 128 (EnemyHitbox) |
| Enemy Hitbox Mask | 8 | 1030 (P1+P2+Hurtbox) |
| Enemy Hurtbox Layer | 64 | 1024 (Hurtbox) |
| Enemy Hurtbox Mask | 4 | 48 (P1Proj+P2Proj) |
| DetectionArea Mask | 1/2 | 6 (P1+P2) |

**Erwartetes Resultat:**
- P2 Void Strike trifft jetzt Enemies ✓
- P2 Shadow Scythe trifft Enemies ✓
- Enemies detektieren P2 ✓

---

## ⚠️ VERBLEIBENDE PROBLEME

### 1. Shadow Scythe unsichtbar

**Symptom:**
```
[Shadow Scythe] Spawned
[Shadow Scythe] Thrown!
```
- Scythe fliegt, ist aber unsichtbar
- Macht keinen Schaden (oder wird nicht detektiert?)

**Mögliche Ursachen:**
- `shadow_scythe.tscn` hat kein Sprite/Texture
- Sprite ist zu klein oder transparent
- Oder: Collision Layer falsch in der .tscn

**Nächster Schritt:** `shadow_scythe.tscn` prüfen

---

### 2. Void Orbs funktionieren nicht

**Symptom:**
- User drückt "RT + B" (laut User)
- Keine Logs, nichts passiert

**Analyse:**
- **RT + B ist NICHT gemappt!**
- Void Orbs sind auf **R3 (button 9)** gemappt
- RT = Button 7 (Right Trigger)

**Input-Mapping:**
```
R3 (button 9) = ultimate (Void Orbs charge)
R3 + B = Phase-Shift
```

**Problem:** User erwartet RT statt R3!

**Fix:** Entweder:
1. User muss R3 verwenden (Right Stick Click)
2. Oder: Input umstellen auf RT

---

### 3. Controller-Mapping durcheinander (P1)

**Symptom:**
- P1 Dodge ist weg
- P1 Dash ist auf B statt LB

**Analyse (project.godot):**
```
dodge={
  events: [SHIFT key, Joypad Button 1 (B), device: -1 (ANY)]
}

p1_dash={
  events: [Joypad Button 1 (B), NUMPAD key, device: 0]
}
```

**Problem:** BEIDE auf Button 1 (B) gemappt!
- `dodge` ist global (device -1)
- `p1_dash` ist für device 0

**Konflikt:** Beide Inputs reagieren auf B-Button!

**Fix erforderlich:**
- Dodge sollte auf eigenen Button (z.B. LB = Button 4)
- Dash sollte separater Button sein

---

## 🎮 SOLL-CONTROLLER-MAPPING

### P1 (Murum) - Keyboard + Maus:
| Aktion | Keyboard | Controller (wenn solo) |
|--------|----------|------------------------|
| Move | WASD | Left Stick |
| Jump | SPACE | A (button 0) |
| Attack | Left Click | X (button 2) |
| Dodge Roll | SHIFT | **B (button 1)** ← FIX |
| Dash | ? | **LB (button 4)?** |
| Block | Right Click | LT (button 6) |
| Staff Throw | Q | Y (button 3) |
| Urgathon | E | RT (button 7) |
| Inventory | TAB | LB (button 4) |

### P2 (Lythrun) - Controller only:
| Aktion | Controller Button |
|--------|-------------------|
| Move | Left Stick |
| Jump | A (button 0) |
| Attack (Void Strike) | **X (button 2)** |
| Shadow Dash | **B (button 1)** |
| Shadow Scythe | **Y (button 3)** |
| Void Parry | **LT (button 6)** |
| Void Rift | **RB (button 5)** |
| Void Orbs (charge) | **RT (button 7)** ← ÄNDERN? |
| Phase-Shift | **R3 (button 9)** |
| Inventory | **LB (button 4)** |

---

## 📝 TO-DO

### PRIORITÄT 1: Testen
1. **Spiel neustarten**
2. **P2 joinen**
3. **Void Strike gegen Enemy testen**
   - Erwartung: Enemy nimmt Schaden
   - Log: `[Void Strike] Hit detected! Body: Untote, Layers: body=8`

### PRIORITÄT 2: Shadow Scythe fixen
1. `shadow_scythe.tscn` prüfen
2. Sprite/Texture hinzufügen
3. Collision Layers prüfen

### PRIORITÄT 3: Input-Mapping korrigieren
1. P1 Dodge auf separaten Button
2. P1 Dash klarstellen
3. P2 Void Orbs: R3 oder RT?

---

## 🔧 SCHNELLTEST

### Test 1: Void Strike
```bash
# Nach Neustart:
1. P2 joinen (START)
2. Neben Enemy stehen
3. X-Button drücken (Void Strike)
4. Console checken:
   - Sollte zeigen: [Void Strike] Hit detected! Body: [EnemyName], Layers: body=8
   - Sollte zeigen: [Void Strike SUCCESS] Dealt X damage to [Enemy]
   - Sollte zeigen: [BaseEnemy] [Enemy] took X damage from Lythrun
```

### Test 2: Shadow Scythe
```bash
1. Y-Button drücken
2. Scythe sollte SICHTBAR sein
3. Sollte Enemy treffen
```

### Test 3: Void Orbs
```bash
1. R3 halten (Right Stick klicken und halten!)
2. Sollte laden
3. Loslassen = Orb fliegt
```

---

**Status:** Collision Layers gefixt, aber weitere Probleme verbleiben.
**Nächster Commit:** Input-Mapping + Shadow Scythe Fixes
