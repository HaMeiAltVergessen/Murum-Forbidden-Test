# Input Map Guide - Keyboard+Mouse + Controller Co-op

## COMMIT 022.5: Hybrid Input System

This document describes the input philosophy and implementation for Murum: Forbidden's local co-op system.

---

## Input Philosophy

**Player 1 (P1)**: **Always Keyboard + Mouse**
- P1 uses keyboard for movement and actions
- P1 uses mouse for aiming and attacks
- No controller support for P1 (design choice for asymmetric co-op)

**Player 2 (P2)**: **Any Controller (Device-Agnostic)**
- P2 uses any connected controller (Xbox, PlayStation, Generic)
- Device-agnostic: P2 input system detects and adapts to any controller
- Multiple controllers can be connected, but only the first detected is used for P2

---

## Input Actions

### P1 (Keyboard + Mouse)

| Action | Input | Description |
|--------|-------|-------------|
| **Movement** | `WASD` | Character movement (no diagonal normalization) |
| **Jump** | `Space` | Jump action |
| **Dash** | `Shift` | Dash/dodge |
| **Attack** | `Left Mouse Button` | Primary attack (direction = mouse position) |
| **Heavy Attack** | `Right Mouse Button` | Heavy attack / charged attack |
| **Interact** | `E` | Interact with objects/NPCs |
| **Inventory** | `Tab` | Open inventory |
| **Pause** | `Esc` | Pause menu |

### P2 (Controller)

| Action | Input (Xbox) | Input (PlayStation) | Description |
|--------|-------------|---------------------|-------------|
| **Movement** | `Left Stick` | `Left Stick` | Character movement (normalized) |
| **Jump** | `A Button` | `✕ (Cross)` | Jump action |
| **Dash** | `B Button` | `○ (Circle)` | Dash/dodge |
| **Attack** | `X Button` | `□ (Square)` | Primary attack (direction = movement) |
| **Heavy Attack** | `Y Button` | `△ (Triangle)` | Heavy attack / charged attack |
| **Interact** | `A Button` | `✕ (Cross)` | Interact with objects/NPCs |
| **Inventory** | `Back/View` | `Share` | Open inventory |
| **Join Game** | `Start` | `Options` | Join as P2 / Leave game |

---

## Technical Implementation

### InputManager (`core/autoloads/input_manager.gd`)

The InputManager handles all input detection and routing for both players:

```gdscript
# Controller detection
var p2_controller_device: int = -1
var detected_controllers: Array[int] = []

# Detect controllers on startup
func detect_controllers() -> void:
    detected_controllers.clear()
    var joypads = Input.get_connected_joypads()
    for device_id in joypads:
        detected_controllers.append(device_id)

# Get P1 input (Keyboard + Mouse)
func get_p1_input_vector() -> Vector2:
    return Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")

# Get P2 input (Controller only)
func get_p2_input_vector() -> Vector2:
    if p2_controller_device == -1:
        return Vector2.ZERO

    var x = Input.get_joy_axis(p2_controller_device, JOY_AXIS_LEFT_X)
    var y = Input.get_joy_axis(p2_controller_device, JOY_AXIS_LEFT_Y)

    # Apply deadzone
    if abs(x) < 0.2: x = 0.0
    if abs(y) < 0.2: y = 0.0

    return Vector2(x, y).normalized()
```

### Controller Hotplug Support

The InputManager listens for controller connect/disconnect events:

```gdscript
func _ready() -> void:
    # Listen for controller hotplug
    Input.joy_connection_changed.connect(_on_controller_connection_changed)
    detect_controllers()

func _on_controller_connection_changed(device: int, connected: bool) -> void:
    if connected:
        print("[InputManager] Controller connected: Device %d" % device)
        detected_controllers.append(device)
    else:
        print("[InputManager] Controller disconnected: Device %d" % device)
        detected_controllers.erase(device)

        # If P2's controller disconnected, despawn P2
        if device == p2_controller_device:
            print("[InputManager] P2's controller disconnected!")
            p2_leave_requested.emit()
            p2_controller_device = -1
```

### Controller Type Detection

The tutorial system detects controller type to display appropriate button names:

```gdscript
func get_button_names_for_controller(controller_name: String) -> Dictionary:
    var name_lower = controller_name.to_lower()

    # Xbox controllers
    if "xbox" in name_lower or "xinput" in name_lower:
        return {
            "jump": "A Button",
            "attack": "X Button",
            "dash": "B Button",
            "heavy_attack": "Y Button",
            "interact": "A Button",
            "inventory": "Back Button",
            "start": "Start Button"
        }

    # PlayStation controllers
    elif "playstation" in name_lower or "dualshock" in name_lower or "dualsense" in name_lower:
        return {
            "jump": "✕ (Cross)",
            "attack": "□ (Square)",
            "dash": "○ (Circle)",
            "heavy_attack": "△ (Triangle)",
            "interact": "✕ (Cross)",
            "inventory": "Share Button",
            "start": "Options Button"
        }

    # Generic controllers (fallback)
    else:
        return {
            "jump": "Button 0",
            "attack": "Button 2",
            "dash": "Button 1",
            "heavy_attack": "Button 3",
            "interact": "Button 0",
            "inventory": "Button 6",
            "start": "Button 7"
        }
```

---

## UI Integration

### Join Prompt with Controller Check

The join prompt (`ui/hud/join_prompt.gd`) checks for controller availability:

```gdscript
func check_controller_and_show_prompt() -> void:
    if not InputManager.has_controller():
        # No controller detected
        prompt_label.text = "Connect a controller to join as Lythrun"
        warning_label.text = "⚠ No controller detected"
        warning_label.visible = true
        warning_label.modulate = Color(1.0, 0.6, 0)  # Orange
    else:
        # Controller detected
        prompt_label.text = "Press START on controller to join as Lythrun"
        warning_label.visible = false
```

### P2 Tutorial with Controller-Specific Buttons

The P2 tutorial (`ui/hud/p2_tutorial.gd`) dynamically shows button names based on detected controller:

```gdscript
func populate_controller_controls() -> void:
    var controller_name = InputManager.get_p2_controller_name()
    var button_names = get_button_names_for_controller(controller_name)

    # Update UI labels
    controls_grid.get_node("JumpInput").text = button_names.get("jump", "A Button")
    controls_grid.get_node("AttackInput").text = button_names.get("attack", "X Button")
    controls_grid.get_node("DashInput").text = button_names.get("dash", "B Button")
    # ... etc
```

---

## Input Map Configuration

### project.godot Input Actions

```ini
[input]

# ============ PLAYER 1 (Keyboard + Mouse) ============
p1_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":65,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}

p1_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":68,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}

p1_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":87,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}

p1_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":83,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}

p1_jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}

p1_dash={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194325,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}

p1_attack={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}

# ============ PLAYER 2 (Controller) ============
# Note: P2 uses device-specific joy axis/button queries
# No InputEventJoypadButton defined here - handled in code
```

---

## Testing

### Test Checklist

- [ ] P1 can move with WASD
- [ ] P1 can attack with mouse clicks
- [ ] Controller detected on startup
- [ ] Join prompt shows "Press START" when controller detected
- [ ] Join prompt shows warning when no controller detected
- [ ] P2 can join with Start button
- [ ] P2 can move with left stick
- [ ] P2 can jump/dash/attack with buttons
- [ ] P2 tutorial shows correct button names for Xbox controller
- [ ] P2 tutorial shows correct button names for PlayStation controller
- [ ] Controller disconnect despawns P2
- [ ] Controller reconnect allows P2 to rejoin

---

## Common Issues

### Issue: "No controller detected" but controller is plugged in
**Solution**: Check if controller is recognized by OS. Test with `Input.get_connected_joypads()` in Godot console.

### Issue: P2 input not working
**Solution**: Check `InputManager.p2_controller_device` is set correctly. Should be >= 0 when P2 is active.

### Issue: Wrong button names in tutorial
**Solution**: Check `Input.get_joy_name(device_id)` output. Add pattern to `get_button_names_for_controller()` if needed.

### Issue: P2 doesn't despawn when controller disconnected
**Solution**: Verify `joy_connection_changed` signal is connected in `InputManager._ready()`.

---

## Future Enhancements

- [ ] Support for rebinding P2 controls
- [ ] Support for multiple simultaneous P2 players (3-4 player co-op)
- [ ] Haptic feedback integration for controllers
- [ ] Adaptive triggers for DualSense controllers
- [ ] Steam Input API integration

---

**Last Updated**: COMMIT 022.5
**Author**: Murum: Forbidden Development Team
