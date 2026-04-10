extends Node2D
class_name ParryBlockSystem

## Timing + Spatial Parry/Block system
## - Parry: First 1 second after RMB press = Perfect Parry (enemy dies)
## - Block: After 1 second = Normal Block (costs mana on hit, based on attack category)
## - Player is invulnerable during both parry and block

# ============================================================================
# CONSTANTS
# ============================================================================

# Block Sphere (only one collision area now)
const BLOCK_RADIUS: float = 70.0  # Single sphere for both parry and block
const BLOCK_OFFSET: Vector2 = Vector2.ZERO  # Centered on player

# Parry Timing
const PARRY_WINDOW_DURATION: float = 0.3  # 0.3 second timing window für Parry

# Block Mana Cost
const BLOCK_MANA_DRAIN_INTERVAL: float = 1.5  # Sekunden zwischen Mana-Drain
const BLOCK_MANA_DRAIN_AMOUNT: float = 1.0    # Mana-Menge pro Drain
enum BlockCategory { LIGHT, NORMAL, HEAVY }
const MANA_COST_LIGHT: float = 5.0   # Additional cost on hit (Light attack)
const MANA_COST_NORMAL: float = 15.0  # Additional cost on hit (Normal attack)
const MANA_COST_HEAVY: float = 30.0   # Additional cost on hit (Heavy attack)

# Rewards (unchanged from Commit 004)
const STUN_DURATION: float = 0.8
const TIME_SLOW_SCALE: float = 0.3
const TIME_SLOW_DURATION: float = 0.2
const RESONANCE_GAIN_ON_PARRY: float = 12.5

# Cooldown
const PARRY_COOLDOWN: float = 0.3   # Brief cooldown after perfect parry
const BLOCK_COOLDOWN: float = 0.1   # Very brief after block

# ============================================================================
# REBOUND SYSTEM (Commit 018 - REVISED)
# ============================================================================

# Rebound Parameters
const PARRY_COUNT_REQUIRED: int = 3       # 3 perfect parrys required
const PARRY_TIMEOUT: float = 5.0          # Reset if no parry for 5s

# Healing (REVISED - no longer damage)
const REBOUND_HEAL_PERCENT: float = 0.30  # 30% HP restored

# Resonance Bonus
const NORMAL_PARRY_RESONANCE: float = 12.5  # Same as RESONANCE_GAIN_ON_PARRY
const REBOUND_RESONANCE_BONUS: float = 25.0  # Double normal

# Visual/Audio
const REBOUND_FLASH_DURATION: float = 0.3

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, PARRY_WINDOW, BLOCKING }

var current_state: State = State.IDLE
var cooldown_timer: float = 0.0
var parry_window_timer: float = 0.0  # Timing window für Parry
var mana_drain_timer: float = 0.0    # Timer für interval-based mana drain
var last_mana_warning_time: float = 0.0  # Throttle for "out of mana" message

# Rebound State (Commit 018)
var perfect_parry_count: int = 0
var rebound_ready: bool = false
var last_parry_time: float = 0.0
var parry_timeout_timer: float = 0.0
var rebound_indicator_tween: Tween = null
var rebound_aura: Node = null

# ============================================================================
# REFERENCES
# ============================================================================

var player: CharacterBody2D = null  # Will be set in _ready()

@onready var block_area: Area2D = $BlockArea
@onready var block_collision: CollisionShape2D = $BlockArea/BlockCollision

# Visual indicator
@onready var block_indicator: Polygon2D = $BlockIndicator

# ============================================================================
# SIGNALS
# ============================================================================

signal parry_started  # RMB pressed
signal perfect_parry_executed(enemy: Node)
signal normal_block_executed(enemy: Node)
signal parry_ended    # RMB released

# Rebound Signals (Commit 018)
signal rebound_progress(current: int, required: int)
signal rebound_ready_signal
signal rebound_executed(enemy: Node)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get player reference (via parent CombatSystem)
	var combat_system = get_parent()
	if combat_system:
		player = combat_system.owner as CharacterBody2D
		if not player:
			print("[ParryBlockSystem] WARNING: Could not get player from combat_system.owner")

	# Fallback: Try owner directly
	if not player:
		player = owner as CharacterBody2D

	if not player:
		print("[ParryBlockSystem] ERROR: Could not find player reference!")
	else:
		print("[ParryBlockSystem] Player reference set: %s" % player.name)

	# Setup collision area (only one now)
	_setup_collision_area()

	# Setup visual indicator
	_setup_visual_indicator()

	# Connect area signal (only block area now)
	if block_area.area_entered.connect(_on_block_area_entered) == OK:
		print("[ParryBlockSystem] area_entered signal connected successfully")
	else:
		print("[ParryBlockSystem] ERROR: Failed to connect area_entered signal!")

	# Hide indicator by default
	if block_indicator:
		block_indicator.visible = false

	print("[ParryBlockSystem] Initialized (timing-based parry/block)")
	print("[ParryBlockSystem] BlockArea node: %s" % block_area)
	print("[ParryBlockSystem] BlockCollision node: %s" % block_collision)
	print("[ParryBlockSystem] Initial monitoring: %s" % block_area.monitoring)

func _setup_collision_area() -> void:
	"""Sets up collision shape and position"""

	# Block Area (single sphere for both parry and block)
	if block_collision and block_collision.shape is CircleShape2D:
		block_collision.shape.radius = BLOCK_RADIUS
	block_area.position = BLOCK_OFFSET

	# Collision layers
	block_area.collision_layer = 0
	block_area.collision_mask = 0
	block_area.set_collision_mask_value(6, true)  # P2 Projectiles (Layer 6)
	block_area.set_collision_mask_value(8, true)  # Enemy Hitboxes (Layer 8)
	block_area.set_collision_mask_value(9, true)  # P2 Abilities (Layer 9)

	# Disabled by default
	block_area.monitoring = false

func _setup_visual_indicator() -> void:
	"""Sets up visual circle polygon for block indicator"""

	# Block/Parry Indicator (changes color based on state)
	if block_indicator:
		var block_points = _create_circle_points(BLOCK_RADIUS, 48)
		block_indicator.polygon = block_points
		block_indicator.position = BLOCK_OFFSET
		block_indicator.z_index = 0

func _create_circle_points(radius: float, num_points: int) -> PackedVector2Array:
	"""Creates a circle polygon with given radius and number of points"""
	var points: PackedVector2Array = []
	for i in range(num_points):
		var angle = (i / float(num_points)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	# CRITICAL: Device filtering for co-op support
	# P1: Can use block with keyboard/mouse (or controller when solo)
	# P2: Should NOT use this system (has void_parry instead)

	# Check if this is P2 - if so, don't process block input
	var player = get_parent()
	if player and player.name == "LythrunPlayer":
		return  # P2 doesn't use parry/block system

	# Use InputManager for proper device filtering (COMMIT 022.5)
	if not InputManager:
		return

	# Check for block input (Right-Click or LT)
	if InputManager.is_p1_action_just_pressed("block"):
		_start_blocking()

	if InputManager.is_p1_action_just_released("block"):
		_stop_blocking()

# ============================================================================
# BLOCKING
# ============================================================================

func _start_blocking() -> void:
	"""Starts parry window (RMB pressed)"""

	if current_state != State.IDLE:
		return

	# Check cooldown
	if cooldown_timer > 0.0:
		return

	# Enter PARRY_WINDOW state
	current_state = State.PARRY_WINDOW
	parry_window_timer = PARRY_WINDOW_DURATION

	# Enable collision detection
	block_area.monitoring = true

	# Enable invulnerability immediately
	_set_player_invulnerable(true)

	# Visual feedback (gold pulsing during parry window)
	_show_parry_window_indicators()

	# Emit signal
	parry_started.emit()
	EventBus.parry_started.emit()

func _transition_to_blocking() -> void:
	"""Transitions from parry window to normal blocking"""

	current_state = State.BLOCKING

	# Visual feedback (dim parry ring, show normal block)
	_show_block_indicators()

func _stop_blocking() -> void:
	"""Stops blocking state (RMB released)"""

	if current_state == State.IDLE:
		return

	current_state = State.IDLE

	# Reset mana drain timer
	mana_drain_timer = 0.0

	# Disable collision detection
	block_area.monitoring = false

	# Disable invulnerability
	_set_player_invulnerable(false)

	# Hide visual feedback
	_hide_indicators()

	# Emit signal
	parry_ended.emit()

# ============================================================================
# COLLISION DETECTION
# ============================================================================

func _on_block_area_entered(area: Area2D) -> void:
	"""Called when enemy attack enters block sphere (0-70px)"""

	# Safety check
	if current_state == State.IDLE:
		return

	# Check if enemy hitbox
	if not _is_enemy_hitbox(area):
		return

	# Get target (enemy or projectile)
	var target = area.owner
	if not target:
		return

	# Don't parry/block own hurtbox
	if target == player:
		return

	# ========== PARRY WINDOW ==========
	if current_state == State.PARRY_WINDOW:
		if target.is_in_group("enemies"):
			print("[ParryBlockSystem] PERFECT PARRY on: ", target.name)
			_execute_perfect_parry(target)
			return

		if _is_projectile(target):
			print("[ParryBlockSystem] PROJECTILE PARRIED: ", target.name)
			_parry_projectile(target)
			return

	# ========== NORMAL BLOCK ==========
	elif current_state == State.BLOCKING:
		var category: BlockCategory = BlockCategory.LIGHT
		var mana_cost: float = _get_mana_cost_for_category(category)

		_drain_mana_on_hit(mana_cost)
		_spawn_block_effect()
		AudioManager.play_sfx("combat_block", 0.12)

		normal_block_executed.emit(target)
		EventBus.attack_blocked.emit(target, 1.0)

func _is_enemy_hitbox(area: Area2D) -> bool:
	"""Checks if area is enemy hitbox or P2 projectile/ability"""
	# Check by group
	if area.is_in_group("hitbox"):
		return true
	# Check by name
	if area.name.contains("Hitbox"):
		return true
	# Check by collision layer (NEW: for P2 projectiles/abilities)
	# Layer 6 = P2 Projectiles, Layer 8 = Enemy Hitboxes, Layer 9 = P2 Abilities
	if area.get_collision_layer_value(6):  # P2 Projectiles (Shadow Scythe, etc.)
		return true
	if area.get_collision_layer_value(8):  # Enemy Hitboxes
		return true
	if area.get_collision_layer_value(9):  # P2 Abilities (Void Strike, etc.)
		return true
	return false

func _is_projectile(node: Node) -> bool:
	"""Checks if node is a projectile"""
	if node.is_in_group("projectiles"):
		return true
	if "Projectile" in node.name:
		return true
	if node.get_class() == "Projectile":
		return true
	return false

func _get_mana_cost_for_category(category: BlockCategory) -> float:
	"""Returns mana cost for given attack category"""
	match category:
		BlockCategory.LIGHT:
			return MANA_COST_LIGHT
		BlockCategory.NORMAL:
			return MANA_COST_NORMAL
		BlockCategory.HEAVY:
			return MANA_COST_HEAVY
	return MANA_COST_LIGHT  # Default to light

# ============================================================================
# PERFECT PARRY
# ============================================================================

func _execute_perfect_parry(enemy: Node) -> void:
	"""Executes perfect parry with full rewards"""

	print("[ParryBlockSystem] PERFECT PARRY on ", enemy.name)

	# Stun enemy for 1 second
	if enemy.has_method("stun"):
		enemy.stun(1.0)
		print("[ParryBlockSystem] Enemy stunned for 1.0 seconds!")
	else:
		print("[ParryBlockSystem] WARNING: Enemy has no stun() method")

	# Time slow effect
	GlobalTimeEffects.slow_motion(TIME_SLOW_SCALE, TIME_SLOW_DURATION)

	# Resonance gain (normal parry amount)
	var resonance = player.get_node_or_null("CombatSystem/ResonanceSystem")
	if resonance and resonance.has_method("add_resonance"):
		resonance.add_resonance(RESONANCE_GAIN_ON_PARRY)

	# Spawn parry flash VFX
	_spawn_parry_flash()

	# Audio
	AudioManager.play_sfx("parry", 0.15)

	# Camera shake (reduced from 0.25)
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.1)

	# Hitstop
	GlobalTimeEffects.hit_stop(0.15)

	# ========== REBOUND CHECK (Commit 018) ==========
	# Check if Rebound ready
	if rebound_ready:
		# Execute Rebound Counter
		print("[ParryBlockSystem] REBOUND READY - Executing counter!")
		_execute_rebound_counter(enemy)
	else:
		# Increment counter
		_increment_parry_counter()

	# Set cooldown
	cooldown_timer = PARRY_COOLDOWN

	# Emit signals
	perfect_parry_executed.emit(enemy)
	EventBus.perfect_parry_executed.emit(enemy)

func _parry_projectile(projectile: Node) -> void:
	"""Parries a projectile - destroys it and gives parry rewards"""

	print("[ParryBlockSystem] PROJECTILE PARRIED: ", projectile.name)

	# Destroy projectile
	if projectile.has_method("queue_free"):
		projectile.queue_free()

	# Try to find and stun the shooter
	var shooter = null
	if projectile.has("shooter"):
		shooter = projectile.get("shooter")
	elif projectile.has("owner_enemy"):
		shooter = projectile.get("owner_enemy")

	if shooter and shooter.is_in_group("enemies"):
		print("[ParryBlockSystem] Stunning shooter: ", shooter.name)
		if shooter.has_method("stun"):
			shooter.stun(1.0)  # Stun for 1 second
			print("[ParryBlockSystem] Shooter stunned for 1.0 seconds!")
		else:
			print("[ParryBlockSystem] WARNING: Shooter has no stun() method")

	# Same rewards as perfect parry
	# Time slow effect
	GlobalTimeEffects.slow_motion(TIME_SLOW_SCALE, TIME_SLOW_DURATION)

	# Resonance gain
	var resonance = player.get_node_or_null("CombatSystem/ResonanceSystem")
	if resonance and resonance.has_method("add_resonance"):
		resonance.add_resonance(RESONANCE_GAIN_ON_PARRY)

	# Spawn parry flash VFX
	_spawn_parry_flash()

	# Audio
	AudioManager.play_sfx("parry", 0.15)

	# Camera shake removed (was 0.25 - too much for projectile parry)

	# Hitstop
	GlobalTimeEffects.hit_stop(0.15)

	# Set cooldown
	cooldown_timer = PARRY_COOLDOWN

	# Emit signals (use projectile as target if no shooter found)
	var parry_target = shooter if shooter else projectile
	perfect_parry_executed.emit(parry_target)
	EventBus.perfect_parry_executed.emit(parry_target)

# ============================================================================
# REBOUND COUNTER TRACKING (Commit 018)
# ============================================================================

func _increment_parry_counter() -> void:
	"""Increments perfect parry counter"""

	perfect_parry_count += 1
	last_parry_time = Time.get_ticks_msec() / 1000.0
	parry_timeout_timer = PARRY_TIMEOUT

	print("[ParryBlockSystem] Parry counter: %d/%d" % [perfect_parry_count, PARRY_COUNT_REQUIRED])

	# Emit progress
	rebound_progress.emit(perfect_parry_count, PARRY_COUNT_REQUIRED)
	EventBus.rebound_progress.emit(perfect_parry_count, PARRY_COUNT_REQUIRED)

	# Check if ready
	if perfect_parry_count >= PARRY_COUNT_REQUIRED:
		_activate_rebound_ready()

func _activate_rebound_ready() -> void:
	"""Activates Rebound Ready state"""

	print("[ParryBlockSystem] ========== REBOUND READY! ==========")

	rebound_ready = true

	# Visual indicator
	_show_rebound_indicator()

	# Audio cue
	AudioManager.play_sfx("player_rebound_ready", 0.2)

	# Emit signal
	rebound_ready_signal.emit()
	EventBus.rebound_ready.emit()

func _reset_parry_counter() -> void:
	"""Resets parry counter"""

	if perfect_parry_count > 0:
		print("[ParryBlockSystem] Parry counter reset")

	perfect_parry_count = 0
	rebound_ready = false

	# Hide indicator
	_hide_rebound_indicator()

# ============================================================================
# REBOUND EXECUTION (Commit 018)
# ============================================================================

func _execute_rebound_counter(enemy: Node) -> void:
	"""Executes Rebound heal (REVISED - no longer damage)"""

	print("[ParryBlockSystem] ========== REBOUND HEAL! ==========")

	# Play counter animation (async)
	_play_rebound_animation(enemy)

	# REVISED: Heal player for 30% HP instead of dealing damage
	var health_component = player.get_node_or_null("HealthComponent")
	if health_component and health_component.has_method("heal"):
		var max_hp = health_component.max_health
		var heal_amount = int(max_hp * REBOUND_HEAL_PERCENT)
		health_component.heal(heal_amount)
		print("[ParryBlockSystem] Rebound heal: %d HP (%.0f%% of max)" % [heal_amount, REBOUND_HEAL_PERCENT * 100])
	else:
		print("[ParryBlockSystem] WARNING: HealthComponent not found or has no heal() method")

	# Apply enhanced resonance (ADDITIONAL to normal parry resonance)
	var resonance = player.get_node_or_null("CombatSystem/ResonanceSystem")
	if resonance and resonance.has_method("add_resonance"):
		# Add additional resonance (on top of normal parry gain)
		var additional_resonance = REBOUND_RESONANCE_BONUS - NORMAL_PARRY_RESONANCE
		resonance.add_resonance(additional_resonance)
		print("[ParryBlockSystem] Rebound bonus resonance: +%.1f (total: %.1f)" % [additional_resonance, REBOUND_RESONANCE_BONUS])

	# Spawn special VFX
	_spawn_rebound_flash(enemy)

	# Audio
	AudioManager.play_sfx("combat_rebound_counter", 0.0)

	# Enhanced camera shake (reduced from 0.35)
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.2)

	# Enhanced hitstop
	GlobalTimeEffects.hit_stop(0.2)

	# TESTING: Disabled - only timeout resets counter
	# This allows multiple rebounds without re-charging
	# Reset counter
	# _reset_parry_counter()

	# Emit signal
	rebound_executed.emit(enemy)
	EventBus.rebound_executed.emit(enemy)

func _play_rebound_animation(enemy: Node) -> void:
	"""Plays fast counter-attack animation"""

	if not player or not enemy:
		return

	# Player animation (if available)
	var sprite = player.get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.sprite_frames.has_animation("rebound_counter"):
		sprite.play("rebound_counter")

	# NOTE: Removed player position teleportation (was causing spawn bugs)
	# The visual effects (flash, impact lines, damage) provide enough feedback
	# Moving CharacterBody2D.global_position directly causes physics glitches

# ============================================================================
# COOLDOWN / UPDATE
# ============================================================================

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	# Handle parry window timer
	if current_state == State.PARRY_WINDOW:
		parry_window_timer -= delta

		if parry_window_timer <= 0.0:
			# Parry window expired, transition to normal blocking
			_transition_to_blocking()

	# Handle blocking state - continuous mana drain
	elif current_state == State.BLOCKING:
		# Drain mana continuously (1 per second)
		_drain_mana_continuous(delta)

	# ========== REBOUND TIMEOUT TRACKING (Commit 018) ==========
	if perfect_parry_count > 0 and not rebound_ready:
		parry_timeout_timer -= delta

		if parry_timeout_timer <= 0.0:
			print("[ParryBlockSystem] Parry chain timed out (%.1fs)" % PARRY_TIMEOUT)
			_reset_parry_counter()

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _set_player_invulnerable(invulnerable: bool) -> void:
	"""Sets player invulnerability state"""
	if not player:
		print("[ParryBlockSystem] ERROR: Cannot set invulnerability - player is null!")
		return

	# CRITICAL FIX: Set invulnerability on HURTBOX, not HealthComponent!
	# HurtboxComponent.take_damage() checks its own is_invulnerable
	if not player.has_node("HurtboxComponent"):
		print("[ParryBlockSystem] ERROR: Cannot set invulnerability - HurtboxComponent not found!")
		return

	var hurtbox = player.get_node("HurtboxComponent")

	# Stop the hurtbox's invulnerability timer
	if hurtbox.invulnerability_timer:
		hurtbox.invulnerability_timer.stop()
		print("[ParryBlockSystem] Stopped HurtboxComponent invulnerability_timer")

	hurtbox.is_invulnerable = invulnerable
	print("[ParryBlockSystem] Player invulnerability set to: %s (current value: %s)" % [invulnerable, hurtbox.is_invulnerable])

func _drain_mana_on_hit(cost: float) -> void:
	"""Drains mana when blocking an attack"""
	if not player:
		print("[ParryBlockSystem] ERROR: Cannot drain mana - player is null!")
		return

	if not player.has_node("ManaComponent"):
		print("[ParryBlockSystem] ERROR: Cannot drain mana - ManaComponent not found!")
		return

	var mana = player.get_node("ManaComponent")

	print("[ParryBlockSystem] Draining mana on hit: %.1f (current: %.1f)" % [cost, mana.current_mana])

	# Drain mana
	if mana.current_mana > 0:
		mana.current_mana = max(0, mana.current_mana - cost)
		mana.mana_changed.emit(mana.current_mana, mana.max_mana)
		print("[ParryBlockSystem] Mana after drain: %.1f" % mana.current_mana)
	else:
		# No mana left, but we're invulnerable so no damage taken
		# Just log it
		print("[ParryBlockSystem] Out of mana, block still works (invulnerable) but no mana to drain")

func _drain_mana_continuous(delta: float) -> void:
	"""Drains mana at intervals during blocking (1 mana every 1.5 seconds)"""
	if not player:
		return

	if not player.has_node("ManaComponent"):
		return

	# Update drain timer
	mana_drain_timer += delta

	# Check if interval passed
	if mana_drain_timer >= BLOCK_MANA_DRAIN_INTERVAL:
		mana_drain_timer = 0.0  # Reset timer

		var mana = player.get_node("ManaComponent")

		# Drain mana
		if mana.current_mana > 0:
			var old_mana = mana.current_mana
			mana.current_mana = max(0, mana.current_mana - BLOCK_MANA_DRAIN_AMOUNT)
			mana.mana_changed.emit(mana.current_mana, mana.max_mana)

			print("[ParryBlockSystem] Mana drain: %.1f -> %.1f (every %.1fs)" % [old_mana, mana.current_mana, BLOCK_MANA_DRAIN_INTERVAL])
		else:
			# Out of mana but still blocking (invulnerable)
			print("[ParryBlockSystem] Out of mana, block still works (invulnerable)")

# ============================================================================
# VISUAL INDICATORS
# ============================================================================

func _show_parry_window_indicators() -> void:
	"""Shows indicator during parry window (gold, pulsing)"""

	if block_indicator:
		block_indicator.visible = true
		# Gold color for parry window
		block_indicator.color = Color(1.0, 0.84, 0.0, 0.5)  # Gold

		# Bright pulsing animation during parry window
		var tween = create_tween().set_loops()
		tween.tween_property(block_indicator, "modulate:a", 0.9, 0.15)
		tween.tween_property(block_indicator, "modulate:a", 1.0, 0.15)

func _show_block_indicators() -> void:
	"""Shows visual indicator for normal blocking (blue, dimmer)"""

	if block_indicator:
		block_indicator.visible = true
		# Blue color for normal block
		block_indicator.color = Color(0.3, 0.5, 1.0, 0.3)  # Blue, dimmer

func _hide_indicators() -> void:
	"""Hides visual indicator"""

	if block_indicator:
		block_indicator.visible = false

# ============================================================================
# EFFECTS
# ============================================================================

func _spawn_parry_flash() -> void:
	"""Spawns parry flash VFX"""

	# Check player reference
	if not player:
		print("[ParryBlockSystem] Cannot spawn parry flash - player reference is null")
		return

	# Check if scene exists
	if not ResourceLoader.exists("res://vfx/particles/parry_flash.tscn"):
		print("[ParryBlockSystem] Parry flash VFX not found, skipping")
		return

	var flash_scene = preload("res://vfx/particles/parry_flash.tscn")
	var flash = flash_scene.instantiate()
	get_tree().root.add_child(flash)
	flash.global_position = player.global_position + block_area.position

	# Auto-cleanup
	await get_tree().create_timer(1.0).timeout
	if flash:
		flash.queue_free()

func _spawn_block_effect() -> void:
	"""Spawns block effect (smaller, different from parry)"""

	# Check player reference
	if not player:
		print("[ParryBlockSystem] Cannot spawn block effect - player reference is null")
		return

	# Check if scene exists
	if not ResourceLoader.exists("res://vfx/particles/block_effect.tscn"):
		print("[ParryBlockSystem] Block effect VFX not found, skipping")
		return

	var block_scene = preload("res://vfx/particles/block_effect.tscn")
	var effect = block_scene.instantiate()
	get_tree().root.add_child(effect)
	effect.global_position = player.global_position

	# Auto-cleanup
	await get_tree().create_timer(0.5).timeout
	if effect:
		effect.queue_free()

# ============================================================================
# REBOUND VISUAL INDICATORS (Commit 018)
# ============================================================================

func _show_rebound_indicator() -> void:
	"""Shows visual indicator that Rebound is ready"""

	if not player:
		return

	# Player glow (golden)
	var sprite = player.get_node_or_null("AnimatedSprite2D")
	if not sprite:
		sprite = player.get_node_or_null("Sprite2D")

	if sprite:
		rebound_indicator_tween = create_tween().set_loops()
		rebound_indicator_tween.tween_property(sprite, "modulate", Color(1.5, 1.3, 0.5), 0.4)
		rebound_indicator_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.4)

	# Spawn aura particles (if scene exists)
	if ResourceLoader.exists("res://vfx/particles/rebound_aura.tscn"):
		var aura_scene = preload("res://vfx/particles/rebound_aura.tscn")
		rebound_aura = aura_scene.instantiate()
		player.add_child(rebound_aura)
		rebound_aura.emitting = true

func _hide_rebound_indicator() -> void:
	"""Hides Rebound Ready indicator"""

	if not player:
		return

	# Stop glow
	if rebound_indicator_tween:
		rebound_indicator_tween.kill()
		rebound_indicator_tween = null

	# Remove aura
	if rebound_aura:
		rebound_aura.queue_free()
		rebound_aura = null

	# Reset sprite color
	var sprite = player.get_node_or_null("AnimatedSprite2D")
	if not sprite:
		sprite = player.get_node_or_null("Sprite2D")

	if sprite:
		sprite.modulate = Color.WHITE

func _spawn_rebound_flash(enemy: Node) -> void:
	"""Spawns enhanced flash VFX for Rebound"""

	# CRITICAL: Safety check for freed objects
	if not is_instance_valid(enemy):
		return

	# Store position before any async operations
	var enemy_pos = enemy.global_position

	# Enhanced parry flash (golden)
	if ResourceLoader.exists("res://vfx/particles/rebound_flash.tscn"):
		var flash_scene = preload("res://vfx/particles/rebound_flash.tscn")
		var flash = flash_scene.instantiate()
		get_tree().root.add_child(flash)
		flash.global_position = enemy_pos  # Use stored position
		flash.emitting = true

		# Auto-cleanup
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(flash):
			flash.queue_free()

	# Impact lines (speed effect)
	if ResourceLoader.exists("res://vfx/particles/rebound_impact_lines.tscn"):
		var lines_scene = preload("res://vfx/particles/rebound_impact_lines.tscn")
		var lines = lines_scene.instantiate()
		get_tree().root.add_child(lines)
		lines.global_position = enemy_pos  # Use stored position
		lines.emitting = true

		# Auto-cleanup
		await get_tree().create_timer(0.5).timeout
		if lines:
			lines.queue_free()

# ============================================================================
# DAMAGE NOTIFICATION (Commit 018)
# ============================================================================

func _on_player_damaged(_amount: int, _attacker: Node) -> void:
	"""Called when player takes damage - resets parry counter"""
	# TESTING: Disabled - only timeout resets counter
	# This allows maintaining counter even after taking damage
	print("[ParryBlockSystem] Player took damage (counter NOT reset for testing)")
	# _reset_parry_counter()

# ============================================================================
# UTILITY
# ============================================================================

func is_blocking() -> bool:
	"""Returns true if currently blocking"""
	return current_state == State.BLOCKING

func can_parry() -> bool:
	"""Returns true if can start blocking"""
	return current_state == State.IDLE and cooldown_timer <= 0.0
