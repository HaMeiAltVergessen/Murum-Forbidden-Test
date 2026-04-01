"""
Extract frames from trap placeholder PNGs and create spritesheets.
Uses only PIL/Pillow — no numpy required.
"""

from PIL import Image
import os

# Paths
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(BASE, "Assets", "AIPlaceholder", "Fallen_PNGs")
OUT_DIR = os.path.join(BASE, "Assets", "AIPlaceholder", "Fallen_Spritesheets")

os.makedirs(OUT_DIR, exist_ok=True)

# ============================================================================
# TRAP CONFIGS: (source, output, cols, rows, bg_mode)
# bg_mode: "gray" | "black" | "purple" | "none"
# ============================================================================

TRAP_CONFIGS = [
    # W1
    ("Arrow trap.png",       "arrow_trap_sheet.png",       2, 3, "gray"),
    ("arrowprojectile.png",  "arrow_projectile.png",       1, 1, "gray"),
    ("fallingRock.png",      "falling_rock_sheet.png",     4, 1, "gray"),
    ("Treibsand.png",        "quicksand_sheet.png",        3, 1, "gray"),
    ("pendelklinge.png",     "pendulum_blade_sheet.png",   3, 1, "black"),
    ("Spikes.png",           "spike_trap_sheet.png",       3, 1, "gray"),
    # W2
    ("Elektropanel.png",     "electro_panel_sheet.png",    1, 3, "gray"),
    ("Gravitationsfalle.png","gravity_anomaly_sheet.png",  3, 1, "gray"),
    ("Wachtturm.png",        "energy_turret_sheet.png",    4, 1, "gray"),
    ("turretlaser.png",      "energy_bolt_sheet.png",      2, 1, "gray"),
    ("laserwandstrahl.png",  "laser_beam.png",             1, 1, "gray"),
    ("kraftfeld.png",        "force_field_sheet.png",      4, 1, "gray"),
    ("Sicherheitsdrone.png", "security_drone_sheet.png",   5, 1, "black"),
    # W3
    ("VoidRiss.png",         "void_rift_sheet.png",        3, 1, "purple"),
    ("cosmicEYE.png",        "cosmic_eye_sheet.png",       5, 1, "gray"),
    ("eyelaser.png",         "eye_laser_sheet.png",        2, 1, "gray"),
    ("Schattenranke.png",    "shadow_tendril_sheet.png",   4, 1, "gray"),
    ("Zeitverzerren.png",    "time_distortion_sheet.png",  2, 1, "gray"),
    ("Phaseplattform.png",   "phase_platform.png",         1, 1, "gray"),
]


def remove_background(img, mode="gray"):
    """Remove background pixels by setting alpha to 0."""
    img = img.convert("RGBA")
    pixels = img.load()
    w, h = img.size

    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            should_remove = False

            if mode == "gray":
                # Gray bg: channels are similar AND pixel is bright-ish
                max_c = max(r, g, b)
                min_c = min(r, g, b)
                diff = max_c - min_c
                brightness = (r + g + b) / 3
                if diff < 45 and brightness > 85:
                    # Stronger removal for very uniform grays
                    strength = max(0, 1.0 - diff / 45) * min(1.0, (brightness - 60) / 120)
                    new_alpha = int(a * (1.0 - strength * 0.95))
                    pixels[x, y] = (r, g, b, new_alpha)

            elif mode == "black":
                brightness = (r + g + b) / 3
                if brightness < 45:
                    strength = max(0, 1.0 - brightness / 45)
                    new_alpha = int(a * (1.0 - strength * 0.95))
                    pixels[x, y] = (r, g, b, new_alpha)

            elif mode == "purple":
                brightness = (r + g + b) / 3
                max_c = max(r, g, b)
                min_c = min(r, g, b)
                diff = max_c - min_c
                # Light uniform-ish background
                if brightness > 140 and diff < 65:
                    strength = max(0, 1.0 - diff / 65) * min(1.0, (brightness - 120) / 100)
                    new_alpha = int(a * (1.0 - strength * 0.9))
                    pixels[x, y] = (r, g, b, new_alpha)

    return img


def get_tight_bbox(img):
    """Get bounding box of non-transparent content."""
    w, h = img.size
    pixels = img.load()
    min_x, min_y = w, h
    max_x, max_y = 0, 0

    for y in range(h):
        for x in range(w):
            if pixels[x, y][3] > 15:  # alpha threshold
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

    if max_x <= min_x or max_y <= min_y:
        return (0, 0, w, h)

    pad = 4
    return (max(0, min_x - pad), max(0, min_y - pad),
            min(w, max_x + pad + 1), min(h, max_y + pad + 1))


def extract_frames(img, cols, rows):
    """Split image into grid cells."""
    w, h = img.size
    fw = w // cols
    fh = h // rows
    frames = []
    for r in range(rows):
        for c in range(cols):
            frame = img.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))
            frames.append(frame)
    return frames


def frame_has_content(img, threshold=15):
    """Check if frame has meaningful non-transparent content."""
    pixels = img.load()
    w, h = img.size
    count = 0
    sample_step = max(1, min(w, h) // 50)  # Sample for speed
    for y in range(0, h, sample_step):
        for x in range(0, w, sample_step):
            if pixels[x, y][3] > threshold:
                count += 1
                if count > 20:
                    return True
    return count > 5


def create_spritesheet(frames):
    """Create horizontal strip from frames with uniform size."""
    # Tight crop each frame
    cropped = []
    for f in frames:
        bbox = get_tight_bbox(f)
        cropped.append(f.crop(bbox))

    # Find max dimensions
    max_w = max(c.width for c in cropped)
    max_h = max(c.height for c in cropped)

    # Pad each to max size (centered)
    padded = []
    for c in cropped:
        p = Image.new("RGBA", (max_w, max_h), (0, 0, 0, 0))
        x_off = (max_w - c.width) // 2
        y_off = (max_h - c.height) // 2
        p.paste(c, (x_off, y_off))
        padded.append(p)

    # Create horizontal strip
    sheet = Image.new("RGBA", (max_w * len(padded), max_h), (0, 0, 0, 0))
    for i, p in enumerate(padded):
        sheet.paste(p, (i * max_w, 0))

    return sheet, max_w, max_h


def process_trap(src_name, out_name, cols, rows, bg_mode):
    """Process one trap PNG."""
    src_path = os.path.join(SRC_DIR, src_name)
    out_path = os.path.join(OUT_DIR, out_name)

    if not os.path.exists(src_path):
        print(f"  SKIP: {src_name} not found")
        return None

    print(f"  {src_name} ({cols}x{rows})")
    img = Image.open(src_path).convert("RGBA")

    # Extract frames
    frames = extract_frames(img, cols, rows)
    print(f"    Extracted {len(frames)} cells")

    # Remove background per frame
    clean_frames = []
    for i, frame in enumerate(frames):
        clean = remove_background(frame, mode=bg_mode)
        if frame_has_content(clean):
            clean_frames.append(clean)
        else:
            print(f"    Frame {i} empty -> skip")

    if not clean_frames:
        print(f"  ERROR: No valid frames!")
        return None

    # Create spritesheet
    sheet, fw, fh = create_spritesheet(clean_frames)
    sheet.save(out_path, "PNG")

    print(f"    -> {out_name}: {len(clean_frames)}f @ {fw}x{fh}, sheet {sheet.width}x{sheet.height}")
    return {
        "name": out_name,
        "frames": len(clean_frames),
        "fw": fw, "fh": fh,
        "sw": sheet.width, "sh": sheet.height,
    }


def main():
    print("=== Trap Sprite Extraction ===")
    print(f"Src: {SRC_DIR}")
    print(f"Out: {OUT_DIR}\n")

    results = {}
    for cfg in TRAP_CONFIGS:
        info = process_trap(*cfg)
        if info:
            results[info["name"]] = info

    print(f"\n=== DONE: {len(results)} spritesheets ===")
    for name, i in results.items():
        print(f"  {name}: {i['frames']}f @ {i['fw']}x{i['fh']}")


if __name__ == "__main__":
    main()
