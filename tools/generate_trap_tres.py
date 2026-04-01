"""
Generate Godot SpriteFrames .tres files for all trap spritesheets.
Each trap gets a .tres with named animations pointing to AtlasTexture regions.
"""
import os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET_DIR = "res://Assets/AIPlaceholder/Fallen_Spritesheets"
OUT_DIR = os.path.join(BASE, "traps", "sprites")
os.makedirs(OUT_DIR, exist_ok=True)

# ============================================================================
# CONFIGS: Each entry defines a trap's spritesheet and animation mapping
# "anims": dict of animation_name -> list of frame indices (0-based)
# ============================================================================

CONFIGS = {
    "arrow_trap_frames": {
        "sheet": "arrow_trap_sheet.png",
        "fw": 499, "fh": 256, "total": 6,
        "anims": {
            "idle": [0],
            "loaded": [1, 2],
            "firing": [3, 4],
        },
        "speeds": {"idle": 1.0, "loaded": 3.0, "firing": 8.0},
        "loops": {"idle": False, "loaded": False, "firing": False},
    },
    "falling_rock_frames": {
        "sheet": "falling_rock_sheet.png",
        "fw": 384, "fh": 388, "total": 4,
        "anims": {
            "ceiling": [0, 1],
            "falling": [2],
            "debris": [3],
        },
        "speeds": {"ceiling": 3.0, "falling": 5.0, "debris": 1.0},
        "loops": {"ceiling": True, "falling": False, "debris": False},
    },
    "quicksand_frames": {
        "sheet": "quicksand_sheet.png",
        "fw": 512, "fh": 324, "total": 3,
        "anims": {
            "idle": [0],
            "active": [1],
            "pulling": [2],
        },
        "speeds": {}, "loops": {"idle": True, "active": True, "pulling": True},
    },
    "spike_trap_frames": {
        "sheet": "spike_trap_sheet.png",
        "fw": 481, "fh": 533, "total": 3,
        "anims": {
            "off": [0],
            "warning": [1],
            "active": [2],
        },
        "speeds": {}, "loops": {},
    },
    "electro_panel_frames": {
        "sheet": "electro_panel_sheet.png",
        "fw": 1335, "fh": 228, "total": 3,
        "anims": {
            "off": [0],
            "warning": [1],
            "active": [2],
        },
        "speeds": {}, "loops": {},
    },
    "gravity_anomaly_frames": {
        "sheet": "gravity_anomaly_sheet.png",
        "fw": 482, "fh": 428, "total": 3,
        "anims": {
            "dormant": [0],
            "active": [1],
            "energized": [2],
        },
        "speeds": {}, "loops": {},
    },
    "energy_turret_frames": {
        "sheet": "energy_turret_sheet.png",
        "fw": 384, "fh": 360, "total": 4,
        "anims": {
            "idle": [0],
            "patrol": [1],
            "retracted": [2],
            "emerging": [3],
        },
        "speeds": {}, "loops": {},
    },
    "energy_bolt_frames": {
        "sheet": "energy_bolt_sheet.png",
        "fw": 485, "fh": 154, "total": 2,
        "anims": {
            "default": [0, 1],
        },
        "speeds": {"default": 5.0}, "loops": {"default": True},
    },
    "force_field_frames": {
        "sheet": "force_field_sheet.png",
        "fw": 250, "fh": 833, "total": 4,
        "anims": {
            "idle": [0],
            "warning": [1],
            "active": [2],
            "max": [3],
        },
        "speeds": {}, "loops": {},
    },
    "security_drone_frames": {
        "sheet": "security_drone_sheet.png",
        "fw": 368, "fh": 345, "total": 5,
        "anims": {
            "patrol": [0],
            "firing": [1],
            "alert": [2],
            "stunned": [3],
            "destroyed": [4],
        },
        "speeds": {}, "loops": {},
    },
    "void_rift_frames": {
        "sheet": "void_rift_sheet.png",
        "fw": 453, "fh": 1024, "total": 3,
        "anims": {
            "active": [0],
            "teleporting": [1],
            "cooldown": [2],
        },
        "speeds": {}, "loops": {},
    },
    "cosmic_eye_frames": {
        "sheet": "cosmic_eye_sheet.png",
        "fw": 307, "fh": 291, "total": 5,
        "anims": {
            "closed": [0],
            "opening": [1],
            "tracking": [2],
            "firing": [3],
            "destroyed": [4],
        },
        "speeds": {}, "loops": {},
    },
    "eye_laser_frames": {
        "sheet": "eye_laser_sheet.png",
        "fw": 497, "fh": 176, "total": 2,
        "anims": {
            "default": [0, 1],
        },
        "speeds": {"default": 5.0}, "loops": {"default": True},
    },
    "shadow_tendril_frames": {
        "sheet": "shadow_tendril_sheet.png",
        "fw": 384, "fh": 850, "total": 4,
        "anims": {
            "dormant": [0],
            "emerging": [1],
            "grabbed": [2],
            "retracted": [3],
        },
        "speeds": {}, "loops": {},
    },
    "time_distortion_frames": {
        "sheet": "time_distortion_sheet.png",
        "fw": 675, "fh": 569, "total": 2,
        "anims": {
            "inactive": [0],
            "active": [1],
        },
        "speeds": {}, "loops": {},
    },
    "pendulum_blade_frames": {
        "sheet": "pendulum_blade_sheet.png",
        "fw": 512, "fh": 1024, "total": 3,
        "anims": {
            "center": [0],
            "left": [1],
            "right": [2],
        },
        "speeds": {}, "loops": {},
    },
}


def generate_tres(name, cfg):
    """Generate a .tres SpriteFrames file."""
    sheet_path = f"{SHEET_DIR}/{cfg['sheet']}"
    fw, fh = cfg["fw"], cfg["fh"]

    # Collect all unique frame indices
    all_frames = set()
    for indices in cfg["anims"].values():
        all_frames.update(indices)
    all_frames = sorted(all_frames)

    load_steps = len(all_frames) + 2  # ext_resource script + texture + sub_resources

    lines = []
    lines.append(f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]')
    lines.append('')
    lines.append(f'[ext_resource type="Texture2D" path="{sheet_path}" id="1_sheet"]')
    lines.append('')

    # Sub-resources (AtlasTextures)
    for idx in all_frames:
        x = idx * fw
        lines.append(f'[sub_resource type="AtlasTexture" id="frame_{idx}"]')
        lines.append(f'atlas = ExtResource("1_sheet")')
        lines.append(f'region = Rect2({x}, 0, {fw}, {fh})')
        lines.append('')

    # Resource with animations
    lines.append('[resource]')

    anim_parts = []
    for anim_name, frame_indices in cfg["anims"].items():
        speed = cfg.get("speeds", {}).get(anim_name, 5.0)
        loop = cfg.get("loops", {}).get(anim_name, False)

        frame_entries = []
        for fi in frame_indices:
            frame_entries.append(f'{{\n"duration": 1.0,\n"texture": SubResource("frame_{fi}")\n}}')

        frames_str = ", ".join(frame_entries)
        loop_str = "true" if loop else "false"

        anim_parts.append(
            f'{{\n"frames": [{frames_str}],\n'
            f'"loop": {loop_str},\n'
            f'"name": &"{anim_name}",\n'
            f'"speed": {speed}\n}}'
        )

    lines.append(f'animations = [{", ".join(anim_parts)}]')
    lines.append('')

    out_path = os.path.join(OUT_DIR, f"{name}.tres")
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    anim_names = list(cfg["anims"].keys())
    print(f"  {name}.tres -> {len(anim_names)} anims: {anim_names}")
    return out_path


def main():
    print("=== Generating SpriteFrames .tres files ===\n")

    for name, cfg in CONFIGS.items():
        generate_tres(name, cfg)

    print(f"\nDone: {len(CONFIGS)} .tres files in {OUT_DIR}")


if __name__ == "__main__":
    main()
