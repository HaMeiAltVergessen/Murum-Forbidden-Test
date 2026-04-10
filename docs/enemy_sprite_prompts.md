# Murum — Enemy Sprite Prompts für Nano Banana

Jedes Sheet zeigt **alle Animationszustände nebeneinander**.
Format: `[Zustand A] | [Zustand B] | ...` — Angaben sind Pixelgröße pro Frame.
Schwarzer Hintergrund auf allen Sprites.

## Übersicht

| # | Gegner | Welt | Typ | Frames | Framegröße | Sheetgröße |
|---|--------|------|-----|--------|------------|------------|
| 1 | Sentinel Drone | W2 | Regular | 5 | 128×128 | 640×128 |
| 2 | Sentinel Drone Bolt | W2 | Projektil | 2 | 48×32 | 96×32 |
| 3 | Enforcer | W2 | Regular | 5 | 192×192 | 960×192 |
| 4 | Mender | W2 | Regular | 4 | 96×96 | 384×96 |
| 5 | Disruptor | W2 | Regular | 5 | 128×128 | 640×128 |
| 6 | Vanguard | W2 | Elite | 6 | 256×256 | 1536×256 |
| 7 | Hivemind Nexus | W2 | Elite | 6 | 256×256 | 1536×256 |
| 7b | Synaptik-Kommandant | W2 | Pre-Boss Elite | 8 | 256×256 | 2048×256 |
| 8 | Phase Wraith | W3 | Regular | 5 | 128×192 | 640×192 |
| 9 | Hollow Vessel | W3 | Regular | 5 | 128×128 | 640×128 |
| 10 | Abyssal Anchor | W3 | Regular | 5 | 128×128 | 640×128 |
| 11 | Breach Hulk | W3 | Regular | 5 | 192×192 | 960×192 |
| 12 | Echo Siren | W3 | Regular | 5 | 128×192 | 640×192 |
| 13 | Echo Bolt | W3 | Projektil | 2 | 48×48 | 96×48 |
| 14 | Hollow Mender | W3 | Regular | 4 | 96×96 | 384×96 |
| 15 | The Tethered — Warden | W3 | Elite | 5 | 192×256 | 960×256 |
| 16 | The Tethered — Beast | W3 | Elite | 5 | 192×128 | 960×128 |
| 17 | The Witness | W3 | Elite | 6 | 256×256 | 1536×256 |
| 18 | Eye Bolt | W3 | Projektil | 2 | 48×48 | 96×48 |
| **Gesamt** | | | | **80 Frames** | | **18 Sheets** |

---

## WELT 2 — DAS KOLLEKTIV (Sci-Fi/Cyberpunk)

*Neon-Tech-Ästhetik: Dunkles Metall, cyan/orange/lila LED-Akzente, modulare Bauweise, Hive-Mind-Thematik. Farbpalette: Cyan-Elektrik, Neon-Orange, Metallic-Lila, Rot (Gefahr), Grün (Fabrikation).*

---

### 1. Sentinel Drone *(sentinel_drone)*
**Sheet: 640×128px (5 × 128×128px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Sentinel Drone — a small angular hovering combat drone, roughly 0.7x the height of a human. Compact diamond-shaped metallic body in dark gunmetal grey, with glowing cyan LED edge-lines running along the angular panels. A single bright red targeting eye on the front face. Two thin swept-back wing-fins. Cyan thruster glow underneath. Facing right in side-view.
Sheet shows 5 animation states side by side at 128×128px per frame (total 640×128px):
PATROL: drone hovering neutrally, thrusters glowing soft cyan, red eye dim, wings level, relaxed flight posture.
ALERT: red eye glowing intensely bright, a thin red targeting laser line projecting forward from the eye, body tilted slightly forward, thrusters brightening.
STRAFE: body tilted diagonally as if sliding sideways, thrusters angled, motion blur on the wing-fins, eye locked forward, fast evasive movement posture.
FIRING: body recoiling slightly backward from a bright cyan energy bolt being released from below the eye, muzzle flash of cyan-white light, thrusters flaring bright.
STUNNED: drone sparking wildly, spinning slowly with erratic rotation, cyan LEDs flickering, red eye dark/off, small electric arcs across the body, thrusters sputtering.
Black background.

Style: Sci-fi cyberpunk, dark gunmetal with glowing cyan neon edges, angular military drone design. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 2. Sentinel Drone Energy Bolt *(sentinel_bolt)*
**Sheet: 96×32px (2 × 48×32px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Energy Bolt Projectile — a small bright cyan energy bolt fired horizontally to the right. Compact elongated shape with a bright white-cyan core and softer cyan glow trail behind it.
Sheet shows 2 animation frames side by side at 48×32px per frame (total 96×32px):
Frame 1: bolt in flight, bright white core at the tip, cyan energy glow surrounding it, short trailing energy wisps.
Frame 2: bolt in flight, core pulses slightly larger, trail wisps shifted position for animation cycle.
Black background.

Style: Sci-fi energy projectile, bright cyan with white-hot core, clean neon glow. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 3. Enforcer *(enforcer)*
**Sheet: 960×192px (5 × 192×192px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Enforcer — a bulky humanoid combat robot, roughly 1.2x human height. Wide stocky frame with heavy dark metallic purple chest plate and leg armor, neon-orange energy conduits visible through seams and joints. Right arm ends in a large hydraulic piston fist (a mechanical battering ram). Left arm is a standard heavy claw hand. Head is a small rounded sensor dome with a horizontal orange visor strip. Heavy stomping legs with thick hydraulic joints. Facing right in side-view.
Sheet shows 5 animation states side by side at 192×192px per frame (total 960×192px):
DORMANT: standing completely still in a powered-down pose, arms at sides, visor dark/off, all orange conduits dim, slight dust on the shoulders, inactive.
CHASE: mid-stride walking forward aggressively, visor glowing orange, all conduits lit, piston fist pulled slightly back and ready, heavy deliberate posture.
ATTACK_WINDUP: planted stance, piston fist pulled far back behind the body, orange energy building visibly in the hydraulic arm, visor flaring bright, body compressed like a coiled spring.
ATTACK_STRIKE: piston fist fully extended forward in a powerful punch, arm stretched with visible hydraulic extension, orange energy burst at the fist impact point, slight forward lean, motion blur on the fist.
ARMOR_BROKEN: same chassis but the chest plate has visible cracks and a section blown off on the back, sparks flying from exposed wiring on the rear, orange conduits on the back are dark/flickering, front armor still intact but the back is clearly damaged and vulnerable.
Black background.

Style: Sci-fi cyberpunk, heavy industrial robot, dark metallic purple armor with glowing neon-orange energy conduits, bulky and imposing. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 4. Mender *(mender)*
**Sheet: 384×96px (4 × 96×96px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Mender — a small floating spherical repair drone, roughly 0.6x human height. Translucent green-tinted shell revealing inner circuitry and glowing green core. Two green glowing healing rings orbit around the sphere at different angles. A small green cross symbol on the front of the shell. Multiple thin articulated appendage arms folded against the body. Facing right in side-view.
Sheet shows 4 animation states side by side at 96×96px per frame (total 384×96px):
IDLE: hovering gently, healing rings orbiting slowly, arms folded close to body, green core glowing softly, peaceful neutral posture.
HEALING: arms extended outward, a bright green beam projecting from the front toward the right, healing rings spinning faster and glowing brighter, green core intensely bright, active working posture.
FLEE: body tilted backward as if dashing away to the left, thruster glow visible behind, healing rings trailing, arms retracted tight, panicked fast movement.
SHIELDING: arms spread wide, a hexagonal green energy shield pattern projecting outward from the body, green core pulsing, healing rings expanded to maximum orbit radius, protective casting posture.
Black background.

Style: Sci-fi cyberpunk, translucent green-tinted tech sphere, clean medical/support aesthetic, glowing green energy. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 5. Disruptor *(disruptor)*
**Sheet: 640×128px (5 × 128×128px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Disruptor — a ground-based quadruped spider robot, roughly 0.8x human height. Four jointed mechanical legs supporting a central metallic purple dome body. Two tall antenna prongs extend from the top of the dome, crackling with red-orange electricity between them. Concentric red ring markings on the dome surface that pulse outward. Low and wide silhouette. Facing right in side-view.
Sheet shows 5 animation states side by side at 128×128px per frame (total 640×128px):
IDLE: standing on four legs, dome settled low, antennae straight up with no electricity, red rings dim, resting patrol posture.
CHASE: legs in mid-stride scuttling forward, body raised slightly higher, antennae angled forward, red rings faintly pulsing, aggressive approach.
DEPLOY: legs planted wide and braced, dome lowered to the ground, antennae tips arcing with intense red-orange electricity, the red rings on the dome glowing bright and expanding outward as a charging telegraph.
FIELD_ACTIVE: same braced stance, but now a visible circular red energy field emanates from the dome around the robot on the ground plane, antennae crackling continuously, red rings fully bright, the field distorts the air within it.
PULSE: emergency defensive pose — legs pulled in slightly, dome pulsing outward with a bright red-white shockwave ring expanding from center, antennae flaring, a quick burst of energy.
Black background.

Style: Sci-fi cyberpunk, mechanical spider design, dark metallic purple body with red-orange electrical energy, tactical area-denial aesthetic. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 6. Vanguard *(vanguard)* — ELITE
**Sheet: 1536×256px (6 × 256×256px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Vanguard — a large imposing humanoid mech commander, roughly 1.8x human height. Heavy angular dark gunmetal armor plates with glowing neon-orange edge lighting along every panel seam. Right arm holds a massive energy sword with a bright orange plasma blade. Left arm has a large deployable riot shield made of translucent cyan energy projected from a forearm emitter. Head is a narrow horizontal visor slit glowing cyan. Broad shoulders with energy fin projections flowing back like a cape made of faint orange light trails. Commanding military silhouette. Facing right in side-view.
Sheet shows 6 animation states side by side at 256×256px per frame (total 1536×256px):
SHIELD_STANCE: standing tall and defensive, cyan energy shield fully deployed on the left arm covering the front torso, orange sword held at the side ready, visor glowing steady cyan, imposing guardian posture.
SWORD_SLASH: mid-swing with the orange energy sword in a wide horizontal arc, orange plasma trail behind the blade, right arm fully extended, shield lowered/retracted during the swing, aggressive forward lean.
SHIELD_CHARGE: body crouched low with the cyan shield angled forward like a battering ram, legs mid-sprint, orange energy trailing from the shoulder fins, visor bright, charging forward with momentum.
EXPOSED: shield arm sparking and broken — the cyan energy shield is offline/shattered, exposed emitter on the forearm crackles with dying sparks, armor panels cracked, orange conduits flickering irregularly, sword still active, a more aggressive but vulnerable stance.
RALLY_CRY: sword planted into the ground vertically, both arms spread wide, a pulsing orange energy wave radiating outward from the body, visor blazing bright, shoulder fins flaring maximum brightness, commanding summoning posture.
DEFEATED: down on one knee, sword dropped to the ground beside, shield arm hanging limp, visor flickering and dimming section by section, orange edge lights going dark one panel at a time, a slow dignified power-down.
Black background.

Style: Sci-fi cyberpunk commander mech, heavy dark gunmetal armor with neon-orange edges and cyan energy shield, imposing military elite design. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 7. Hivemind Nexus *(hivemind_nexus)* — ELITE
**Sheet: 1536×256px (6 × 256×256px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Hivemind Nexus — a large floating brain-like construct, roughly 1.5x human size. A metallic purple outer shell cracked partially open revealing an exposed neural network core of glowing cyan circuitry inside. Multiple thick cable tendrils hang from the bottom, connecting downward to floor ports. One large central eye with a bright cyan iris and dark pupil. Several smaller sensor eyes arranged in a ring around the main eye. Holographic data streams and floating code symbols orbit around the construct. Facing forward (symmetrical front view). Stationary — does not move.
Sheet shows 6 animation states side by side at 256×256px per frame (total 1536×256px):
INACTIVE: shell fully closed, no glow, eye shut, tendrils limp and disconnected from floor, all lights off, dormant dark mass.
AWAKEN: shell cracking open along seams, cyan light spilling from the cracks, central eye opening halfway, tendrils twitching and reaching toward the floor, holographic data starting to flicker into existence.
SUMMONING: shell fully open, central eye wide and focused, all tendrils plugged into floor ports and glowing bright cyan with flowing energy, holographic symbols swirling fast around the body, a bright glow at one tendril tip where a new unit is materializing.
MIND_PULSE: central eye blazing white-cyan, concentric cyan energy rings expanding outward from the eye, all smaller eyes open and glowing, the shell pulsing, a powerful psychic shockwave visual.
OVERCLOCK: shell cracked wider than before with pieces breaking off, the neural core inside glowing dangerously bright and overheating (shifting from cyan to cyan-white), all eyes wide with dilated pupils, tendrils writhing frantically, holographic data spinning chaotically, visibly unstable and dangerous.
DEATH: shell collapsing inward, eye dimming and closing, tendrils going limp and detaching from floor, holographic data scattering and dissolving, the neural core imploding into a dark point, pieces of the shell being pulled inward.
Black background.

Style: Sci-fi cyberpunk, bio-mechanical brain construct, metallic purple shell with glowing cyan neural circuitry, hovering hive-mind intelligence. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 7b. Synaptik-Kommandant *(synaptik_kommandant)* — PRE-BOSS ELITE
**Sheet: 2048×256px (8 × 256×256px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Synaptik-Kommandant — a tall imposing humanoid Kollektiv commander, roughly 1.9x human height. Metallic purple armor plating with cyan LED pulse-lines running along every seam. Massive oversized dorsal module on the upper back shaped like a synapse cluster, with four articulated projector arms extending upward and outward from the shoulders, each tipped with a glowing cyan emitter lens that broadcasts buff beams. A heavy shoulder-mounted plasma cone cannon on the right shoulder pointing forward, with an intake funnel and visible charging chamber. Head is an elongated oval visor with a single horizontal cyan sensor slit and small orange warning lights. Narrow waist, long powerful legs with hydraulic pistons. Commanding posture with one hand raised to control the projector arms. Facing right in side-view.
Sheet shows 8 animation states side by side at 256×256px per frame (total 2048×256px):
IDLE: standing tall in a steady command pose, projector arms slightly extended and glowing soft cyan, cone cannon dormant, visor glowing steady cyan, orange warning lights calm, LED seams pulsing slowly in rhythm, aura of authority.
REPOSITION: mid-stride sidestep movement, cone cannon held level and ready, projector arms still active and broadcasting soft cyan, legs angled as if circling to maintain distance, visor tracking forward, tactical reposition posture.
CONE_WINDUP: planted stance, right shoulder cannon pulled slightly back with the charging chamber glowing bright orange, energy visibly building in the muzzle funnel, projector arms flared wide and trailing more intense cyan, visor brightening, body braced, clear telegraph of incoming volley.
CONE_FIRE: cone cannon fully extended forward with a bright orange plasma burst erupting from the muzzle in a wide 30-degree fan pattern, five visible plasma bolt trails spreading outward from the barrel, slight recoil throwing the shoulder back, orange muzzle flash and smoke, visor blazing, the middle bolt distinctly brighter than the others.
OVERLOAD_CHARGE: commander standing still with both arms spread wide to the sides, an expanding cyan energy ring on the ground at his feet growing outward as a radial telegraph, the dorsal synapse cluster glowing dangerously bright cyan-white and overcharging, all four projector arms flared to maximum with crackling cyan lightning arcing between the tips, visor burning bright orange-white with warning lights flashing, body rigid and vulnerable, clearly channeling a devastating attack.
OVERLOAD_RELEASE: radial cyan-white shockwave exploding outward from the commander at full force, the ground ring now a bright ring of plasma expanding, the body at the center hunched forward slightly from the kickback, projector arms snapped outward stiffly, dorsal module venting steam, intense shockwave burst filling most of the frame with motion lines and energy fragments.
STUNNED: body staggered backward, visor flickering irregularly, dorsal synapse module sparking and dark, projector arms drooping limp and unlit, cone cannon dangling at the side, LED seams dim and glitching, small electric arcs across the chassis, vulnerable exposed posture.
DEATH: collapsing forward onto one knee, dorsal synapse module cracked open with cyan neural fluid leaking out, projector arms detached and hanging, cone cannon fallen beside the body, visor dark and cracked, LED seams going out one by one, orange warning lights dead, a slow broken power-down of the commander.
Black background.

Style: Sci-fi cyberpunk Kollektiv commander elite, metallic purple armor with cyan LED seams and dorsal synapse module, orange plasma weaponry and warning lights, imposing hive-mind authority figure with broadcasting buff-projector arms. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

## WELT 3 — DER ABGRUND (Kosmischer Horror)

*Void-Horror-Ästhetik: Tief-lila, Dunkel-Magenta, Void-Schwarz, krank-Cyan, Geister-Outlines. Verzerrte Formen, dimensionale Risse, eldritch Augen, greifende Tentakel, gebrochene Zeit.*

---

### 8. Phase Wraith *(phase_wraith)*
**Sheet: 640×192px (5 × 128×192px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Phase Wraith — a tall thin humanoid shadow figure, roughly human-sized but elongated. Dark purple translucent body with ragged fraying edges that dissolve into floating particles. No distinct face — just two sickly cyan glowing eye-dots in a smooth dark head. Limbs taper into smoky wisps rather than hands or feet. Tattered shadow robes cling to the upper body. Hunched posture, slightly bent forward. Facing right in side-view.
Sheet shows 5 animation states side by side at 128×192px per frame (total 640×192px):
PHASED: body mostly transparent/ghostly, a dark purple silhouette with only the faintest outline visible, cyan eye-dots dimmed, dissolving particle trail behind, passing through solid matter, ethereal and barely there.
MATERIALIZING: a dark purple vortex swirling at the feet, the body condensing from particles into a more solid form from the ground up, cyan eye-dots brightening, edges still unstable and flickering between solid and transparent.
CORPOREAL_IDLE: fully materialized and solid, dark purple body clearly visible with sharp edges, cyan eye-dots bright, tattered robes defined, hunched forward in a predatory stance, wisps of dark energy drifting from the edges.
VOID_SLASH: right arm pulled far back trailing dark purple energy, then sweeping forward in a wide slash arc, a visible dark energy crescent following the arm motion, cyan eyes flaring, body lunging forward aggressively.
DEATH: body frozen mid-motion, cracks of bright cyan light splitting through the dark purple form like shattering glass, pieces breaking away and dissolving into floating particles that fade to nothing, eyes flickering out.
Black background.

Style: Cosmic horror, dark purple shadow entity with cyan eye-dots, translucent phasing effects, tattered ethereal robes, unsettling and alien. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 9. Hollow Vessel *(hollow_vessel)*
**Sheet: 640×128px (5 × 128×128px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Hollow Vessel — a corrupted version of a ghostly entity. Dark magenta body instead of spectral white. The form is permanently distorted and WRONG — arms stretched too long, torso unnaturally thin, proportions subtly off. Two extra phantom arms trail behind the main body as ghostly afterimages. Eye sockets are void-black holes with tiny sickly cyan pinprick lights deep inside. The body has a jerky, stuttering quality as if reality glitches around it. Roughly human-sized. Facing right in side-view.
Sheet shows 5 animation states side by side at 128×128px per frame (total 640×128px):
IDLE: floating with jerky micro-movements, distorted long arms hanging, phantom arms trailing behind slightly offset, cyan eye-pinpricks dim, body twitching with visual static/glitch artifacts at the edges.
CHASE: lunging forward aggressively, main body stretched horizontally, phantom arms streaming behind, cyan eyes brighter, movement lines suggesting fast stuttering pursuit, glitch artifacts intensified.
VOID_LASH: body stretched extremely (3x horizontal stretch), all four arms (real + phantom) sweeping forward in a wide slash, dark magenta energy arc trailing the strike, the entire form distorted like a rubber band snapping, eyes blazing cyan.
MIRROR_SPLIT: the body splitting into TWO identical copies side by side, both facing right, connected by a faint dark energy thread, both with matching pose but one has slightly brighter cyan eye-pinpricks (the real one) — subtle tell.
DEATH: body cracking like dark glass, magenta light spilling from fracture lines, phantom arms reaching upward desperately, then the whole form collapsing inward to a single bright magenta point of implosion.
Black background.

Style: Cosmic horror corrupted ghost, dark magenta body with void-black eyes and cyan pinpricks, distorted wrong proportions, glitch/static artifacts, deeply unsettling. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 10. Abyssal Anchor *(abyssal_anchor)*
**Sheet: 640×128px (5 × 128×128px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Abyssal Anchor — a floating dark crystalline mass, roughly human-sized. Jagged irregular obsidian crystal formation with deep purple veins pulsing through the dark surface. At the core center, a small void-black sphere that visually warps the space around it (bending nearby lines). Small rock debris and dust particles orbit the formation slowly. No face, no eyes — it is a cosmic OBJECT, not a creature. Spiky, irregular, asymmetric silhouette. Floating with no visible support.
Sheet shows 5 animation states side by side at 128×128px per frame (total 640×128px):
DORMANT: crystals dark and still, purple veins barely visible, void sphere at center is tiny and dim, no orbiting debris, inert and easy to overlook.
ACTIVATED: purple veins brightening and pulsing visibly, void sphere growing slightly, small debris beginning to orbit, the crystals vibrating subtly, awakening.
DEPLOYING: crystals spreading apart slightly revealing the void core, purple veins blazing bright, void sphere enlarged and actively distorting surrounding space, debris orbiting fast, energy gathering visibly — a charging telegraph.
WELL_ACTIVE: crystals fully spread open like a dark flower, void sphere at center pulling everything inward, visible gravitational distortion lines curving toward the center, purple energy field radiating outward on the ground plane, debris spiraling inward rapidly.
IMPLOSION: everything contracting violently inward — crystals snapping shut, void sphere collapsing to a pinpoint of bright purple-white light, debris smashing together at center, a final bright flash at the point of collapse.
Black background.

Style: Cosmic horror, dark obsidian crystals with deep purple veins, void-black gravity core, reality-warping distortion effects, alien cosmic object. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 11. Breach Hulk *(breach_hulk)*
**Sheet: 960×192px (5 × 192×192px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Breach Hulk — a corrupted version of a heavy combat robot consumed by cosmic horror. The original bulky humanoid robot frame is still recognizable but grotesquely warped. Original neon-orange energy conduits have shifted to sickly cyan, leaking void energy as wisps. Heavy armor plates are cracked and peeling away, revealing dark fleshy organic tendrils growing underneath instead of wiring. The hydraulic piston fist has grown organic bone spikes protruding from the knuckles. The sensor dome head is cracked wide open, and a single large wet eldritch eye peers out from inside the broken dome. 1.3x human size due to organic growths bulging the frame. Facing right in side-view.
Sheet shows 5 animation states side by side at 192×192px per frame (total 960×192px):
IDLE: standing heavy, eldritch eye scanning slowly, organic tendrils writhing subtly under cracked plates, sickly cyan conduits leaking wisps of void energy, a menacing dormant threat.
CHASE: stomping forward, eye locked ahead and glowing bright, tendrils pulsing with each heavy step, small void puddles left behind the feet (dark spots on the ground), cracked armor plates rattling.
CORRUPTED_PUNCH: piston fist with bone spikes pulled far back, eye blazing, tendrils on the arm tensing, cyan void energy building around the fist, then the fist extended forward with a void energy burst at the impact point.
VOID_BURST: immediately after the punch — a sphere of dark void energy erupting from the ground at the impact point, expanding outward as a dark purple-black shockwave ring, the robot slightly recoiling, eye wide.
TENDRIL_GRAB: organic tendrils shooting out from the cracked chest armor, extending far forward like grasping arms with fleshy tips, reaching toward a target, eye focused intently, the robot leaning forward, a desperate grasping attack.
Black background.

Style: Cosmic horror corrupted robot, dark metal frame with organic fleshy tendrils growing through cracked armor, sickly cyan void energy replacing original orange, single eldritch eye in broken head dome, grotesque bio-mechanical fusion. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 12. Echo Siren *(echo_siren)*
**Sheet: 640×192px (5 × 128×192px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Echo Siren — a floating ethereal figure, roughly 0.9x human height. Upper body is a smooth featureless humanoid torso in ghost-white, merged seamlessly into a jellyfish-like lower half with long translucent dark magenta tentacles dangling below. The head is a smooth featureless oval with a single large dark magenta eye at the center. The body shifts between translucent and opaque in a slow breathing rhythm. Small glowing bioluminescent particles drift around it like deep-sea plankton. Facing right in side-view.
Sheet shows 5 animation states side by side at 128×192px per frame (total 640×192px):
DRIFT: hovering neutrally, tentacles trailing gently below and slightly behind, magenta eye half-open and dim, bioluminescent particles scattered lazily, calm drifting posture.
SCREAM_WINDUP: body tensing, the head splitting open at the bottom revealing a dark mouth-like opening below the eye, dark magenta energy gathering visibly into the mouth area, tentacles pulling upward and contracting, eye wide open and bright, a charging telegraph.
SCREAMING: mouth fully open with concentric dark magenta sound/energy waves radiating outward in a cone shape from the mouth, eye blazing, tentacles flared outward rigidly, body vibrating with the force of the scream, particles scattered chaotically.
BOLT_CAST: mouth closed, eye focused and narrowed, a dark magenta energy orb forming at the tip of one extended tentacle, the tentacle pointing forward like a weapon, other tentacles pulled back, a precise ranged attack posture.
DEATH: body going rigid from bottom up, tentacles coiling inward, the eye dimming and closing, the form dissolving from the top downward like smoke dissipating upward, bioluminescent particles scattering outward and fading.
Black background.

Style: Cosmic horror, ghost-white upper body with dark magenta jellyfish tentacles, featureless head with single large eye, bioluminescent deep-sea horror aesthetic, ethereal and alien. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 13. Echo Bolt *(echo_bolt)*
**Sheet: 96×48px (2 × 48×48px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Echo Bolt Projectile — a small dark magenta energy orb flying horizontally to the right. Spherical shape with a dark magenta-purple core, surrounded by a softer magenta glow aura, with small void-dark particle wisps trailing behind it.
Sheet shows 2 animation frames side by side at 48×48px per frame (total 96×48px):
Frame 1: orb in flight, dark magenta core bright, aura pulsing outward, short trailing wisps.
Frame 2: orb in flight, core pulses slightly smaller, aura contracted, wisps shifted for animation cycle.
Black background.

Style: Cosmic horror energy projectile, dark magenta-purple with void particle trail, eldritch glow. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 14. Hollow Mender *(hollow_mender)*
**Sheet: 384×96px (4 × 96×96px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Hollow Mender — a corrupted version of a small floating repair drone. The original translucent green spherical shell is now cracked open and darkened, revealing not circuitry inside but a pulsing fleshy organic mass with dark veins. The original green healing rings are now void-black with sickly cyan edges, orbiting erratically at uneven speeds. The green cross symbol on the front is replaced by an inverted dark magenta sigil. The thin appendage arms now end in sharp needle-like points instead of tools. Same size as the original (~0.6x human). Facing right in side-view.
Sheet shows 4 animation states side by side at 96×96px per frame (total 384×96px):
IDLE: hovering with an unsettling wobble, dark rings orbiting erratically, organic mass inside pulsing slowly, magenta sigil dimly glowing, needle arms folded close, menacing stillness.
CORRUPTION_BEAM: needle arms extended, a dark magenta beam with black particle trail projecting forward from the organic core through the cracked shell, dark rings spinning fast, sigil blazing bright, an inverted healing posture — draining instead of giving.
ANTI_SHIELD: arms spread wide, a dark hexagonal energy pattern projecting outward (same shape as the original Mender's shield but in dark magenta-black instead of green), organic mass pulsing rapidly, a cursed protective inversion.
DEATH: shell cracking fully apart, organic mass inside shrieking (mouth-like opening), dark rings shattering into fragments, needle arms flailing, then the organic core dissolving into dark smoke, leaving broken shell pieces falling.
Black background.

Style: Cosmic horror corrupted support drone, cracked dark shell with organic fleshy interior, void-black rings with cyan edges, inverted magenta sigil, body horror medical aesthetic. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 15. The Tethered — Warden *(tethered_warden)* — ELITE
**Sheet: 960×256px (5 × 192×256px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: The Tethered Warden — a tall skeletal humanoid figure wreathed in deep purple fire, roughly 1.5x human height. Extremely thin and elongated frame, almost skeletal — visible rib-like structures through the torso. Long arms ending in sharp dark claw-like hands. The head is a narrow skull shape with two bright sickly cyan eye-sockets. Deep purple flames flicker and trail from the shoulders, head, and forearms. Tattered dark robes hang from the waist. A thick chain of dark void energy extends from the torso toward the right side of the frame (connecting to the Beast, shown separately). The chain has small embedded eye-like patterns along its length. Facing right in side-view.
Sheet shows 5 animation states side by side at 192×256px per frame (total 960×256px):
IDLE: standing tall with arms at sides, purple flames burning steadily, cyan eyes glowing, void chain extending to the right at rest, a sentinel guardian posture, calm menace.
VOID_WAVE: both arms raised high above the head gathering a mass of deep purple energy between the claws, then arms sweeping down and forward releasing a wide arc-shaped wave of dark purple energy, flames flaring with the motion, eyes blazing.
CHAIN_PULL: body leaning back, both hands gripping the void chain, pulling it taut and contracting it toward itself, the chain glowing brighter with the embedded eyes opening wide, a violent yanking motion.
FRENZY: chain broken and trailing as loose dark energy wisps from the torso, body more hunched and aggressive, purple flames doubled in intensity, claws spread wide, eyes blazing maximum brightness, a berserking rage posture — faster and more dangerous.
DEATH: purple flames extinguishing from bottom up, skeletal frame collapsing at the joints, robes pooling on the ground, eyes dimming, the chain end dissolving into dark particles, a slow dignified collapse.
Black background.

Style: Cosmic horror, tall skeletal figure wreathed in deep purple fire, dark void chain with embedded eyes, eldritch guardian aesthetic, gaunt and terrifying. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 16. The Tethered — Beast *(tethered_beast)* — ELITE
**Sheet: 960×128px (5 × 192×128px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: The Tethered Beast — a crouching feral quadruped shadow-creature, roughly human-sized but low and wide. Dark purple-black body with a fluid shifting surface like living shadow. Multiple small sickly cyan eyes scattered across the head and upper back (6-8 eyes of varying sizes). Short powerful legs ending in clawed feet. Two longer tentacle-like appendages extend from the shoulders. A thick chain of dark void energy extends from the torso toward the left side of the frame (connecting to the Warden, shown separately). The chain has small embedded eye-like patterns along its length. Low, predatory silhouette. Facing right in side-view.
Sheet shows 5 animation states side by side at 192×128px per frame (total 960×128px):
STALK: low to the ground, body compressed and coiled, all eyes focused forward, tentacle appendages tucked against the body, legs bent and ready to spring, the shadow surface rippling, hunting posture.
POUNCE: body fully extended mid-leap, all four legs stretched, tentacle appendages trailing behind like streamers, eyes wide and blazing, launching at high speed toward the right, powerful aerial attack.
CLAW: landed and swiping with the right forepaw in a fast arc, claws extended and slashing, shadow particles spraying from the impact direction, tentacles whipping forward simultaneously, vicious melee posture.
FRENZY: chain broken and trailing from torso, body raised higher and more erect than normal, ALL eyes blazing maximum cyan, tentacles flailing wildly, shadow surface churning chaotically, mouth (previously hidden) open revealing rows of cyan-lit teeth, completely berserk.
DEATH: body flattening against the ground, eyes closing one by one across the body, shadow surface solidifying and cracking, tentacles going limp, the chain end dissolving, fading into a dark stain on the ground.
Black background.

Style: Cosmic horror, feral quadruped shadow-beast with multiple cyan eyes, dark purple-black living shadow body, void chain with embedded eyes, predatory alien creature. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 17. The Witness *(the_witness)* — ELITE
**Sheet: 1536×256px (6 × 256×256px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: The Witness — a massive floating eldritch eye, roughly 2x human size. The main eye has a void-black iris with a sickly cyan pupil at the center that visibly tracks and follows. Surrounding the main eye is a halo ring of smaller independent eyes (8-10 of them) that open and close at different times. Below the main eye, long dark shadow tendrils hang downward like a beard or tentacle mass. The entire entity has a breathing opacity effect — slightly pulsing between more and less visible. The surface of the main eye has faint vein-like patterns. Deeply unsettling cosmic horror entity. Facing forward (symmetrical front view).
Sheet shows 6 animation states side by side at 256×256px per frame (total 1536×256px):
CLOSED: a dark amorphous mass with no visible eye, all smaller eyes shut, tendrils hanging limp, barely distinguishable from void — dormant, just a dark shape.
OPENING: the main eye splitting open slowly from a horizontal slit, sickly cyan light spilling from the widening gap, smaller eyes beginning to open around the perimeter, tendrils twitching awake, a deeply unsettling awakening.
GAZING: fully open, main eye wide with cyan pupil focused to the right, smaller eyes open and independently scanning different directions, tendrils gently drifting, a steady menacing observation pose, vein patterns visible on the eyeball surface.
EYE_BOLT: several of the smaller halo eyes glowing bright and projecting small dark magenta energy bolts outward in different directions, main eye still gazing, tendrils contracted, a multi-directional ranged attack from the smaller eyes.
TENDRIL_SWEEP: the lower tendrils sweeping in a wide arc from left to right, extended to full length and rigid like whips, main eye looking down toward the sweep, smaller eyes focused on the sweep area, a grasping area attack.
BLINK: ALL eyes simultaneously closed — main eye shut as a horizontal line, all smaller eyes closed, the entire form dimmed and darkened, tendrils hanging limp, a moment of blindness and vulnerability, visibly weakened and exposed.
Black background.

Style: Cosmic horror, massive eldritch floating eye with smaller eye halo and shadow tendrils, void-black iris with sickly cyan pupil, deeply unsettling omniscient horror entity. Pixel art, clean edges, no anti-aliasing.
No UI.
```

---

### 18. Eye Bolt *(eye_bolt)*
**Sheet: 96×48px (2 × 48×48px)**

```
2D Pixel Art Sprite Sheet for a Godot Game: Eye Bolt Projectile — a small dark magenta-purple energy projectile shaped like a miniature eye. An oval shape with a dark center (pupil) surrounded by a magenta-glowing iris ring, trailing dark void wisps behind it as it flies horizontally to the right.
Sheet shows 2 animation frames side by side at 48×48px per frame (total 96×48px):
Frame 1: eye-bolt in flight, iris ring glowing bright magenta, dark pupil at center, short dark wisps trailing behind.
Frame 2: eye-bolt in flight, iris ring pulsing slightly dimmer, pupil dilated slightly larger, wisps shifted position for animation cycle.
Black background.

Style: Cosmic horror projectile, miniature eye shape, dark magenta iris glow with void-dark pupil, eldritch and creepy. Pixel art, clean edges, no anti-aliasing.
No UI.
```
