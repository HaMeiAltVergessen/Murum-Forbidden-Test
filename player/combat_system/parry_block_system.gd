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

	# Only process during blocking
	if current_state != State.BLOCKING:
		return

	# Check if enemy hitbox
	if not _is_enemy_hitbox(area):
		return

	# Get enemy
	var enemy = area.owner
	if not enemy or not enemy.is_in_group("enemies"):
		return

	# PERFECT PARRY!
	_execute_perfect_parry(enemy)

func _on_block_area_entered(area: Area2D) -> void:
	"""Called when enemy attack enters BLOCK area (but not parry)"""

	# Only process during blocking
	if current_state != State.BLOCKING:
		return

	# Check if enemy hitbox
	if not _is_enemy_hitbox(area):
		return

	# Check if attack is ALSO in parry area (priority check)
	if _is_in_parry_area(area):
		# Will be handled by parry detection
		return

	# Get enemy
	var enemy = area.owner
	if not enemy or not enemy.is_in_group("enemies"):
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

	# Apply stun to enemy
	if enemy.has_method("stun"):
		enemy.stun(STUN_DURATION)

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
		block_indicator.modulate = Color(0.5, 0.5, 1.0, 0.3)  # Blue, transparent

	if parry_indicator:
		parry_indicator.visible = true
		parry_indicator.modulate = Color(1.0, 1.0, 0.5, 0.5)  # Yellow, semi-transparent

		# Pulse animation
		var tween = create_tween().set_loops()
		tween.tween_property(parry_indicator, "modulate:a", 0.3, 0.3)
		tween.tween_property(parry_indicator, "modulate:a", 0.6, 0.3)

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
