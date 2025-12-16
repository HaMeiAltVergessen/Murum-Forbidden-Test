# Murum - Forbidden Tales
**Vertical Slice - Godot 4.4**

A 2D action platformer featuring combat, platforming, and environmental puzzles.

## 🎮 Project Setup

### Engine Requirements
- **Godot Version:** 4.4 (stable)
- **Renderer:** Forward+
- **Resolution:** 1920x1080 (16:9)
- **Art Style:** Pixel Art (placeholder colored rectangles)

### How to Run
1. Open the project in Godot 4.4
2. Press **F5** or click "Play" to start
3. The game will load directly into the Test Room

## 🕹️ Controls

### Movement
- **W / Space** - Jump
- **A** - Move Left
- **D** - Move Right
- **Shift** - Dash (costs 20 Mana)

### Combat
- **Left Mouse Button** - Light Attack (3-hit combo)

### Interaction
- **E** - Interact (levers, etc.)

### Debug
- **ESC** - Pause (when implemented)

## 📦 Project Structure

```
res://
├── core/autoloads/          # Global managers (GameManager, EventBus, AudioManager)
├── player/                  # Player character (Murum)
│   ├── murum.tscn          # Main player scene
│   ├── movement_controller.gd
│   ├── combat_system.gd
│   └── health/mana components
├── enemies/                 # Enemy AI and behaviors
│   ├── base_enemy.tscn     # Base enemy template
│   ├── untote.tscn         # Undead enemy
│   └── ai_controller.gd
├── components/              # Reusable components
│   ├── hitbox_component.tscn
│   └── hurtbox_component.tscn
├── environment/             # Interactive objects
│   ├── spike_trap.tscn
│   ├── lever.tscn
│   └── door.tscn
├── levels/                  # Game levels
│   └── test_room.tscn      # Main test level
├── ui/                      # User interface
│   ├── hud.tscn            # Health/Mana display
│   └── death_screen.tscn   # Death/Respawn screen
└── vfx/                     # Visual effects
    └── hit_spark.tscn      # Hit particle effect
```

## ✨ Implemented Features

### ✅ Player System
- [x] WASD Movement (300 px/s)
- [x] Jump with Coyote Time (0.1s) and Jump Buffer (0.15s)
- [x] Dash ability (costs 20 Mana, 1s cooldown)
- [x] 3-Hit Combo system (10/12/15 damage)
- [x] Health: 100 HP (5 hearts)
- [x] Mana: 100 Mana (regenerates 10/s)
- [x] Smooth camera with room bounds
- [x] Camera shake on damage

### ✅ Enemy System
- [x] Untote enemy (40 HP, 100 px/s, 10 damage)
- [x] AI State Machine (IDLE → CHASE → ATTACK)
- [x] Detection radius: 300px
- [x] Attack range: 50px
- [x] Death animation with coin drop

### ✅ Environment
- [x] **Spike Trap**: Cycling hazard (20 damage, 3s retracted → 2s extended)
- [x] **Lever**: One-time activation trigger
- [x] **Door**: Opens when lever is activated
- [x] Platforming sections with collision

### ✅ Combat System
- [x] Hitbox/Hurtbox component architecture
- [x] Damage dealing and reception
- [x] Knockback system
- [x] Invulnerability frames (0.5s)
- [x] Hit particles (orange/yellow sparks)

### ✅ UI System
- [x] HUD with heart-based health display
- [x] Mana bar with numeric display
- [x] Interaction prompts
- [x] Death screen with respawn button

### ✅ Audio System
- [x] SFX pool (16 players)
- [x] Music player with fade in/out
- [x] Volume control system
- [x] Audio integration points (placeholder sounds)

### ✅ VFX & Polish
- [x] Hit spark particles
- [x] Camera shake system
- [x] Damage flash effects
- [x] Smooth animations

## 🎯 Vertical Slice Checklist

| Feature | Status |
|---------|--------|
| Player spawns and moves | ✅ |
| Player attacks (3-hit combo) | ✅ |
| Enemy detects and attacks | ✅ |
| Damage system works | ✅ |
| Spike trap deals damage | ✅ |
| Lever activates door | ✅ |
| HUD shows HP/Mana | ✅ |
| Death screen appears | ✅ |
| Respawn works | ✅ |
| Audio plays (structure) | ✅ |
| 60 FPS target | ✅ |

## 🎨 Placeholder Assets

Since this is a vertical slice, all assets are **placeholder colored rectangles**:

- **Player (Murum)**: Cyan rectangle (32x48px)
- **Enemy (Untote)**: Purple rectangle (32x32px)
- **Spike Trap**: Gray → Yellow → Red (state-based)
- **Lever**: Yellow → Green (when activated)
- **Door**: Brown (64x96px)
- **Hearts**: Red circles
- **Platforms**: Gray rectangles

## 🔧 Technical Details

### Collision Layers
1. **World** (Layer 1) - Static environment
2. **Player** (Layer 2) - Player body
3. **PlayerHitbox** (Layer 3) - Player attack hitbox
4. **PlayerHurtbox** (Layer 4) - Player damage reception
5. **Enemy** (Layer 5) - Enemy body
6. **EnemyHitbox** (Layer 6) - Enemy attack hitbox
7. **EnemyHurtbox** (Layer 7) - Enemy damage reception
8. **Hazard** (Layer 8) - Environmental damage (spikes)

### Physics Settings
- **Gravity**: 980 px/s²
- **Physics Ticks**: 60 TPS
- **Jump Height**: ~400px
- **Dash Distance**: 250px

### Code Style
- Type hints everywhere
- Signal-based communication (EventBus pattern)
- Component-based architecture
- Clear section comments with `# ============`

## 🚀 Next Steps (Beyond Vertical Slice)

- [ ] Replace placeholder art with actual sprites
- [ ] Add attack animations
- [ ] Implement actual audio files (currently placeholder structure)
- [ ] Add more enemy types
- [ ] Create additional levels
- [ ] Implement save/load system
- [ ] Add combat abilities (heavy attack, special moves)
- [ ] Expand UI (menus, inventory)
- [ ] Add gamepad support

## 📝 Notes

- This is a **functional vertical slice** demonstrating core gameplay mechanics
- All systems are fully implemented and interconnected
- Audio Manager is structured but uses placeholder/no sounds
- VFX use simple particle systems
- Focus is on gameplay feel and system architecture

## 🐛 Known Issues

- No actual audio files (AudioManager structure is ready)
- Placeholder graphics (colored rectangles)
- Simple particle effects
- No animation sprites (states work, visuals are placeholder)

## 📄 License

This is a demonstration project for "Murum - Forbidden Tales".

---

**Built with Godot 4.4 | Forward+ Renderer | 2025**
