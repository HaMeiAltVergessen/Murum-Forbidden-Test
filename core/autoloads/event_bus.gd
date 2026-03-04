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

## P2 combo signals
signal p2_combo_finisher_ready()
signal p2_combo_finisher_executed(combo_count: int)
signal p2_combo_broken(final_count: int)

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

# ============ REBOUND SYSTEM SIGNALS (Commit 018) ============
## Emitted when parry counter progresses
signal rebound_progress(current: int, required: int)

## Emitted when Rebound Ready state is activated (3/3 parrys)
signal rebound_ready()

## Emitted when Rebound counter is executed
signal rebound_executed(enemy: Node)

# ============ MACHTBRUCH SYSTEM SIGNALS (Commit 019) ============
## Emitted when Machtbruch becomes available (after 3rd combo hit)
signal machtbruch_available()

## Emitted when Machtbruch charging starts
signal machtbruch_charge_started()

## Emitted when Machtbruch charge is complete
signal machtbruch_charge_completed()

## Emitted when Machtbruch burst is released
signal machtbruch_released(tier: int, damage: int, radius: float)

## Emitted when Machtbruch is cancelled (released too early)
signal machtbruch_cancelled()

# ============ MACHTSTOSS SYSTEM SIGNALS (Commit 020) ============
## Emitted when Machtstoß knockback wave is activated
signal machtstoss_activated(position: Vector2)

## Emitted when Machtstoß hits an enemy
signal machtstoss_hit_enemy(enemy: Node)

## Emitted when Machtstoß cooldown starts
signal machtstoss_cooldown_started(duration: float)

## Emitted when Machtstoß cooldown finishes
signal machtstoss_cooldown_finished()

# ============ URTEIL SYSTEM SIGNALS (Commit 021) ============
## Emitted when Urteil (Death Mark) is activated
signal urteil_activated(enemy: Node)

## Emitted when death mark is applied to an enemy
signal urteil_mark_applied(enemy: Node)

## Emitted when death mark expires naturally (not triggered)
signal urteil_mark_expired(enemy: Node)

## Emitted when marked enemy dies and explosion triggers
signal urteil_explosion_triggered(position: Vector2, enemy: Node)

## Emitted when an enemy is hit by explosion (pull + damage)
signal urteil_enemy_hit(enemy: Node, damage: int)

## Emitted when Urteil cooldown starts
signal urteil_cooldown_started(duration: float)

## Emitted when Urteil cooldown finishes
signal urteil_cooldown_finished()

# ============ ECHO SYSTEM SIGNALS (Commit 022) ============
## Emitted when Echo von Urgathon is activated
signal echo_activated()

## Emitted when Echo is deactivated (duration expired)
signal echo_deactivated()

## Emitted when player hits enemy while Echo is active (mana gained)
signal echo_hit_registered(mana_gained: int)

## Emitted every 2 seconds while Echo is active (visual pulse)
signal echo_pulse()

## Emitted when Echo duration expires naturally
signal echo_duration_expired()

## Emitted when Echo cooldown starts
signal echo_cooldown_started(duration: float)

## Emitted when Echo cooldown finishes
signal echo_cooldown_finished()

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

# ============ CUTSCENE SIGNALS ============
## Emitted when a cutscene starts playing
signal cutscene_started(cutscene_id: String)

## Emitted when a cutscene finishes (completed or skipped)
signal cutscene_finished(cutscene_id: String, was_skipped: bool)

## Emitted when a cutscene is paused
signal cutscene_paused(cutscene_id: String)

## Emitted when a cutscene is resumed
signal cutscene_resumed(cutscene_id: String)

## Emitted when an engine cutscene (in-game camera sequence) starts
signal engine_cutscene_started(cutscene_id: String)

## Emitted when a subtitle is shown
signal subtitle_shown(text: String, speaker: String)

## Emitted when a subtitle is hidden
signal subtitle_hidden()

## Emitted when user requests to skip a cutscene
signal cutscene_skip_requested(cutscene_id: String)

# ============ DIALOG SIGNALS ============
## Emitted when a dialog starts
signal dialog_started(dialog_id: String)

## Emitted when a dialog finishes (completed or choice selected)
signal dialog_finished(dialog_id: String)

## Emitted when a dialog choice is selected
signal dialog_choice_selected(dialog_id: String, choice_index: int)

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
## Emitted when mana is gained from Echo passive ability
signal echo_mana_gained(amount: int)
# ============ LUFTGOTT (AIR RESET) EVENTS ============
## Emitted when air reset window opens (after air combo ends)
signal air_reset_window_started()

## Emitted when air reset is activated
signal air_reset_activated(enemy: Node)

## Emitted when air reset hit is performed
signal air_reset_hit(count: int, damage: int)

## Emitted when air reset ends
signal air_reset_ended(total_hits: int)

# ============ ACHIEVEMENT SIGNALS ============
## Emitted when an achievement is unlocked
signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)

# ============ STATISTICS SIGNALS ============
## Emitted when damage is dealt to an enemy
signal damage_dealt(amount: int, target: Node)

## Emitted when player takes damage (for statistics tracking)
signal damage_taken(amount: int, source: Node)

## Emitted when Urgathon ability is activated
signal urgathon_activated()

## Emitted when a secret is found
signal secret_found(secret_id: String)

# ============ CHALLENGE RUN SIGNALS ============
## Emitted when a challenge run starts
signal challenge_run_started(modifiers: Dictionary)

## Emitted when a challenge run is completed successfully
signal challenge_run_completed(modifiers: Dictionary)

## Emitted when a challenge run fails (e.g., time limit exceeded)
signal challenge_run_failed(reason: String)

## Emitted when challenge timer updates (for Zeitlimit)
signal challenge_time_updated(remaining: float)

# ============ INVENTORY SIGNALS ============
## Emitted when a relic is equipped (stats should be applied)
signal relic_equipped(relic_id: String, stats: Dictionary)

## Emitted when a relic is unequipped (stats should be removed)
signal relic_unequipped(relic_id: String, stats: Dictionary)

## Emitted when an item is picked up
signal item_picked_up(item_id: String, item_name: String, category: String)

## Emitted when a consumable buff is applied (handled by BuffManager)
signal consumable_buff_applied(item_data: Dictionary)

# ============ CURRENCY SIGNALS ============
## Emitted when player's gold/coins change
signal coins_changed(new_amount: int)


func _ready() -> void:
	print("[EventBus] Initialized")
