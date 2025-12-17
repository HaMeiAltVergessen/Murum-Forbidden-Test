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

## Emitted when resonance value changes
signal resonance_changed(current: float, maximum: float, percentage: float)

## Emitted when combat state starts
signal combat_started()

## Emitted when combat state ends
signal combat_ended()

## Emitted when resonance mode timer updates (countdown)
signal resonance_mode_timer_updated(time_remaining: float)

# ============ PARRY SIGNALS ============
## Emitted when parry attempt starts
signal parry_started()

## Emitted when parry window opens (active parry frame)
signal parry_window_opened()

## Emitted when perfect parry succeeds
signal perfect_parry(enemy: Node)

## Emitted when parry fails (timeout)
signal parry_failed()

## Emitted when parry cooldown starts
signal parry_cooldown_started(duration: float)

## Emitted when parry cooldown updates
signal parry_cooldown_updated(time_remaining: float)

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


func _ready() -> void:
	print("[EventBus] Initialized")
