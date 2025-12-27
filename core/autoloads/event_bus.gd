extends Node
## Central Event Bus for game-wide signal communication
## All systems can connect to these signals for loose coupling

# ============ PLAYER SIGNALS ============
## Emitted when player health changes
signal player_hp_changed(new_hp: int, max_hp: int)

## Emitted when player mana changes
signal player_mana_changed(new_mana: int, max_mana: int)

## Emitted when player takes damage
signal player_damaged(damage: int, source: Node)

## Emitted when player dies
signal player_died()

## Emitted when player respawns
signal player_respawned()

## Emitted when player enters combat
signal player_entered_combat()

## Emitted when player exits combat
signal player_exited_combat()

# ============ ENEMY SIGNALS ============
## Emitted when any enemy takes damage
signal enemy_damaged(enemy: Node, damage: int)

## Emitted when any enemy dies
signal enemy_died(enemy: Node, position: Vector2)

# ============ COMBAT SIGNALS ============
## Emitted when a hit is registered
signal hit_registered(attacker: Node, target: Node, damage: int)

## Emitted when player performs attack
signal player_attacked(attack_number: int)

## Emitted when combo counter increases
signal combo_increased(new_count: int, multiplier: float)

## Emitted when combo chain breaks
signal combo_broken(final_count: int)

## Emitted when damage is calculated with combo applied
signal damage_calculated(final_damage: int, had_combo: bool)

## Emitted when hitstop effect triggers
signal hitstop_triggered(duration: float)

## Emitted when next hit will be a finisher
signal combo_finisher_ready()

## Emitted when a combo finisher is executed
signal combo_finisher_executed(combo_count: int)

## Emitted when leap ender becomes available (after 3rd hit)
signal leap_ender_available()

## Emitted when leap ender is triggered
signal leap_ender_triggered(direction: Vector2)

## Emitted when leap ender is started
signal leap_ender_started(direction: Vector2)

## Emitted when leap ender is completed
signal leap_ender_completed()

## Emitted when resonance value changes
signal resonance_changed(current: float, maximum: float, percentage: float)

## Emitted when combat state starts
signal combat_started()

## Emitted when combat state ends
signal combat_ended()

## Emitted when resonance mode activates
signal resonance_mode_activated()

## Emitted when resonance mode deactivates
signal resonance_mode_deactivated()

## Emitted when resonance mode timer updates (countdown)
signal resonance_mode_timer_updated(time_remaining: float)

# ============ PARRY/BLOCK SIGNALS (Spatial System) ============
## Emitted when parry/block attempt starts (RMB pressed)
signal parry_started()

## Emitted when perfect parry succeeds (enemy in parry ring)
signal perfect_parry_executed(enemy: Node)

## Emitted when normal block succeeds (enemy in block sphere)
signal normal_block_executed(enemy: Node)

## Emitted when attack is blocked (for damage mitigation)
signal attack_blocked(enemy: Node, damage_reduction: float)

## Emitted when enemy is stunned
signal enemy_stunned(enemy: Node, duration: float)

# ============ ENVIRONMENT SIGNALS ============
## Emitted when lever is activated
signal lever_activated(lever: Node)

## Emitted when door state changes
signal door_state_changed(door: Node, new_state: String)

## Emitted when trap activates
signal trap_activated(trap: Node)

# ============ UI SIGNALS ============
## Emitted to show interaction prompt
signal show_interaction_prompt(text: String)

## Emitted to hide interaction prompt
signal hide_interaction_prompt()

# ============ GAME STATE SIGNALS ============
## Emitted when game starts
signal game_started()

## Emitted when game is paused
signal game_paused()

## Emitted when game is unpaused
signal game_unpaused()

## Emitted when returning to main menu
signal return_to_menu()

# ============ SAVE/LOAD SIGNALS ============
## Emitted when checkpoint is activated
signal checkpoint_activated(checkpoint: Node)

## Emitted to open save menu
signal open_save_menu()

## Emitted when save menu is opened
signal save_menu_opened()

## Emitted when load menu is opened
signal load_menu_opened()

## Emitted when menu is closed
signal menu_closed()

## Emitted to show notification message
signal show_notification(message: String, duration: float)

## Emitted when enemy is killed
signal enemy_killed(enemy: Node, killer: Node)

# ============ WORLD/ROOM SIGNALS ============
## Emitted when checkpoint is set
signal checkpoint_set(checkpoint_id: String, position: Vector2)

## Emitted when room is cleared
signal room_cleared(room_id: String)

## Emitted when door is unlocked
signal door_unlocked(door_id: String)

## Emitted when world is unlocked
signal world_unlocked(world_id: String)

## Emitted when boss is defeated
signal boss_defeated(boss_id: String)

# ============ WAVE SYSTEM SIGNALS ============
## Emitted when wave spawner starts
signal wave_spawner_started

## Emitted when new wave starts
signal wave_started(wave_index: int, total_waves: int)

## Emitted when wave is completed
signal wave_completed(wave_index: int, total_waves: int)

## Emitted when all waves are completed
signal all_waves_completed

# ============ PLAYER SIGNALS ============
## Emitted when player has insufficient mana
signal mana_insufficient

# ============ AERIAL COMBAT SIGNALS ============
## Emitted when launcher attack is activated
signal launcher_activated()

## Emitted when an enemy is launched into the air
signal enemy_launched(enemy: Node)

## Emitted when an enemy enters juggle state
signal enemy_juggled(enemy: Node)

## Emitted when air combo starts
signal air_combo_started(enemy: Node)

## Emitted when air hit is registered
signal air_hit_registered(count: int, enemy: Node)

## Emitted when air combo ends
signal air_combo_ended(final_count: int)

## Emitted when slam finisher is executed
signal slam_executed(enemy: Node, damage: int)

## Emitted when Ende der Schwerkraft is executed
signal ende_schwerkraft_executed(enemy: Node)

# ============ DODGE ROLL SIGNALS ============
## Emitted when dodge roll starts
signal dodge_started(direction: Vector2)

## Emitted when dodge roll completes
signal dodge_completed

# ============ WOLKENBRUCH EVENTS ============
## Emitted when Wolkenbruch is activated
signal wolkenbruch_started(powered: bool)

## Emitted when Wolkenbruch impacts the ground
signal wolkenbruch_impact(powered: bool)

## Emitted when Wolkenbruch is completed
signal wolkenbruch_completed

# ============ ECHO VON URGATHON EVENTS ============
## Emitted when Echo von Urgathon is activated
signal echo_von_urgathon_activated()

## Emitted when Echo von Urgathon is deactivated
signal echo_von_urgathon_deactivated()

## Emitted when Echo timer updates (countdown)
signal echo_timer_updated(time_remaining: float)

## Emitted when Echo cooldown updates
signal echo_cooldown_updated(cooldown_remaining: float)

## Emitted when Echo becomes ready after cooldown
signal echo_ready()

## Emitted when mana is gained from Echo hit
signal echo_mana_gained(amount: int)


func _ready() -> void:
	print("[EventBus] Initialized")
