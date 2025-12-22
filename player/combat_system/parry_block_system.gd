extends Node2D
class_name ParryBlockSystem

## Spatial-based Parry/Block system with two collision areas

# ============================================================================
# CONSTANTS
# ============================================================================

# Block (größere sphere)
const BLOCK_RADIUS: float = 50.0
const BLOCK_OFFSET: Vector2 = Vector2.ZERO  # Centered on player

# Parry (kleinerer ring, vor player)
const PARRY_RADIUS: float = 45.0
const PARRY_OFFSET: Vector2 = Vector2(15.0, 0)  # 15px forward from player center

# Rewards (unchanged from Commit 004)
const STUN_DURATION: float = 0.8
const TIME_SLOW_SCALE: float = 0.3
const TIME_SLOW_DURATION: float = 0.2
const RESONANCE_GAIN_ON_PARRY: float = 12.5

# Block Mitigation
const BLOCK_DAMAGE_REDUCTION: float = 0.7  # 70% damage reduction

# Cooldown
const PARRY_COOLDOWN: float = 0.3   # Brief cooldown after perfect parry
const BLOCK_COOLDOWN: float = 0.1   # Very brief after block

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, BLOCKING }

var current_state: State = State.IDLE
var cooldown_timer: float = 0.0

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
	"""Starts blocking state (RMB pressed)"""

	if current_state == State.BLOCKING:
		return

	# Check cooldown
	if cooldown_timer > 0.0:
		print("[ParryBlockSystem] Cooldown active, cannot block")
		return

	print("[ParryBlockSystem] Blocking started")

	current_state = State.BLOCKING

	# Enable collision detection
	parry_area.monitoring = true
	block_area.monitoring = true

	# Visual feedback
	_show_block_indicators()

	# Emit signal
	parry_started.emit()
	EventBus.parry_started.emit()

func _stop_blocking() -> void:
	"""Stops blocking state (RMB released)"""

	if current_state != State.BLOCKING:
		return

	print("[ParryBlockSystem] Blocking ended")

	current_state = State.IDLE

	# Disable collision detection
	parry_area.monitoring = false
	block_area.monitoring = false

	# Hide visual feedback
	_hide_block_indicators()

	# Emit signal
	parry_ended.emit()

# ============================================================================
# COLLISION DETECTION
# ============================================================================

func _on_parry_area_entered(area: Area2D) -> void:
	"""Called when enemy attack enters PARRY area"""

	print("[ParryBlockSystem] Parry area entered: %s (owner: %s)" % [area.name, area.owner.name if area.owner else "null"])

	# Only process during blocking
	if current_state != State.BLOCKING:
		print("[ParryBlockSystem] Not blocking, ignoring")
		return

	# Check if enemy hitbox
	if not _is_enemy_hitbox(area):
		print("[ParryBlockSystem] Not enemy hitbox, ignoring")
		return

	# Get enemy
	var enemy = area.owner
	if not enemy:
		print("[ParryBlockSystem] No owner, ignoring")
		return

	if not enemy.is_in_group("enemies"):
		print("[ParryBlockSystem] Owner not in 'enemies' group, ignoring")
		return

	# PERFECT PARRY!
	_execute_perfect_parry(enemy)

func _on_block_area_entered(area: Area2D) -> void:
	"""Called when enemy attack enters BLOCK area (but not parry)"""

	print("[ParryBlockSystem] Block area entered: %s (owner: %s)" % [area.name, area.owner.name if area.owner else "null"])

	# Only process during blocking
	if current_state != State.BLOCKING:
		print("[ParryBlockSystem] Not blocking, ignoring")
		return

	# Check if enemy hitbox
	if not _is_enemy_hitbox(area):
		print("[ParryBlockSystem] Not enemy hitbox, ignoring")
		return

	# Check if attack is ALSO in parry area (priority check)
	if _is_in_parry_area(area):
		print("[ParryBlockSystem] Also in parry area, will be handled by parry")
		return

	# Get enemy
	var enemy = area.owner
	if not enemy:
		print("[ParryBlockSystem] No owner, ignoring")
		return

	if not enemy.is_in_group("enemies"):
		print("[ParryBlockSystem] Owner not in 'enemies' group, ignoring")
		return

	# NORMAL BLOCK
	_execute_normal_block(enemy)

func _is_enemy_hitbox(area: Area2D) -> bool:
	"""Checks if area is enemy hitbox"""
	return area.is_in_group("hitbox") or area.name.contains("Hitbox")

func _is_in_parry_area(area: Area2D) -> bool:
	"""Checks if area overlaps parry zone"""
	return parry_area.overlaps_area(area)

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

# ============================================================================
# NORMAL BLOCK
# ============================================================================

func _execute_normal_block(enemy: Node) -> void:
	"""Executes normal block (damage reduction, no rewards)"""

	print("[ParryBlockSystem] NORMAL BLOCK on %s" % enemy.name)

	# Damage mitigation (handled in damage calculation)
	# Signal to indicate block active
	EventBus.attack_blocked.emit(enemy, BLOCK_DAMAGE_REDUCTION)

	# Spawn block effect (smaller than parry)
	_spawn_block_effect()

	# Audio (different from parry)
	AudioManager.play_sfx("combat_block", 0.12)

	# Brief hitstop (shorter than parry)
	GlobalTimeEffects.hit_stop(0.05)

	# Set cooldown (shorter than parry)
	cooldown_timer = BLOCK_COOLDOWN

	# Emit signal
	normal_block_executed.emit(enemy)

# ============================================================================
# COOLDOWN
# ============================================================================

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

# ============================================================================
# VISUAL INDICATORS
# ============================================================================

func _show_block_indicators() -> void:
	"""Shows visual indicators for block/parry areas"""

	if block_indicator:
		block_indicator.visible = true

	if parry_indicator:
		parry_indicator.visible = true

		# Pulse animation on parry indicator
		var tween = create_tween().set_loops()
		tween.tween_property(parry_indicator, "modulate:a", 0.4, 0.3)
		tween.tween_property(parry_indicator, "modulate:a", 0.8, 0.3)

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
