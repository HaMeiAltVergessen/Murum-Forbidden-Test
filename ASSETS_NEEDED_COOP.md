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

## Notes
- All assets above are placeholders and need to be replaced with actual art/audio
- Current implementation uses existing Murum assets with color modulation
- Lythrun is **fully playable** with all movement/combat abilities
- Stats scaling is **fully functional** and adaptive
- System works completely with placeholders - ready for testing!
