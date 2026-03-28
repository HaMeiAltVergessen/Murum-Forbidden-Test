# Murum — Foreground Tile Prompts für Nano Banana

## Aufbau

Jede Welt hat 3 Asset-Typen:
- **Master Block** — Solid-Boden, links/mitte/rechts Endkappen, 64×64px Tiles
- **Fallthrough Platform** — Einweg-Plattform, dünn, gleiche Modularität
- **Climbable Updraft** — Luftstrom/Aufwind-Kolonne, breites vertikales Asset

Jeder Master Block / Fallthrough Prompt erzeugt **ein Sheet mit 3 Tiles nebeneinander**:
`[Linke Endkappe] | [Wiederholbare Mitte] | [Rechte Endkappe]`

---

## WELT 1 — Das Niemandsland (Dark Fantasy Ruins)

---

### Master Block — Niemandsland

```
2D Pixel Art Tileset Sheet for a Godot Game: Ancient rough-hewn stone blocks in dark grey-brown, slightly crumbling at the edges, pale green moss growing in the mortar joints and cracks. The top surface has a worn uneven stone texture. The visible side face below shows layered stone depth with darker shadow at the bottom edge. Sheet displays three 64x64 pixel tiles side by side: left end cap tile with a rough natural stone break on the left side | seamlessly tileable center tile with consistent mortar joint lines | right end cap tile mirroring the left break. Transparent background.

Style: Dark fantasy ruins, muted earthy palette of charcoal grey and brown with hints of green moss and faint amber highlight suggesting distant torchlight. Pixel art, clean edges, no anti-aliasing.

No characters.
No UI.
```

---

### Fallthrough Platform — Niemandsland

```
2D Pixel Art Tileset Sheet for a Godot Game: Thin weathered wooden plank platform, dark aged timber with visible wood grain, iron nail heads at intervals, slightly warped and worn smooth by years of use. The top surface shows the plank grain texture. The visible thin side face below shows the plank edge and a hint of shadow beneath. Sheet displays three 64x32 pixel tiles side by side: left end cap tile where the plank terminates with a rough splintered edge | seamlessly tileable center tile with consistent wood grain | right end cap tile mirroring the left. Transparent background.

Style: Dark fantasy ruins, aged wood in dark brown and grey-brown tones with iron nail accents, subtle amber light on the top surface. Pixel art, clean edges, no anti-aliasing.

No characters.
No UI.
```

---

### Climbable Updraft — Niemandsland

```
2D Pixel Art Climbable Updraft Asset for a Godot Game: A vertical column of swirling golden-amber ash and dust particles rising upward, an ancient magical wind current flowing through a ruined stone shaft. Fine ember particles and golden motes rise in spiraling streams, glowing warm amber at the core fading to transparent at the outer edges. The column is approximately 128 pixels wide, clearly defined in the center, fully transparent outside. Designed to tile or loop vertically.

Style: Dark fantasy ruins, warm golden-amber particle column against dark air, soft magical glow from within the stream, ancient and otherworldly but natural-feeling. Pixel art, no anti-aliasing.

No characters.
No UI.
```

---

## WELT 2 — Das Kollektiv (Sci-Fi Cyberpunk)

---

### Master Block — Kollektiv

```
2D Pixel Art Tileset Sheet for a Godot Game: Dark industrial metal platform section, near-black textured metal surface on top with a hexagonal grip grating pattern, small screw heads at regular intervals, a neon cyan light strip running along the bottom edge of the side face. The visible side face shows structural girder depth in dark grey with the glowing cyan trim at the bottom. Sheet displays three 64x64 pixel tiles side by side: left end cap tile with a finished angled metal end plate on the left side | seamlessly tileable center tile with consistent grating and screw pattern | right end cap tile mirroring the left end plate. Transparent background.

Style: Sci-fi cyberpunk, very dark grey and black metal with neon cyan accent lighting, clean industrial precision. Pixel art, clean edges, no anti-aliasing.

No characters.
No UI.
```

---

### Fallthrough Platform — Kollektiv

```
2D Pixel Art Tileset Sheet for a Godot Game: Thin holographic energy platform panel, a semi-translucent cyan-blue glowing panel that appears barely solid, reinforced by a thin metal frame on the top edge with neon accent lines. The top surface is a transparent energy field with visible grid lines. The side face is minimal, showing only the thin metal frame edge with a neon glow. Sheet displays three 64x32 pixel tiles side by side: left end cap tile with a rounded or angled energy field terminator on the left | seamlessly tileable center tile with consistent holographic grid | right end cap tile mirroring the left. Transparent background.

Style: Sci-fi cyberpunk, translucent cyan-blue energy with dark metal frame, cold light emanating from within the panel. Pixel art, clean edges, no anti-aliasing.

No characters.
No UI.
```

---

### Climbable Updraft — Kollektiv

```
2D Pixel Art Climbable Updraft Asset for a Godot Game: A vertical column of upward-flowing electromagnetic energy and blue-cyan light particles, a contained anti-gravity lift beam inside a defined cylindrical field boundary. Bright cyan-white at the energetic core, fine particle streams of electric blue rising upward, faint electromagnetic field lines at the outer edge creating a hard visible boundary. Approximately 128 pixels wide, fully transparent outside the field boundary. Designed to tile or loop vertically.

Style: Sci-fi cyberpunk, cold electric blue and cyan energy column, clean precise field boundary, technological and powerful. Pixel art, no anti-aliasing.

No characters.
No UI.
```

---

## WELT 3 — Der Abgrund (Kosmischer Horror)

---

### Master Block — Abgrund

```
2D Pixel Art Tileset Sheet for a Godot Game: Dark void crystal platform, formed from solidified cosmic matter, near-black crystalline top surface with irregular facets and deep cold white-purple glowing veins running through the cracks. The visible side face shows layered void crystal strata, with eldritch purple-white light glowing from within the crystal depth, darker at the outer surface. Sheet displays three 64x64 pixel tiles side by side: left end cap tile where the crystal terminates in a natural jagged crystalline growth fracture on the left | seamlessly tileable center tile with consistent crystal facet and glowing vein pattern | right end cap tile mirroring the left crystalline fracture. Transparent background.

Style: Cosmic horror, near-black void crystal with cold purple and white eldritch inner glow, alien and impossibly dense material. Pixel art, clean edges, no anti-aliasing.

No characters.
No UI.
```

---

### Fallthrough Platform — Abgrund

```
2D Pixel Art Tileset Sheet for a Godot Game: Thin void shadow matter platform shard, barely substantial, formed from condensed cosmic darkness. The top surface is a thin layer of near-black void crystal with cold white-purple glow at the edges. The side face is extremely thin, almost shadow-like, with a cold purple luminescent edge line. Sheet displays three 64x32 pixel tiles side by side: left end cap tile where the shadow matter ends in a sharp jagged fracture on the left | seamlessly tileable center tile with minimal consistent dark crystal texture | right end cap tile mirroring the left fracture. Transparent background.

Style: Cosmic horror, near-black shadow matter with cold purple-white edge glow, looks barely solid, alien and unsettling. Pixel art, clean edges, no anti-aliasing.

No characters.
No UI.
```

---

### Climbable Updraft — Abgrund

```
2D Pixel Art Climbable Updraft Asset for a Godot Game: A vertical column of upward-flowing void energy, deep purple ethereal particles and cold eldritch light rising in slow spiraling streams, fragments of distorted space visible within the column, cosmic matter dissolving and reforming as it rises. The column has a soft undefined outer boundary where void energy bleeds into the surrounding dark, approximately 128 pixels wide, transparent outside. Designed to tile or loop vertically.

Style: Cosmic horror, deep purple and cold white-blue void energy column, ethereal and slightly wrong, beautiful and frightening. Pixel art, no anti-aliasing.

No characters.
No UI.
```

---

## LIMBUS — Der Limbus Hub

---

### Master Block — Limbus

```
2D Pixel Art Tileset Sheet for a Godot Game: Ancient dark stone tiles, perfectly flat deep charcoal-black stone surface on top with etched geometric rune patterns, golden-purple glowing light emanating from carved rune lines in the mortar joints and surface cracks. The visible side face shows layers of ancient stone with golden-purple glowing rune veins running through the depth, darker at the bottom. Sheet displays three 64x64 pixel tiles side by side: left end cap tile with a carved corner rune relief terminating the surface on the left | seamlessly tileable center tile with consistent rune grid pattern and glowing joints | right end cap tile mirroring the left carved relief. Transparent background.

Style: Cosmic hub, very dark charcoal stone with warm golden and purple magical rune glow, ancient and dimensional, sacred geometry. Pixel art, clean edges, no anti-aliasing.

No characters.
No UI.
```

---

### Fallthrough Platform — Limbus

```
2D Pixel Art Tileset Sheet for a Godot Game: Semi-transparent golden magical energy platform, a softly glowing arcane panel of condensed light, warm gold at the core fading to translucent golden-purple at the edges. The top surface shows a subtle sacred geometry grid pattern within the golden light. The thin side face is a defined golden energy edge line. Sheet displays three 64x32 pixel tiles side by side: left end cap tile where the energy panel terminates in a soft curved golden glow on the left | seamlessly tileable center tile with consistent sacred geometry glow pattern | right end cap tile mirroring the left. Transparent background.

Style: Cosmic hub, warm golden-purple magical translucent energy panel, ethereal but defined, ancient magical light made solid. Pixel art, clean edges, no anti-aliasing.

No characters.
No UI.
```

---

### Climbable Updraft — Limbus

```
2D Pixel Art Climbable Updraft Asset for a Godot Game: A vertical column of upward-flowing golden-purple divine energy, a sacred beam of warm golden light at the core with swirling arcane particles and sacred geometry patterns visible within, fading from bright gold at center to deep purple at the outer edge. Fine golden motes and arcane sparks rise in the stream. Approximately 128 pixels wide, the column has a soft glowing boundary, fully transparent outside. Designed to tile or loop vertically.

Style: Cosmic hub, warm golden-purple divine light column, beautiful and sacred, ancient magical power made into a current of light. Pixel art, no anti-aliasing.

No characters.
No UI.
```

---

## ÜBERSICHT

| Welt | Master Block | Fallthrough | Climbable Updraft |
|------|-------------|-------------|-------------------|
| Niemandsland (W1) | Verwitterter Stein | Morsche Holzplanken | Goldener Aschewind |
| Kollektiv (W2) | Metall-Grating + Neon | Hologramm-Panel | Elektro-Lift-Strahl |
| Abgrund (W3) | Void-Kristall | Schattenmaterien | Void-Energie-Strom |
| Limbus | Runen-Stein | Magisches Energie-Panel | Goldenes Arkan-Licht |

*Gesamt: 12 Prompts — 4 Welten × 3 Asset-Typen*
