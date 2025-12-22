extends Node2D
class_name ParryBlockSystem

## Timing + Spatial Parry/Block system
## - Block: Hold RMB = invulnerable + mana drain
## - Parry: Press RMB timing window + enemy in parry ring (50-70px)

# ============================================================================
# CONSTANTS
# ============================================================================

# Block (innere sphere)
const BLOCK_RADIUS: float = 50.0
const BLOCK_OFFSET: Vector2 = Vector2.ZERO  # Centered on player

# Parry (äußere sphere - parry ring ist zwischen 50-70px)
const PARRY_RADIUS: float = 70.0
const PARRY_OFFSET: Vector2 = Vector2.ZERO  # Auch zentriert, konzentrisch

# Parry Timing
const PARRY_WINDOW_DURATION: float = 60.0  # 60s timing window für Testing

# Block Mana Cost
const BLOCK_MANA_PER_SECOND: float = 10.0  # 10 Mana pro Sekunde

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

@onready var player: CharacterBody2D = owner

@onready var block_area: Area2D = $BlockArea
@onready var block_collision: CollisionShape2D = $BlockArea/BlockCollision

@onready var parry_area: Area2D = $ParryArea
@onready var parry_collision: CollisionShape2D = $ParryArea/ParryCollision

# Visual indicators (optional, für debug)
@onready var parry_indicator: Polygon2D = $ParryIndicator
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
	# Setup collision areas
	_setup_collision_areas()

	# Setup visual indicators
	_setup_visual_indicators()

	# Connect area signals
	parry_area.area_entered.connect(_on_parry_area_entered)
	block_area.area_entered.connect(_on_block_area_entered)

	# Hide indicators by default
	if parry_indicator:
		parry_indicator.visible = false
	if block_indicator:
		block_indicator.visible = false

	print("[ParryBlockSystem] Initialized (spatial detection)")

func _setup_collision_areas() -> void:
	"""Sets up collision shapes and positions"""

	# Block Area (größer, centered)
	if block_collision and block_collision.shape is CircleShape2D:
		block_collision.shape.radius = BLOCK_RADIUS
	block_area.position = BLOCK_OFFSET

	# Parry Area (kleiner, offset forward)
	if parry_collision and parry_collision.shape is CircleShape2D:
		parry_collision.shape.radius = PARRY_RADIUS
	parry_area.position = PARRY_OFFSET

	# Collision layers
	block_area.collision_layer = 0
	block_area.collision_mask = 4  # Enemy hitbox layer

	parry_area.collision_layer = 0
	parry_area.collision_mask = 4

	# Parry higher priority (disable/enable logic)
	block_area.monitoring = false
	parry_area.monitoring = false

func _setup_visual_indicators() -> void:
	"""Sets up visual circle polygons for indicators"""

	# Block Indicator (Blue, 50% transparent, 50px radius)
	if block_indicator:
		var block_points = _create_circle_points(BLOCK_RADIUS, 48)
		block_indicator.polygon = block_points
		block_indicator.color = Color(0.3, 0.6, 1.0, 0.5)  # Blue, 50% alpha
		block_indicator.position = BLOCK_OFFSET  # Match block area position
		block_indicator.z_index = -1  # Behind player

	# Parry Indicator (Gold, 45px radius)
	if parry_indicator:
		var parry_points = _create_circle_points(PARRY_RADIUS, 48)
		parry_indicator.polygon = parry_points
		parry_indicator.color = Color(1.0, 0.84, 0.0, 0.6)  # Gold, 60% alpha
		parry_indicator.position = PARRY_OFFSET  # Match parry area position
		parry_indicator.z_index = 0  # Above block

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

	# Enable collision detection (both areas for detection)
	parry_area.monitoring = true
	block_area.monitoring = true

	# Enable invulnerability immediately
	_set_player_invulnerable(true)

	# Visual feedback (make parry ring glow brighter during window)
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
	parry_area.monitoring = false
	block_area.monitoring = false

	# Disable invulnerability
	_set_player_invulnerable(false)

	# Hide visual feedback
	_hide_block_indicators()

	# Emit signal
	parry_ended.emit()

# ============================================================================
# COLLISION DETECTION
# ============================================================================

func _on_parry_area_entered(area: Area2D) -> void:
	"""Called when enemy attack enters PARRY area (outer ring 50-70px)"""

	print("[ParryBlockSystem] Parry area entered: %s (owner: %s)" % [area.name, area.owner.name if area.owner else "null"])

	# Only process during parry window for perfect parry
	if current_state != State.PARRY_WINDOW:
		print("[ParryBlockSystem] Not in parry window, ignoring for parry")
		return

	# Check if enemy hitbox
	if not _is_enemy_hitbox(area):
		print("[ParryBlockSystem] Not enemy hitbox, ignoring")
		return

	# Check if ALSO in block area (too close for parry)
	if _is_in_block_area(area):
		print("[ParryBlockSystem] Also in block area (too close), no parry")
		return

	# Get target (enemy or projectile)
	var target = area.owner
	if not target:
		print("[ParryBlockSystem] No owner, ignoring")
		return

	# PERFECT PARRY! Target is in parry ring (50-70px) during timing window
	# Check if it's an enemy directly
	if target.is_in_group("enemies"):
		print("[ParryBlockSystem] *** PERFECT PARRY *** on enemy: %s (in parry ring during window)" % target.name)
		_execute_perfect_parry(target)
		return

	# Check if it's a projectile - we can parry projectiles!
	if _is_projectile(target):
		print("[ParryBlockSystem] *** PERFECT PARRY *** on projectile: %s" % target.name)
		_parry_projectile(target)
		return

	print("[ParryBlockSystem] Owner not enemy or projectile, ignoring")

func _on_block_area_entered(area: Area2D) -> void:
	"""Called when enemy attack enters BLOCK area (inner sphere 0-50px)"""

	# Player is invulnerable during blocking, so attacks are automatically blocked
	# We just need to log it and provide feedback

	if current_state == State.IDLE:
		return  # Not blocking, shouldn't happen but safety check

	# Check if enemy hitbox
	if not _is_enemy_hitbox(area):
		return

	var target = area.owner
	if not target:
		return

	# Log blocked attack (player is invulnerable, no damage taken)
	print("[ParryBlockSystem] Attack blocked (player invulnerable) from: %s" % target.name)

	# Spawn block VFX for feedback
	_spawn_block_effect()

	# Audio feedback
	AudioManager.play_sfx("combat_block", 0.12)

func _is_enemy_hitbox(area: Area2D) -> bool:
	"""Checks if area is enemy hitbox"""
	return area.is_in_group("hitbox") or area.name.contains("Hitbox")

func _is_in_parry_area(area: Area2D) -> bool:
	"""Checks if area overlaps parry zone"""
	return parry_area.overlaps_area(area)

func _is_in_block_area(area: Area2D) -> bool:
	"""Checks if area overlaps block zone"""
	return block_area.overlaps_area(area)

func _is_projectile(node: Node) -> bool:
	"""Checks if node is a projectile"""
	if node.is_in_group("projectiles"):
		return true
	if "Projectile" in node.name:
		return true
	if node.get_class() == "Projectile":
		return true
	return false

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

	# Drain mana during blocking
	if current_state == State.BLOCKING:
		_drain_mana(delta)

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

func _drain_mana(delta: float) -> void:
	"""Drains mana during blocking"""
	if not player:
		print("[ParryBlockSystem] ERROR: Cannot drain mana - player is null!")
		return

	if not player.has_node("ManaComponent"):
		print("[ParryBlockSystem] ERROR: Cannot drain mana - ManaComponent not found!")
		return

	var mana = player.get_node("ManaComponent")
	var drain_amount = BLOCK_MANA_PER_SECOND * delta

	print("[ParryBlockSystem] Draining mana: %.2f (current: %.1f)" % [drain_amount, mana.current_mana])

	# Try to drain mana
	if mana.current_mana > 0:
		mana.current_mana = max(0, mana.current_mana - drain_amount)
		mana.mana_changed.emit(mana.current_mana, mana.max_mana)
		print("[ParryBlockSystem] Mana after drain: %.1f" % mana.current_mana)
	else:
		# Out of mana, force stop blocking
		print("[ParryBlockSystem] Out of mana, stopping block")
		_stop_blocking()

# ============================================================================
# VISUAL INDICATORS
# ============================================================================

func _show_parry_window_indicators() -> void:
	"""Shows indicators during parry window (brighter, pulsing)"""

	if block_indicator:
		block_indicator.visible = true

	if parry_indicator:
		parry_indicator.visible = true
		# Bright pulsing animation during parry window
		var tween = create_tween().set_loops()
		tween.tween_property(parry_indicator, "modulate:a", 0.9, 0.1)
		tween.tween_property(parry_indicator, "modulate:a", 1.0, 0.1)

func _show_block_indicators() -> void:
	"""Shows visual indicators for normal blocking (dimmer)"""

	if block_indicator:
		block_indicator.visible = true

	if parry_indicator:
		parry_indicator.visible = true
		parry_indicator.modulate.a = 0.4  # Dimmer during normal block

func _hide_block_indicators() -> void:
	"""Hides visual indicators"""

	if block_indicator:
		block_indicator.visible = false

	if parry_indicator:
		parry_indicator.visible = false

# ============================================================================
# EFFECTS
# ============================================================================

func _spawn_parry_flash() -> void:
	"""Spawns parry flash VFX (same as Commit 004)"""

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
	flash.global_position = player.global_position + parry_area.position

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
