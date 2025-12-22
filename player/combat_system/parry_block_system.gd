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
const PARRY_WINDOW_DURATION: float = 1.0  # 1 second timing window für Parry

# Block Mana Cost Categories (only on hit, not continuous)
enum BlockCategory { LIGHT, NORMAL, HEAVY }
const MANA_COST_LIGHT: float = 5.0
const MANA_COST_NORMAL: float = 15.0
const MANA_COST_HEAVY: float = 30.0

# Rewards (unchanged from Commit 004)
const STUN_DURATION: float = 0.8
const TIME_SLOW_SCALE: float = 0.3
const TIME_SLOW_DURATION: float = 0.2
const RESONANCE_GAIN_ON_PARRY: float = 12.5

# Cooldown
const PARRY_COOLDOWN: float = 0.3   # Brief cooldown after perfect parry
const BLOCK_COOLDOWN: float = 0.1   # Very brief after block

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, PARRY_WINDOW, BLOCKING }

var current_state: State = State.IDLE
var cooldown_timer: float = 0.0
var parry_window_timer: float = 0.0  # Timing window für Parry

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
	block_area.area_entered.connect(_on_block_area_entered)

	# Hide indicator by default
	if block_indicator:
		block_indicator.visible = false

	print("[ParryBlockSystem] Initialized (timing-based parry/block)")

func _setup_collision_area() -> void:
	"""Sets up collision shape and position"""

	# Block Area (single sphere for both parry and block)
	if block_collision and block_collision.shape is CircleShape2D:
		block_collision.shape.radius = BLOCK_RADIUS
	block_area.position = BLOCK_OFFSET

	# Collision layers
	block_area.collision_layer = 0
	block_area.collision_mask = 4  # Enemy hitbox layer

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
	if event.is_action_pressed("block"):
		_start_blocking()

	if event.is_action_released("block"):
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
		print("[ParryBlockSystem] Cooldown active, cannot block")
		return

	print("[ParryBlockSystem] Parry window started (%.2fs)" % PARRY_WINDOW_DURATION)

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

	print("[ParryBlockSystem] Parry window expired, now blocking")

	current_state = State.BLOCKING

	# Visual feedback (dim parry ring, show normal block)
	_show_block_indicators()

func _stop_blocking() -> void:
	"""Stops blocking state (RMB released)"""

	if current_state == State.IDLE:
		return

	print("[ParryBlockSystem] Blocking ended")

	current_state = State.IDLE

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

	print("[ParryBlockSystem] Block area entered: %s (state: %s)" % [area.name, "PARRY_WINDOW" if current_state == State.PARRY_WINDOW else "BLOCKING"])

	# Safety check
	if current_state == State.IDLE:
		return

	# Check if enemy hitbox
	if not _is_enemy_hitbox(area):
		print("[ParryBlockSystem] Not enemy hitbox, ignoring")
		return

	# Get target (enemy or projectile)
	var target = area.owner
	if not target:
		print("[ParryBlockSystem] No owner, ignoring")
		return

	# ========== PARRY WINDOW (first 1 second after RMB press) ==========
	if current_state == State.PARRY_WINDOW:
		# Perfect Parry!

		# Check if it's an enemy
		if target.is_in_group("enemies"):
			print("[ParryBlockSystem] *** PERFECT PARRY *** on enemy: %s (within timing window)" % target.name)
			_execute_perfect_parry(target)
			return

		# Check if it's a projectile
		if _is_projectile(target):
			print("[ParryBlockSystem] *** PERFECT PARRY *** on projectile: %s" % target.name)
			_parry_projectile(target)
			return

	# ========== NORMAL BLOCK (after 1 second) ==========
	elif current_state == State.BLOCKING:
		# Normal block - drain mana based on attack category

		# Determine attack category (currently all enemies do Light damage)
		var category: BlockCategory = BlockCategory.LIGHT

		# Get mana cost for this category
		var mana_cost: float = _get_mana_cost_for_category(category)

		print("[ParryBlockSystem] Normal block against %s (Category: %s, Mana cost: %.1f)" % [target.name, "LIGHT", mana_cost])

		# Drain mana
		_drain_mana_on_hit(mana_cost)

		# Spawn block VFX for feedback
		_spawn_block_effect()

		# Audio feedback
		AudioManager.play_sfx("combat_block", 0.12)

		# Emit signal
		normal_block_executed.emit(target)
		EventBus.attack_blocked.emit(target, 1.0)  # 100% damage reduction (invulnerable)

func _is_enemy_hitbox(area: Area2D) -> bool:
	"""Checks if area is enemy hitbox"""
	return area.is_in_group("hitbox") or area.name.contains("Hitbox")

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

	print("[ParryBlockSystem] PERFECT PARRY on %s" % enemy.name)

	# TESTING: Kill enemy instantly on perfect parry
	if enemy.has_method("die"):
		enemy.die()
	elif enemy.has_method("take_damage"):
		enemy.take_damage(999999, player)  # Massive damage to ensure death
	elif enemy.has_method("queue_free"):
		enemy.queue_free()

	print("[ParryBlockSystem] Enemy killed by perfect parry!")

	# Time slow effect
	GlobalTimeEffects.slow_motion(TIME_SLOW_SCALE, TIME_SLOW_DURATION)

	# Resonance gain
	var resonance = player.get_node_or_null("CombatSystem/ResonanceSystem")
	if resonance and resonance.has_method("add_resonance"):
		resonance.add_resonance(RESONANCE_GAIN_ON_PARRY)

	# Spawn parry flash VFX
	_spawn_parry_flash()

	# Audio
	AudioManager.play_sfx("player_parry_success", 0.15)

	# Camera shake
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.25)

	# Hitstop
	GlobalTimeEffects.hit_stop(0.15)

	# Set cooldown
	cooldown_timer = PARRY_COOLDOWN

	# Emit signals
	perfect_parry_executed.emit(enemy)
	EventBus.perfect_parry_executed.emit(enemy)

func _parry_projectile(projectile: Node) -> void:
	"""Parries a projectile - destroys it and gives parry rewards"""

	print("[ParryBlockSystem] PROJECTILE PARRIED: %s" % projectile.name)

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
		print("[ParryBlockSystem] Stunning shooter: %s" % shooter.name)
		if shooter.has_method("die"):
			shooter.die()  # TESTING: Kill shooter
		elif shooter.has_method("stun"):
			shooter.stun(STUN_DURATION)

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
	AudioManager.play_sfx("player_parry_success", 0.15)

	# Camera shake
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.25)

	# Hitstop
	GlobalTimeEffects.hit_stop(0.15)

	# Set cooldown
	cooldown_timer = PARRY_COOLDOWN

	# Emit signals (use projectile as target if no shooter found)
	var parry_target = shooter if shooter else projectile
	perfect_parry_executed.emit(parry_target)
	EventBus.perfect_parry_executed.emit(parry_target)

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

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _set_player_invulnerable(invulnerable: bool) -> void:
	"""Sets player invulnerability state"""
	if not player:
		print("[ParryBlockSystem] ERROR: Cannot set invulnerability - player is null!")
		return

	if not player.has_node("HealthComponent"):
		print("[ParryBlockSystem] ERROR: Cannot set invulnerability - HealthComponent not found!")
		return

	var health = player.get_node("HealthComponent")
	health.is_invulnerable = invulnerable
	print("[ParryBlockSystem] Player invulnerability set to: %s (current value: %s)" % [invulnerable, health.is_invulnerable])

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
# UTILITY
# ============================================================================

func is_blocking() -> bool:
	"""Returns true if currently blocking"""
	return current_state == State.BLOCKING

func can_parry() -> bool:
	"""Returns true if can start blocking"""
	return current_state == State.IDLE and cooldown_timer <= 0.0
