# INPUT MAPPING GUIDE - Murum Forbidden

## Controller Button Reference (Xbox Standard):
- Button 0 = A
- Button 1 = B
- Button 2 = X
- Button 3 = Y
- Button 4 = LB (Left Bumper)
- Button 5 = RB (Right Bumper)
- Button 6 = LT (Left Trigger)
- Button 7 = RT (Right Trigger)
- Button 8 = Back/View
- Button 9 = Start/Menu
- Button 10 = Left Stick Click (L3)
- Button 11 = Right Stick Click (R3)

## P1 (Murum) - Hybrid Input

| Action | Keyboard | Controller (Solo) | InputMap Name |
|--------|----------|-------------------|---------------|
| Move Left | A / Left Arrow | Left Stick | p1_move_left |
| Move Right | D / Right Arrow | Left Stick | p1_move_right |
| Jump | SPACE | A (button 0) | p1_jump |
| Attack | Left Click | X (button 2) | p1_attack |
| Dodge Roll | CTRL | B (button 1) | dodge |
| Dash | SHIFT | LB (button 4) | p1_dash |
| Block | Right Click | LT (button 6) | p1_block |
| Staff Throw | Q | RT+Y (combo: 7+3) | staff_throw |
| Interact | E | Y (button 3) | p1_interact |
| Urgathon | R | RB (button 5) | urgathon_charge |
| Inventory | TAB | Back (button 8) | p1_inventory |

## P2 (Lythrun) - Controller Only

| Action | Controller Button | InputMap Name | Device |
|--------|-------------------|---------------|--------|
| Move | Left Stick | (analog) | 1 |
| Jump | A (button 0) | jump | 1 |
| Attack (Void Strike) | X (button 2) | attack | 1 |
| Shadow Dash | B (button 1) | dash | 1 |
| Shadow Scythe | Y (button 3) | shadow_scythe | 1 |
| Void Parry | LT (button 6) | void_parry | 1 |
| Void Rift | Attack+Down (combo) | (custom logic) | 1 |
| Void Orbs (charge) | RT (button 7) | ultimate | 1 |
| Phase-Shift | RB (button 5) | phase_shift | 1 |
| Inventory | Back (button 8) | inventory | 1 |

## Special Cases:

### P1 Staff Throw (RT + Y Combo):
- **Challenge:** Godot InputMap doesn't support multi-button combos natively
- **Solution:** Check both buttons in code:
  ```gdscript
  if Input.is_action_pressed("p1_modifier_rt") and Input.is_action_just_pressed("p1_button_y"):
      staff_throw()
  ```

### P2 Void Rift (Attack + Down in Air):
- **Implementation:** Check in `_process()`:
  ```gdscript
  if is_in_air() and Input.is_action_pressed("attack") and Input.get_vector(...).y > 0.5:
      void_rift()
  ```

## Key Changes from Current:

1. **dodge** input:
   - REMOVE: Joypad Button 1 (device -1)
   - KEEP: SHIFT key for P1
   - ADD: Joypad Button 1 (device 0) for P1 solo mode

2. **p1_dash**:
   - CHANGE: Button 1 → Button 4 (LB)
   - KEEP: SHIFT key

3. **p2_ultimate** (for Void Orbs):
   - CHANGE: Button 9 (R3) → Button 7 (RT)
   - Device: 1

4. **NEW: p2_phase_shift**:
   - ADD: Button 5 (RB)
   - Device: 1

5. **staff_throw**:
   - Requires combo detection in code (RT+Y)
   - Create helper inputs: p1_modifier_rt, p1_button_y
