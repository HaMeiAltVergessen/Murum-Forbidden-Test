# Assets Needed for Local Co-op System (COMMIT 018 + 019)

## Player 2 (Lythrun) Assets

### Sprites
- **lythrun_spritesheet.png**
  - Location: `assets/player/lythrun_spritesheet.png`
  - Description: Shadow-themed character sprite with all animations
  - Aesthetic: Dark/violet tones, similar to Murum but with shadowy visual
  - Frames needed:
    - idle (breathing animation with shadow flicker)
    - run (shadow trail effect)
    - jump
    - attack (3-hit combo with dark violet energy)
    - dash (blur into shadows)
    - death (dissolves into shadows)
    - spawn (emerges from abyss - 1.5s)
  - **Currently using**: Murum's sprite with purple modulation (Color(0.7, 0.5, 0.9))

### VFX Assets

#### Shadow Abyss (Spawn Effect)
- **shadow_abyss_animation.png**
  - Location: `assets/vfx/shadow_abyss_animation.png`
  - Description: Animation frames for shadow abyss spawn effect
  - Visual: Dark circular abyss opening, swirling shadows
  - **Currently**: Using simple purple sprite with animation (placeholder)

#### Shadow Particles
- **shadow_particles.png**
  - Location: `assets/vfx/shadow_particles.png`
  - Description: Dark/violet particle texture for shadow trail
  - Visual: Small shadowy wisps, semi-transparent
  - **Currently**: Using default Godot particles

#### Shadow Slash (Attack VFX)
- **shadow_slash_texture.png**
  - Location: `assets/vfx/shadow_slash_texture.png`
  - Description: Dark violet energy streaks for attack VFX
  - Visual: Sharp, angular energy slashes (darker than Murum's)
  - **Currently**: No VFX spawned (placeholder in code)

#### Shadow Death Explosion
- **shadow_explosion_particles.png**
  - Location: `assets/vfx/shadow_explosion_particles.png`
  - Description: Shadow particle burst on death
  - Visual: Black → Violet → Transparent particles radiating out
  - **Currently**: No VFX (just disables shadow trail/aura)

### Audio

#### Lythrun-Specific Sounds
- **lythrun_spawn.ogg**
  - Description: Spawning from shadow abyss
  - Style: Deep, ethereal whoosh with shadow particles
  - **Currently**: Using "player_hurt" sound as placeholder

- **lythrun_attack.ogg** (3 variations for combo)
  - Description: Shadow-infused attack sounds
  - Style: Darker, deeper than Murum's attacks
  - **Currently**: Using default attack sounds (if any)

- **lythrun_dash.ogg**
  - Description: Dash into shadows
  - Style: Quick whoosh with shadow dissipation
  - **Currently**: Using default dash sound (if any)

- **lythrun_death.ogg**
  - Description: Death/dissolution into shadows
  - Style: Fading whisper + shadow dissipation
  - **Currently**: Using "player_hurt" sound as placeholder

- **lythrun_jump.ogg**
  - Description: Shadow-themed jump
  - Style: Lighter than Murum, airy shadow sound
  - **Currently**: Using default jump sound (if any)

## COMMIT 019 Additions

### Stats Scaling System
- **No assets needed** - Pure code implementation
- LythrunStatsScaling calculates 80%-110% scaling based on P1's shop items
- System is fully functional

### Shadow Aesthetic
- **shadow_trail_particles**: Implemented with GPUParticles2D (using default particles)
- **dark_aura**: Implemented with PointLight2D (Color(0.4, 0.2, 0.6))
- **sprite_modulation**: Implemented with Color(0.7, 0.5, 0.9)

## COMMIT 020 Additions - Mirror Inventory System

### Shadow Item Icons

P2 (Lythrun) needs shadow-themed variants of all P1 items. Each shadow item requires its own icon with dark/violet aesthetic.

#### Consumables (World 1 - Ruins)
- **shadow_heilkraeuter.png** → "Schattenessenz"
  - Original: Heilkräuter (healing herbs)
  - Shadow: Dark essence vial with violet glow
  - **Currently**: Placeholder path defined

- **shadow_titanenblut_stein.png** → "Schattenblut-Splitter"
  - Original: Titanenblut-Stein (red glowing stone)
  - Shadow: Cold dark stone with faint violet pulse
  - **Currently**: Placeholder path defined

- **shadow_staub_einkehr.png** → "Asche der Vergessenheit"
  - Original: Staub der Einkehr (golden dust)
  - Shadow: Dark gray ash with violet particles
  - **Currently**: Placeholder path defined

- **shadow_splitter_erdung.png** → "Fragment der Schwere"
  - Original: Splitter der Erdung (grounded fragment)
  - Shadow: Heavy black stone fragment
  - **Currently**: Placeholder path defined

- **shadow_resonanzstaub.png** → "Echo-Partikel"
  - Original: Resonanzstaub (resonance dust)
  - Shadow: Vibrating dark particles
  - **Currently**: Placeholder path defined

#### Relics (Permanent Upgrades)
- **shadow_auge_xy.png** → "Linse der Finsternis"
  - Original: Auge von Xy (holy eye)
  - Shadow: Petrified dark eye with violet iris
  - **Currently**: Placeholder path defined

- **shadow_splitter_xa.png** → "Fragment der Leere"
  - Original: Splitter von Xa (bone splitter)
  - Shadow: Dark bone fragment with void energy
  - **Currently**: Placeholder path defined

- **shadow_urtraene.png** → "Träne des Abgrunds"
  - Original: Urträne (primordial tear)
  - Shadow: Crystallized dark tear with violet core
  - **Currently**: Placeholder path defined

#### Key Item Placeholders
- **shadow_key_empty.png**
  - Visual: Translucent "???" or faded key silhouette
  - Used for all 4 key placeholders
  - Description: P2 sees echoes of keys but cannot use them
  - **Currently**: Placeholder path defined

### Shadow Item Naming Convention

All shadow items follow these themes:
- **Consumables**: Nature/Light → Void/Dark
  - "Heilkräuter" → "Schattenessenz" (healing herbs → shadow essence)
  - "Titanenblut" → "Schattenblut" (titan blood → shadow blood)

- **Relics**: Religious/Holy → Forgotten/Lost
  - "Auge von Xy" → "Linse der Finsternis" (eye of Xy → lens of darkness)
  - "Splitter von Xa" → "Fragment der Leere" (splitter of Xa → fragment of void)

- **Keys**: Always mysterious/unreachable
  - "???" (mystery)
  - "Vergessener Schlüssel" (forgotten key)
  - "Phantom-Fragment" (phantom fragment)

### Shadow Item Database Status

**Created**: `data/items/shadow_items.json`
- 12 example shadow items implemented:
  - 5 consumables (World 1)
  - 3 relics (World 1)
  - 4 key placeholders

**Remaining**: 33+ shadow item variants needed:
- World 2 consumables (5 items)
- World 2 relics (3 items)
- World 3 consumables (5 items)
- World 3 relics (3 items)
- Additional world-specific items

**Mirror System**: Fully functional
- Automatic relic sync (P1 gets relic → P2 gets shadow version silently)
- Separate consumable pools (P2 buys/uses own shadow consumables)
- Key placeholders (P2 sees "???" instead of actual keys)

### P2 Inventory UI (Not Yet Implemented)

**Required** (future work):
- P2 inventory panel (similar to P1 but with shadow theme)
- Dark violet UI color scheme
- Display shadow item names/icons
- Show key placeholders with "???" tooltip
- Separate consumable count display

**Currently**: System is functional but no UI exists yet

### Icon Style Guide

All shadow icons should:
- Use dark/violet color palette (Color(0.7, 0.5, 0.9) tint)
- Have darker backgrounds
- Include subtle shadow particle effects
- Match original item's silhouette but with darker aesthetic

**Quick Prototyping**: Apply Color(0.7, 0.5, 0.9) modulation to original icons

## Implementation Status

### COMMIT 018 - ✅ COMPLETE
- Dual-controller input system
- P2 join/leave mechanics
- Collision layer system
- Respawn system
- Savestate management (P1 only)

### COMMIT 019 - ✅ COMPLETE
- Lythrun fully playable (attack, dash, jump, all combat)
- Adaptive stats scaling (80%-110% based on shop items)
- Shadow aesthetic (violet modulation, trail, aura)
- Full component integration (MovementController, CombatSystem with input_prefix)
- Co-op collision layers for P2

### COMMIT 020 - ✅ CORE COMPLETE
- Mirror inventory system (automatic relic sync)
- Separate P2 consumable pools
- Key placeholders for P2
- 12 example shadow items in shadow_items.json
- Comprehensive documentation (SHADOW_ITEMS_README.md)
- InventoryManager extended with P2 support

**Remaining**:
- Create 33+ additional shadow item variants
- Design actual shadow-themed icons
- Implement P2 inventory UI
- Shop integration for P2 purchases

## Notes
- All assets above are placeholders and need to be replaced with actual art/audio
- Current implementation uses existing Murum assets with color modulation
- Lythrun is **fully playable** with all movement/combat abilities
- Stats scaling is **fully functional** and adaptive
- System works completely with placeholders - ready for testing!
