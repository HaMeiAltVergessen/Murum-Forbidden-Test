# Murum — Trap Sprite Prompts für Nano Banana

Jedes Sheet zeigt **alle Animationszustände nebeneinander**.
Format: `[Zustand A] | [Zustand B] | ...` — Angaben sind Pixelgröße pro Frame.
Schwarzer Hintergrund auf allen Sprites.

---

## WELT 1 — Das Niemandsland (Dark Fantasy Ruins)

---

### Pfeilfalle *(arrow_trap)*
**Größe:** 128×128px pro Frame — Sheet: 384×128px (3 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Arrow Trap — a wall-mounted medieval crossbow mechanism made of dark aged oak wood with iron reinforcement brackets and a tensioning crank. Mounted flush to a stone wall section.
Sheet shows 3 animation states side by side at 128×128px per frame (total 384×128px):
IDLE: mechanism relaxed, bow arms at rest, empty loading track, no arrow, slightly dusty.
LOADED: bow arms bent and tensioned, an iron-tipped wooden arrow locked in the track, iron trigger mechanism visible and under tension.
FIRING: bow arms snapping forward mid-release, arrow leaving the track, wooden arms blurred with motion, a puff of dust from the mechanism.
Black background.

Style: Dark fantasy ruins, aged dark wood and oxidized iron, earthy dark palette. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Pfeil-Projektil *(arrow_projectile)*
**Größe:** 64×32px pro Frame — Sheet: 128×32px (2 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Flying Arrow Projectile — a medieval wooden arrow with a dark iron tip and brown feather fletching at the tail, flying horizontally to the right.
Sheet shows 2 animation frames side by side at 64×32px per frame (total 128×32px):
Frame 1: Arrow in flight, straight, iron tip forward, slight motion blur on shaft.
Frame 2: Arrow in flight, very slightly rotated clockwise (wobble), identical otherwise.
Black background.

Style: Dark fantasy, natural wood brown shaft, dark iron tip, warm feather colours. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Fallender Stein *(falling_rock)*
**Größe:** 128×128px pro Frame — Sheet: 512×128px (4 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Falling Rock Trap — a large rough-hewn granite boulder, dark grey with veins of lighter stone, initially lodged on a ceiling ledge above.
Sheet shows 4 animation states side by side at 128×128px per frame (total 512×128px):
IDLE: boulder resting stable on the ceiling ledge, a fine crack along one edge, completely still, faint dust settled on top.
WARNING: boulder visibly wobbling/shifting, fine dust and pebble particles falling from its edges, a hairline crack glowing faint amber.
FALLING: boulder fully airborne and dropping, strong downward motion lines, loose pebble fragments breaking away around it.
LANDED: shattered into several large grey pieces with a billowing cloud of grey dust around the impact point, cracks radiating outward.
Black background.

Style: Dark fantasy ruins, rough granite dark grey with pale veins, earthy dust particles. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Treibsand *(quicksand_pit)*
**Größe:** 256×128px pro Frame — Sheet: 768×128px (3 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Quicksand Pit Trap — a wide pit of grey-beige cursed quicksand set into the floor, with a slightly sunken center and visible depth below the surface.
Sheet shows 3 animation states side by side at 256×128px per frame (total 768×128px):
IDLE: flat dull sandy surface with subtle slow ripple pattern, a faint dim shimmer, slight depression at center suggesting depth.
ACTIVE: sand surface swirling inward in a slow spiral toward the center, darker churning core visible, particles of sand lifting at the edges.
DANGER: intense churning vortex, the center pit is a dark void visible beneath the spinning sand, particles flying inward from all edges, frantic swirling motion.
Black background.

Style: Dark fantasy ruins, grey-beige sand with dark pit core, muted earthy tones, ominous. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Stachelfalle *(spike_trap)*
**Größe:** 128×128px pro Frame — Sheet: 384×128px (3 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Spike Trap — a cluster of dark iron spikes mounted on a stone floor plate with a mechanical retraction mechanism, flush-mounted into the floor.
Sheet shows 3 animation states side by side at 128×128px per frame (total 384×128px):
OFF: spikes fully retracted, flush with the stone floor plate, only the square seam of the trap base plate visible, a faint metallic sheen, dormant.
WARNING: spike tips just beginning to emerge from the base plate, amber-red glow pulsing from the mechanism slot beneath them, slight scraping vibration cracks in the stone.
ACTIVE: all iron spikes fully extended and rigid, sharp dark iron points at full height, a thin dark red stain on the tips, the mechanical base plate locked in place.
Black background.

Style: Dark fantasy ruins, dark oxidized iron spikes on grey stone base, ominous amber warning glow in middle state. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Pendelklinge *(pendulum_blade)*
**Größe:** 128×256px pro Frame — Sheet: 384×256px (3 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Pendulum Blade Trap — a large curved scimitar-like iron blade suspended by a heavy iron chain from a stone ceiling anchor bracket. The full pendulum from ceiling mount to blade tip is visible.
Sheet shows 3 animation states side by side at 128×256px per frame (total 384×256px):
CENTER/IDLE: blade hanging perfectly vertical, chain taut and straight from ceiling bracket to blade grip, blade face forward, faint rust on the iron, chain links clearly detailed.
SWING LEFT: blade at maximum left arc position, chain angled to the left, the blade tilted in the direction of swing, a subtle motion blur on the blade edge.
SWING RIGHT: blade at maximum right arc position, chain angled to the right, blade tilted accordingly, subtle motion blur on blade edge.
Black background.

Style: Dark fantasy ruins, heavy dark iron blade and chain, aged and rusted, stone ceiling anchor at top of frame. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

## WELT 2 — Das Kollektiv (Sci-Fi Cyberpunk)

---

### Energieturret *(energy_turret)*
**Größe:** 128×128px pro Frame — Sheet: 512×128px (4 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Energy Turret — a sleek sci-fi automated turret with a cylindrical armored body on a floor-mounted base, a rotating head with a barrel and neon cyan sensor eye.
Sheet shows 4 animation states side by side at 128×128px per frame (total 512×128px):
ACTIVE: fully deployed and upright, turret head facing forward with barrel extended, neon cyan sensor eye glowing, body lit with cyan trim lines, fully operational.
RETRACTING: body partially sinking into the floor hatch, head tilting down, cyan glow dimming, the body compressing downward into the base.
RETRACTED: only a small square armored hatch flush with the floor visible, a faint blinking amber warning light on the hatch surface, body completely hidden below.
EMERGING: body rising back up from the open hatch, head tilting upward, cyan glow rebooting and brightening, warning blink on the rising unit.
Black background.

Style: Sci-fi cyberpunk, dark gunmetal grey body with neon cyan accent lighting and trim lines, clean industrial design. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Energie-Bolt Projektil *(energy_bolt)*
**Größe:** 64×32px pro Frame — Sheet: 128×32px (2 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Energy Bolt Projectile — a compact teardrop-shaped energy projectile flying horizontally to the right, bright neon cyan core fading to blue-white at the edges, with a short energy trail behind it.
Sheet shows 2 animation frames side by side at 64×32px per frame (total 128×32px):
Frame 1: bolt at full intensity, bright white-cyan core, pure cyan outer glow, energy trail streaming behind.
Frame 2: bolt with pulse — core slightly expanded and brighter, outer glow slightly larger, same trail, conveying pulsing energy.
Black background.

Style: Sci-fi cyberpunk, neon cyan and white energy, electric and precise. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Elektropanel *(electro_panel)*
**Größe:** 256×64px pro Frame — Sheet: 768×64px (3 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Electro Panel Trap — a wide floor-mounted metal panel with a dark hexagonal grip surface, neon indicator strips along the edges, and a built-in electrification system visible as coil nodes at intervals.
Sheet shows 3 animation states side by side at 256×64px per frame (total 768×64px):
OFF: dark gunmetal panel surface, faint grid lines, coil nodes dark, edge indicator strips unlit, completely dormant.
WARNING: panel surface flickering amber-yellow, coil nodes beginning to glow amber, small random sparks jumping between nodes, edge strips pulsing orange in a warning rhythm.
ACTIVE: panel fully electrified, intense cyan-white electric arcs jumping across the entire surface between all nodes, bright sustained glow, edge strips solid cyan, electric crackling visible.
Black background.

Style: Sci-fi cyberpunk, dark gunmetal panel with neon amber warning and cyan-white active electricity, industrial. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Gravitationsanomalie *(gravity_anomaly)*
**Größe:** 256×256px pro Frame — Sheet: 768×256px (3 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Gravity Anomaly Trap — a spherical zone of intense gravitational distortion hovering above the floor, visible as a dark warped field with particles and debris being pulled toward its center core.
Sheet shows 3 animation states side by side at 256×256px per frame (total 768×256px):
DORMANT: a barely visible shimmer in the air, a faint circular distortion outline, a few floating motes near the center, subtle lens-distortion effect on the field boundary.
ACTIVE: a clearly visible spherical distortion field, concentric rings of gravitational pull, particles and dust streams visibly arcing inward from all directions toward a dark compressed core.
INTENSE: the gravitational field at maximum, a crushing dark vortex core, all particles flying rapidly inward, the field boundary glowing with compressed energy, distorted light bending around the perimeter.
Black background.

Style: Sci-fi cyberpunk, dark gravitational void with cyan-blue distortion rings and glowing compressed core, alien physics made visual. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Laserwand Emitter *(laser_wall — Emitter)*
**Größe:** 96×96px pro Frame — Sheet: 384×96px (4 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Laser Wall Emitter — a compact sci-fi laser emitter unit mounted to a wall or ceiling, with a cylindrical barrel, power coupling ports, and a status indicator light on its housing.
Sheet shows 4 animation states side by side at 96×96px per frame (total 384×96px):
IDLE: emitter dark and powered down, barrel closed with an armored shutter, status light off, no glow.
WARNING: barrel shutter opening, power coils inside the unit glowing amber-red and charging up, status light blinking red rapidly, a low-frequency vibration visible in the casing.
ACTIVE: barrel fully open and firing, a bright intense neon cyan beam extending from the barrel tip, the power coils at full luminescence, status light solid red.
COOLDOWN: barrel still open but beam gone, coils dimming and releasing heat shimmer, a faint residual cyan afterglow at the barrel tip, status light fading.
Black background.

Style: Sci-fi cyberpunk, dark gunmetal emitter housing with neon cyan beam and amber-red warning indicators. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Laserwand Strahl *(laser_wall — Beam, tilebare Segmente)*
**Größe:** 256×48px pro Frame — Sheet: 512×48px (2 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Laser Beam Segment — a tileable horizontal laser beam segment, designed to be repeated end-to-end to create a beam of any length.
Sheet shows 2 animation states side by side at 256×48px per frame (total 512×48px):
WARNING BEAM: a thin dotted red-amber line at the center of the frame, the pre-fire targeting guide, thin and barely visible, dots spaced evenly, faint glow at the center line.
ACTIVE BEAM: a thick intense neon cyan-white laser beam filling the center of the frame, a blinding white core with a bright cyan outer glow, the beam edges sharp and defined, seamlessly tileable on both sides.
Black background.

Style: Sci-fi cyberpunk, neon cyan-white active laser and thin red warning line, clean and precise. Pixel art, seamlessly tileable horizontally, no anti-aliasing.
No characters.
No UI.
```

---

### Kraftfeld *(force_field)*
**Größe:** 64×256px pro Frame — Sheet: 256×256px (4 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Force Field Barrier — a vertical energy shield barrier with emitter nodes at the top and bottom and a continuous energy field between them, blocking passage.
Sheet shows 4 animation states side by side at 64×256px per frame (total 256×256px):
ACTIVE: solid glowing cyan energy wall between two visible emitter nodes, a hexagonal tessellation pattern visible within the field, steady intense glow, the field fully opaque and blocking.
DEACTIVATING: field flickering and breaking apart into horizontal bands, portions of the hexagonal pattern disappearing, field becoming transparent in sections, emitter nodes dimming.
INACTIVE: only the two dark emitter nodes at top and bottom visible, no field between them, nodes are small dark cylinders with a single dim status light, no energy present.
REACTIVATING: field rebuilding from both emitter nodes simultaneously, energy bands growing toward the center from top and bottom, hexagonal pattern reappearing section by section, glow intensifying.
Black background.

Style: Sci-fi cyberpunk, neon cyan energy field with hexagonal grid pattern, dark emitter nodes at ends. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Sicherheitsdrohne *(security_drone)*
**Größe:** 128×128px pro Frame — Sheet: 640×128px (5 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Security Drone — a disc-shaped hovering patrol drone with a central scanning eye, dual rotary thrust units on the sides, a forward-facing weapon port, and a dark armored shell with neon accent lighting.
Sheet shows 5 animation states side by side at 128×128px per frame (total 640×128px):
PATROL: drone hovering level, scanning light sweeping slowly left-right from the central eye, thrusters spinning at cruise speed with a cyan glow, status light green, relaxed posture.
ALERT: drone angled slightly forward in an aggressive lean, scanning eye now a focused red beam aimed forward, thrusters at higher speed with brighter glow, red status light, target locked posture.
ATTACK: weapon port open and flashing, three small energy burst projectiles visible in front of the weapon port mid-fire, drone recoiling slightly from burst, thruster glow at maximum.
STUNNED: drone tilted at a 45-degree angle, sparks flying from the side, one thruster smoking and stopped, the other barely running, eye dark and flickering, crash-landing posture.
DESTROYED: drone lying flat on the ground, cracked shell, both thrusters stopped, sparks jumping from exposed circuits, eye completely dark, debris scattered around it.
Black background.

Style: Sci-fi cyberpunk, dark gunmetal drone shell with neon cyan thruster glow and red alert indicators, precise and threatening. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

## WELT 3 — Der Abgrund (Kosmischer Horror)

---

### Void-Riss *(void_rift_trap)*
**Größe:** 64×256px pro Frame — Sheet: 192×256px (3 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Void Rift Trap — a vertical tear in the fabric of reality, a jagged crack through which the infinite void is visible, hovering in the air with fraying edges of distorted space.
Sheet shows 3 animation states side by side at 64×256px per frame (total 192×256px):
ACTIVE: a stable vertical tear, jagged dark edges with a cold deep purple-black void visible inside, the edges shimmering with fraying distorted light, wisps of void energy at the borders.
TELEPORTING: the tear widening rapidly, a vortex spinning in the interior, a flash of white-purple light at the centre, the edges crackling with discharged eldritch energy.
COOLDOWN: the tear partially sealed and narrower, edges less sharp and more faded, the void interior dimmer, the rift flickering as if struggling to maintain itself.
Black background.

Style: Cosmic horror, deep void purple-black interior with cold white-purple crackling edges, alien and wrong. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Kosmisches Auge *(cosmic_eye)*
**Größe:** 128×128px pro Frame — Sheet: 640×128px (5 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Cosmic Eye Trap — a massive eldritch eye embedded in a wall or ceiling, with heavy dark fleshy eyelids, a golden-purple iris, and a slit pupil that tracks and fires a beam.
Sheet shows 5 animation states side by side at 128×128px per frame (total 640×128px):
CLOSED: heavy dark eyelids shut completely, a slightly raised fleshy mass suggesting the eye within, dark veins visible on the lid surface, dormant and still.
OPENING: eyelids parting to reveal a sliver of golden-purple iris, the inner light beginning to bleed through the gap, eyelid edges trembling.
TRACKING: eye fully open, complete golden iris with a dark narrow slit pupil visible, the pupil rotated slightly in the direction of tracking, iris softly pulsing with gold-purple light.
FIRING: pupil expanded wide, a thin intense beam of purple-gold eldritch energy shooting forward from the pupil, the iris contracted to a ring around the blazing pupil, eyelids forced wide open by the energy.
DESTROYED: eyelids collapsed, the eye deflated and dark, eyelid edges ragged, the iris faded to grey, a dark viscous liquid running from the closed lid, inert.
Black background.

Style: Cosmic horror, organic fleshy eyelids in dark grey-purple, golden-purple iris with eldritch glow, alien biological. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Kosmisches Auge — Strahl *(cosmic_eye — Beam, tilebare Segmente)*
**Größe:** 256×32px — Sheet: 256×32px (1 Frame)

```
2D Pixel Art Sprite Sheet for a Godot Game: Cosmic Eye Beam Segment — a tileable horizontal segment of the Cosmic Eye's DoT beam, designed to be repeated end-to-end to extend from the eye to the target.
Single frame at 256×32px:
A thick organic-feeling energy beam, golden-purple at its core with dark void wisps swirling within the beam body, the outer edge an irregular soft glow that feels alive and breathing, occasional small floating rune-like symbols drifting within the beam, seamlessly tileable on both left and right sides.
Black background.

Style: Cosmic horror, golden-purple eldritch organic beam, alive and breathing, unlike a clean laser. Pixel art, seamlessly tileable horizontally, no anti-aliasing.
No characters.
No UI.
```

---

### Schattenranke *(shadow_tendril)*
**Größe:** 96×256px pro Frame — Sheet: 480×256px (5 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Shadow Tendril Trap — a living dark tendril of void shadow matter that emerges from cracks in walls or the floor, reaching and grabbing at the player.
Sheet shows 5 animation states side by side at 96×256px per frame (total 480×256px):
HIDDEN: barely any sign of presence, only a faint dark crack or shadow seam along the floor or wall base, a slight pulsing void shimmer within the crack.
EMERGING: the tendril tip pushing out of the crack, a coiled dark mass of shadow beginning to unfurl upward, the crack widening, faint cold purple light at the base of the emerging shape.
STRIKING: the tendril fully extended and lunging upward and forward at full reach, a sharp tip at the end, the body of the tendril twisted in a striking pose, motion blur on the tip.
GRABBING: the tendril coiled and constricted in a tight wrap at mid-height, the body forming a holding loop, the tip pressing inward, shadow matter visibly squeezing.
RETREATING: the tendril collapsing back downward and inward toward the crack, the body folding and contracting, losing form as it sinks back into the floor, the crack beginning to close.
Black background.

Style: Cosmic horror, near-black shadow matter with cold purple internal glow at base, organic and fluid, alien and threatening. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

### Zeitverzerrung *(time_distortion)*
**Größe:** 256×256px pro Frame — Sheet: 512×256px (2 Frames)

```
2D Pixel Art Sprite Sheet for a Godot Game: Time Distortion Zone — a standing zone of temporal distortion, visible as a shimmering warped area in space where time flows incorrectly, filled with frozen light fragments and clock-like geometry.
Sheet shows 2 animation states side by side at 256×256px per frame (total 512×256px):
INACTIVE: barely visible, a ghost outline of the zone boundary as a faint shimmering ring, very subtle light refraction within, easily missed, almost transparent.
ACTIVE: a fully visible circular distortion zone, the boundary a clearly defined pulsing ring of warped light, the interior showing distorted refracted imagery like looking through old glass, small shards of crystallized light frozen mid-air within the zone, faint clock-hand geometry faintly etched in the distortion, the whole zone breathing slowly in and out.
Black background.

Style: Cosmic horror, cold blue-grey temporal distortion with crystallized frozen light fragments and faint clock geometry, eerie and wrong. Pixel art, clean edges, no anti-aliasing.
No characters.
No UI.
```

---

## ÜBERSICHT

| Welt | Falle | Frames | Sheet-Größe |
|------|-------|--------|-------------|
| W1 | Pfeilfalle | 3 | 384×128px |
| W1 | Pfeil (Projektil) | 2 | 128×32px |
| W1 | Fallender Stein | 4 | 512×128px |
| W1 | Treibsand | 3 | 768×128px |
| W1 | Stachelfalle | 3 | 384×128px |
| W1 | Pendelklinge | 3 | 384×256px |
| W2 | Energieturret | 4 | 512×128px |
| W2 | Energie-Bolt (Projektil) | 2 | 128×32px |
| W2 | Elektropanel | 3 | 768×64px |
| W2 | Gravitationsanomalie | 3 | 768×256px |
| W2 | Laserwand Emitter | 4 | 384×96px |
| W2 | Laserwand Strahl (tilebar) | 2 | 512×48px |
| W2 | Kraftfeld | 4 | 256×256px |
| W2 | Sicherheitsdrohne | 5 | 640×128px |
| W3 | Void-Riss | 3 | 192×256px |
| W3 | Kosmisches Auge | 5 | 640×128px |
| W3 | Kosmisches Auge Strahl (tilebar) | 1 | 256×32px |
| W3 | Schattenranke | 5 | 480×256px |
| W3 | Zeitverzerrung | 2 | 512×256px |

*Gesamt: 19 Prompts — 6 W1-Fallen + 8 W2-Fallen + 5 W3-Fallen (inkl. Projektile & Strahlen)*
