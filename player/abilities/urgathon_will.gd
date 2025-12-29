extends Node
class_name UrgathonWill

## Urgathon's Will - Ultimate Ability
## Hold R to charge (0-3s), release to unleash devastating fullscreen damage
## Limited uses with increasing unconscious duration penalty

# ============================================================================
# CONSTANTS - Charging
# ============================================================================

const CHARGE_DURATION: float = 3.0  # Max charge time
const TIME_SLOW_SCALE: float = 0.2  # 80% slowdown during charge

# Charge level thresholds (in seconds)
const LEVEL_THRESHOLDS: Array[float] = [0.0, 1.0, 2.0, 3.0]

# ============================================================================
# CONSTANTS - Release (Part 2)
# ============================================================================

const LEVEL_1_DAMAGE: int = 1000
const LEVEL_2_DAMAGE: int = 2000
const LEVEL_3_DAMAGE: int = 4000

const UNCONSCIOUS_DURATIONS: Array[float] = [4.0, 14.0, 24.0]

# Use limits
var use_count: int = 0
const MAX_USES: int = 4  # 4th use = death/game over

# ============================================================================
# STATE
# ============================================================================

var is_charging: bool = false
var charge_timer: float = 0.0
var charge_level: int = 0  # 0-3 (0 = no charge, 1-3 = release levels)

var is_unconscious: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var player: CharacterBody2D = owner

# UI References (will be created/found)
var vignette: ColorRect = null
var charge_bar: ProgressBar = null
var use_counter_label: Label = null
var blackscreen: ColorRect = null

# ============================================================================
# SIGNALS
# ============================================================================

signal urgathon_charge_started()
signal urgathon_charge_level_changed(level: int)
signal urgathon_released(level: int)
signal urgathon_unconscious_started(duration: float)
signal urgathon_unconscious_ended()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[UrgathonWill] Initialized (Urgathon's Will)")

	# UI elements will be created/found later
	call_deferred("_setup_ui")

func _setup_ui() -> void:
	"""Sets up UI references (deferred to ensure UI exists)"""
	# HUD is now an Autoload, access it directly
	var hud = get_node_or_null("/root/HUD")

	if not hud:
		print("[UrgathonWill] ERROR: HUD Autoload not found!")
		return

	charge_bar = hud.get_node_or_null("UrgathonChargeBar")
	use_counter_label = hud.get_node_or_null("UrgathonCounter")
	blackscreen = hud.get_node_or_null("UrgathonBlackscreen")

	if not charge_bar:
		print("[UrgathonWill] WARNING: Charge bar not found in HUD")
	else:
		charge_bar.visible = false

	if not use_counter_label:
		print("[UrgathonWill] WARNING: Use counter label not found in HUD")
	else:
		_update_counter_ui()

	if not blackscreen:
		print("[UrgathonWill] WARNING: Blackscreen not found in HUD")
	else:
		blackscreen.visible = false

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	# Debug: Log all joypad button presses
	if event is InputEventJoypadButton and event.pressed:
		print("[UrgathonWill] DEBUG: Joypad button pressed: ", event.button_index)

	# Debug: Log urgathon_charge action
	if event.is_action_pressed("urgathon_charge"):
		print("[UrgathonWill] DEBUG: urgathon_charge action pressed!")

	# Don't allow charging while unconscious
	if is_unconscious:
		print("[UrgathonWill] DEBUG: Cannot charge - unconscious")
		return

	# Start charging
	if event.is_action_pressed("urgathon_charge"):
		print("[UrgathonWill] DEBUG: Starting charge...")
		_start_charge()

	# Release charge
	if event.is_action_released("urgathon_charge"):
		print("[UrgathonWill] DEBUG: Releasing charge...")
		_release_charge()

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	if not is_charging:
		return

	# Use real delta (not affected by time scale)
	var real_delta = delta / Engine.time_scale
	charge_timer += real_delta

	# Clamp to max duration
	if charge_timer > CHARGE_DURATION:
		charge_timer = CHARGE_DURATION

	# Update charge level
	var new_level = _calculate_charge_level(charge_timer)
	if new_level != charge_level:
		charge_level = new_level
		urgathon_charge_level_changed.emit(charge_level)
		print("[UrgathonWill] Charge level: ", charge_level)

	# Update visuals
	_update_charge_visuals()

# ============================================================================
# CHARGING
# ============================================================================

func _start_charge() -> void:
	"""Starts charging Urgathon's Will"""
	if is_charging:
		return

	# Check if uses exhausted
	if use_count >= MAX_USES:
		print("[UrgathonWill] No uses remaining!")
		return

	print("[UrgathonWill] ===== CHARGE STARTED =====")

	is_charging = true
	charge_timer = 0.0
	charge_level = 0

	# Slow time
	Engine.time_scale = TIME_SLOW_SCALE

	# Start looping sound (TODO: Add sound file)
	# AudioManager.play_sfx_looped("urgathon_charge")

	# Show charge bar
	if charge_bar:
		charge_bar.visible = true
		charge_bar.value = 0

	# Emit signal
	urgathon_charge_started.emit()

func _calculate_charge_level(time: float) -> int:
	"""Calculates charge level based on time"""
	if time >= LEVEL_THRESHOLDS[3]:
		return 3
	elif time >= LEVEL_THRESHOLDS[2]:
		return 2
	elif time >= LEVEL_THRESHOLDS[1]:
		return 1
	else:
		return 0

func _update_charge_visuals() -> void:
	"""Updates charge bar and vignette"""
	var percent = charge_timer / CHARGE_DURATION

	# Update charge bar
	if charge_bar:
		charge_bar.value = percent * 100.0

	# Update vignette (if implemented)
	_update_vignette(percent)

func _update_vignette(percent: float) -> void:
	"""Updates vignette darkness based on charge percent"""
	# Vignette implementation depends on your UI setup
	# This is a placeholder - can be enhanced with shader
	if vignette:
		var color = vignette.color
		color.a = percent * 0.7  # Max 70% opacity
		vignette.color = color

# ============================================================================
# RELEASE (Part 2)
# ============================================================================

func _release_charge() -> void:
	"""Releases charged energy"""
	if not is_charging:
		return

	print("[UrgathonWill] ===== CHARGE RELEASED ===== Level: ", charge_level)

	# Must have at least level 1 charge
	if charge_level < 1:
		print("[UrgathonWill] Charge too low - cancelled")
		_cancel_charge()
		return

	# Stop charging state
	is_charging = false

	# Reset time scale
	Engine.time_scale = 1.0

	# Stop sound (TODO: Add sound file)
	# AudioManager.stop_sfx_looped("urgathon_charge")

	# Hide charge bar
	if charge_bar:
		charge_bar.visible = false

	# Clear vignette
	_clear_vignette()

	# Execute release
	_execute_release(charge_level)

func _cancel_charge() -> void:
	"""Cancels charge without releasing"""
	is_charging = false
	Engine.time_scale = 1.0
	# AudioManager.stop_sfx_looped("urgathon_charge")

	if charge_bar:
		charge_bar.visible = false

	_clear_vignette()

func _clear_vignette() -> void:
	"""Clears vignette effect"""
	if vignette:
		var color = vignette.color
		color.a = 0.0
		vignette.color = color

func _execute_release(level: int) -> void:
	"""Executes the release effect based on charge level"""
	print("[UrgathonWill] Executing release - Level %d" % level)

	# Increment use count
	use_count += 1
	_update_counter_ui()

	# Check if this was the last use
	if use_count >= MAX_USES:
		print("[UrgathonWill] FINAL USE - Triggering game over")
		_trigger_game_over()
		return

	# Calculate damage
	var damage = 0
	match level:
		1: damage = LEVEL_1_DAMAGE
		2: damage = LEVEL_2_DAMAGE
		3: damage = LEVEL_3_DAMAGE
		_: damage = 0

	print("[UrgathonWill] Fullscreen damage: %d" % damage)

	# Deal damage to all enemies
	_deal_fullscreen_damage(damage)

	# Spawn VFX
	_spawn_explosion(level)

	# Play release sound (TODO: Add sound file)
	# AudioManager.play_sfx("urgathon_release")

	# Camera shake (TODO: Fix camera reference)
	# if player and player.has_node("PlayerCamera"):
	# 	player.get_node("PlayerCamera").add_trauma(1.0)  # Max trauma

	# Enter unconscious state
	var duration = UNCONSCIOUS_DURATIONS[use_count - 1]
	_enter_unconscious(duration)

	# Emit signal
	urgathon_released.emit(level)

func _deal_fullscreen_damage(damage: int) -> void:
	"""Deals damage to all enemies on screen"""
	var enemies = get_tree().get_nodes_in_group("enemies")

	print("[UrgathonWill] Damaging %d enemies" % enemies.size())

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Try direct method first
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, player)
			print("[UrgathonWill] Dealt %d damage to %s (direct)" % [damage, enemy.name])
		# Fallback to HealthComponent
		elif enemy.has_node("HealthComponent"):
			var health = enemy.get_node("HealthComponent")
			if health.has_method("take_damage"):
				health.take_damage(damage)
				print("[UrgathonWill] Dealt %d damage to %s (HealthComponent)" % [damage, enemy.name])

func _spawn_explosion(level: int) -> void:
	"""Spawns explosion VFX based on level"""
	# Placeholder - can be enhanced with particle system
	print("[UrgathonWill] Spawning level %d explosion VFX" % level)

	# Flash screen white (TODO: Implement screen flash)
	# if player and player.has_node("PlayerCamera"):
	# 	var camera = player.get_node("PlayerCamera")
	# 	# Screen flash effect would go here

func _enter_unconscious(duration: float) -> void:
	"""Enters unconscious state for specified duration"""
	print("[UrgathonWill] Entering unconscious state for %.1fs" % duration)

	is_unconscious = true
	urgathon_unconscious_started.emit(duration)

	# Completely freeze player
	if player:
		# Stop all movement
		player.velocity = Vector2.ZERO

		# Disable physics and input
		player.set_physics_process(false)
		player.set_process_input(false)

		# Disable MovementController
		var movement = player.get_node_or_null("MovementController")
		if movement:
			movement.set_process(false)
			movement.set_physics_process(false)
			print("[UrgathonWill] MovementController disabled")

	# Fade to black
	if blackscreen:
		blackscreen.visible = true
		blackscreen.mouse_filter = Control.MOUSE_FILTER_STOP  # Block all input
		blackscreen.z_index = 100  # Ensure on top

		# Fade in (transparent to black)
		var tween = create_tween()
		tween.tween_property(blackscreen, "color:a", 1.0, 1.0)
		await tween.finished
		print("[UrgathonWill] Faded to black")
	else:
		print("[UrgathonWill] WARNING: No blackscreen - skipping fade")

	# Wait for unconscious duration
	await get_tree().create_timer(duration).timeout

	# Wake up
	_exit_unconscious()

func _exit_unconscious() -> void:
	"""Exits unconscious state"""
	print("[UrgathonWill] Waking up from unconscious state")

	# Fade from black
	if blackscreen:
		# Fade out (black to transparent)
		var tween = create_tween()
		tween.tween_property(blackscreen, "color:a", 0.0, 2.0)
		await tween.finished

		blackscreen.visible = false
		blackscreen.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Re-allow input
		print("[UrgathonWill] Faded from black")
	else:
		# Wait a bit anyway
		await get_tree().create_timer(2.0).timeout

	is_unconscious = false
	urgathon_unconscious_ended.emit()

	# Re-enable player control
	if player:
		player.set_physics_process(true)
		player.set_process_input(true)

		# Re-enable MovementController
		var movement = player.get_node_or_null("MovementController")
		if movement:
			movement.set_process(true)
			movement.set_physics_process(true)
			print("[UrgathonWill] MovementController re-enabled")

func _trigger_game_over() -> void:
	"""Triggers game over (4th use)"""
	print("[UrgathonWill] GAME OVER - 4th use! Closing game...")

	# Wait a moment
	await get_tree().create_timer(2.0).timeout

	# Quit the game (as requested)
	get_tree().quit()

func _update_counter_ui() -> void:
	"""Updates the use counter UI"""
	if use_counter_label:
		use_counter_label.text = "Urgathon Uses: %d/%d" % [use_count, MAX_USES]
