# Shadow Items System - COMMIT 020

## Overview
Shadow items are mirror variants of P1's items for Player 2 (Lythrun). They have identical gameplay effects but different names, descriptions, and dark/shadow-themed aesthetics.

## How Mirror Sync Works

### Automatic Relic Mirroring
When P1 acquires a relic, P2 automatically receives the shadow version:
```
P1 acquires: "Auge von Xy"
   ↓ (automatic sync)
P2 receives: "Linse der Finsternis" (shadow mirror)
```

### Separate Consumable Pools
Consumables are NOT auto-synced. P2 must buy/find their own:
```
P1 buys: "Heilkräuter" (3x)
P2 inventory: UNCHANGED

P2 buys: "Schattenessenz" (2x)
P1 inventory: UNCHANGED
```

### Key Items (Placeholders)
P2 sees empty placeholder slots instead of keys:
```
P1 has: "Ruinen-Schlüssel"
P2 sees: "???" (placeholder - cannot use)
```

## Adding Shadow Items to Database

### Method 1: Merge shadow_items.json
```bash
# Copy items from shadow_items.json to item_database.json
# Add them to the "items" array
```

### Method 2: Create Items Manually
For each P1 item, create a P2 shadow variant with:

1. **ID Prefix**: `shadow_` + original_id
   ```json
   "id": "shadow_heilkraeuter"
   ```

2. **Mirror Of Field**: Links to original
   ```json
   "mirror_of": "heilkraeuter"
   ```

3. **Shadow-Themed Names**:
   - "Heilkräuter" → "Schattenessenz"
   - "Auge von Xy" → "Linse der Finsternis"
   - "Staub der Einkehr" → "Asche der Vergessenheit"

4. **Darker Descriptions**:
   ```json
   "description": "Dunkle Essenz, die Leben aus Schatten zieht"
   ```

5. **Same Stats** (identical gameplay):
   ```json
   "stats": {
     "heal_percent": 0.4  // Same as original
   }
   ```

## Shadow Item Naming Rules

### Consumables
- Original has nature/light themes → Shadow has void/dark themes
- "Heilkräuter" → "Schattenessenz"
- "Titanenblut-Stein" → "Schattenblut-Splitter"
- "Resonanzstaub" → "Echo-Partikel"

### Relics
- Original has religious/holy themes → Shadow has forgotten/lost themes
- "Auge von Xy" → "Linse der Finsternis"
- "Splitter von Xa" → "Fragment der Leere"
- "Urträne" → "Träne des Abgrunds"

### Keys (Placeholders)
- Always mysterious/unreachable
- "???"
- "Vergessener Schlüssel"
- "Schatten eines Zugangs"
- "Phantom-Fragment"

## Icon Requirements
All shadow items need dark/violet-tinted icons:
```
Original: res://assets/items/icons/heilkraeuter.png
Shadow:   res://assets/items/icons/shadow_heilkraeuter.png
```

Apply Color(0.7, 0.5, 0.9) tint to original icons for quick prototyping.

## Example Shadow Items

### Consumable (Shop Item)
```json
{
  "id": "shadow_heilkraeuter",
  "name": "Schattenessenz",
  "type": "consumable",
  "description": "Dunkle Essenz, die Leben aus Schatten zieht",
  "icon": "res://assets/items/icons/shadow_heilkraeuter.png",
  "price": 50,
  "effect": "Stelle 40% HP wieder her",
  "mirror_of": "heilkraeuter",
  "stats": {
    "heal_percent": 0.4
  }
}
```

### Relic
```json
{
  "id": "shadow_auge_xy",
  "name": "Linse der Finsternis",
  "type": "relic",
  "description": "Versteinertes Auge aus dem Schatten eines Heiligen",
  "lore": "Auge eines vergessenen Beschützers.",
  "icon": "res://assets/items/icons/shadow_auge_xy.png",
  "mirror_of": "auge_xy",
  "stats": {
    "parry_window_bonus": 0.1,
    "parry_slow_duration": 0.5,
    "parry_slow_strength": 0.3
  }
}
```

### Key Placeholder
```json
{
  "id": "shadow_key_placeholder_1",
  "name": "???",
  "type": "key_item",
  "description": "Ein Echo von etwas Realem. Unerreichbar für Schatten.",
  "lore": "Die Form ist da, aber nicht die Substanz.",
  "icon": "res://assets/items/icons/shadow_key_empty.png",
  "stats": {}
}
```

## Implementation Status

✅ **COMMIT 020 - COMPLETE (Core System)**
- Mirror sync logic (relics auto-sync P1→P2)
- Separate consumable pools
- Key placeholders
- Example shadow items (12 total)
- InventoryManager P2 support

⏳ **TODO (Full Content)**
- Create all 45+ shadow item variants
- Design shadow-themed icons
- Create P2 inventory UI
- Shop integration for P2
- Testing with full item set

## Testing

### Test Relic Sync
```gdscript
# P1 acquires relic
InventoryManager.add_item("auge_xy", "relics")

# Check P2's mirror
var p2_inv = InventoryManager.get_p2_inventory()
assert("shadow_auge_xy" in p2_inv.relics)  # Should pass
```

### Test Separate Consumables
```gdscript
# P2 buys shadow consumable
InventoryManager.add_p2_consumable("shadow_heilkraeuter")

# P1's inventory unchanged
assert(InventoryManager.get_consumable_count("heilkraeuter") == 0)
```

### Test Key Placeholders
```gdscript
# P2 sees 4 placeholders
var placeholders = InventoryManager.get_p2_key_placeholders()
assert(placeholders.size() == 4)
assert("shadow_key_placeholder_1" in placeholders)
```

## Notes
- Shadow items are purely cosmetic variants with identical stats
- P2 cannot obtain keys (lore: shadows can't open doors)
- All shadow items use dark/violet color palette
- Mirror sync happens silently (no notifications)
