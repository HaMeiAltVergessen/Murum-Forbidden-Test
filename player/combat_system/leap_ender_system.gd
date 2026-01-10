extends Node
class_name LeapEnderSystem

## Handles Leap Ender alternative combo finisher
## Alternative to normal finisher - trades damage for knockback and positioning

# ============================================================================
# CONSTANTS
# ============================================================================

const LEAP_DAMAGE_MULTIPLIER: float = 1.3
const LEAP_KNOCKBACK_FORCE: float = 400.0
const LEAP_KNOCKBACK_DURATION: float = 0.4

const LEAP_WIND_UP_DURATION: float = 0.3
const LEAP_DURATION: float = 0.2
const LEAP_RECOVERY_DURATION: float = 0.2
const LEAP_DISTANCE: float = 100.0
const LEAP_SPEED: float = 500.0

const LEAP_AOE_RADIUS: float = 50.0

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, WIND_UP, LEAPING, RECOVERY }

var current_state: State = State.IDLE
var state_timer: float = 0.0

var leap_direction: Vector2 = Vector2.ZERO
var leap_start_position: Vector2 = Vector2.ZERO

# ============================================================================
# REFERENCES
# ============================================================================

@onready var player: CharacterBody2D = owner
@onready var combo_tracker: ComboTracker = null
@onready var combat_system: CombatSystem = null
@onready var hitbox: Area2D = null

# ============================================================================
# SIGNALS
# ============================================================================

signal leap_ender_started(direction: Vector2)
signal leap_ender_hit(enemies: Array)
signal leap_ender_completed

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get references (will be set after combat system creates all children)
	call_deferred("_setup_references")

func _setup_references() -> void:
	"""Sets up references to other combat components"""
	# Get parent combat system
	combat_system = get_parent() as CombatSystem

	if combat_system:
		combo_tracker = combat_system.get_node_or_null("ComboTracker")
		hitbox = combat_system.get_node_or_null("HitboxComponent")

		# Get player reference from combat system's owner
		player = combat_system.owner as CharacterBody2D

		if not player:
			print("[LeapEnderSystem] WARNING: Could not get player from combat_system.owner")

	# Fallback: Try owner directly
	if not player:
		player = owner as CharacterBody2D

	if not player:
		print("[LeapEnderSystem] ERROR: Could not find player reference!")
	else:
		print("[LeapEnderSystem] Player reference set: %s" % player.name)

	# Connect to combo tracker
	if combo_tracker:
		combo_tracker.leap_ender_available.connect(_on_leap_available)

	print("[LeapEnderSystem] Initialized")

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	# COMMIT 023: Use InputManager for proper P1/P2 distinction
	var attack_pressed = false
	if InputManager:
		var is_p2 = player.is_in_group("player2") or player.name == "Lythrun"
		if is_p2:
			attack_pressed = event.is_action_pressed("p2_attack")
		else:
			attack_pressed = event.is_action_pressed("p1_attack")

	if attack_pressed:
		_try_trigger_leap_ender()

func _try_trigger_leap_ender() -> void:
	"""Attempts to trigger leap ender"""

	if current_state != State.IDLE:
		return

	if not combo_tracker or not combo_tracker.check_leap_ender_input():
		return

	# Execute leap ender
	_start_leap_ender()

# ============================================================================
# LEAP EXECUTION
# ============================================================================

func _start_leap_ender() -> void:
	"""Starts leap ender sequence"""

	print("[LeapEnderSystem] Executing leap ender")

	# Ensure player reference is valid
	if not player:
		player = owner as CharacterBody2D

	if not player:
		print("[LeapEnderSystem] ERROR: Player reference is null!")
		return

	# Get direction from combo tracker
	leap_direction = combo_tracker.consume_leap_ender()
	leap_start_position = player.global_position

	# Enter wind-up
	current_state = State.WIND_UP
	state_timer = LEAP_WIND_UP_DURATION

	# Lock combat during leap
	if combat_system and combat_system.has_method("set_combat_enabled"):
		combat_system.set_combat_enabled(false)

	# Play wind-up animation
	_play_wind_up_animation()

	# Emit signal
	leap_ender_started.emit(leap_direction)
	EventBus.leap_ender_started.emit(leap_direction)

func _play_wind_up_animation() -> void:
	"""Plays wind-up animation"""

	# Ensure player reference
	if not player:
		return

	# Visual: Pull back sprite
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite:
		var pull_direction = -leap_direction.x if abs(leap_direction.x) > 0.1 else 0
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "position:x", pull_direction * 10, LEAP_WIND_UP_DURATION * 0.6)
		tween.tween_property(sprite, "scale", Vector2(1.2, 0.9), LEAP_WIND_UP_DURATION * 0.6)

	# Audio (charge-up sound)
	AudioManager.play_sfx("player_leap_windup", 0.1)

# ============================================================================
# STATE MACHINE
# ============================================================================

func _physics_process(delta: float) -> void:
	match current_state:
		State.WIND_UP:
			_process_wind_up(delta)
		State.LEAPING:
			_process_leaping(delta)
		State.RECOVERY:
			_process_recovery(delta)

func _process_wind_up(delta: float) -> void:
	"""Processes wind-up phase (vulnerable)"""

	state_timer -= delta

	# Ensure player reference
	if not player:
		player = owner as CharacterBody2D

	if player:
		# Lock movement during wind-up
		player.velocity = Vector2.ZERO

	if state_timer <= 0.0:
		_enter_leap()

func _process_leaping(delta: float) -> void:
	"""Processes leap phase (attack active)"""

	state_timer -= delta

	# Ensure player reference
	if not player:
		player = owner as CharacterBody2D

	if player:
		# Move forward
		player.velocity = leap_direction * LEAP_SPEED
		player.move_and_slide()

	# Check for hits (continuous during leap)
	_check_leap_hits()

	if state_timer <= 0.0:
		_enter_recovery()

func _process_recovery(delta: float) -> void:
	"""Processes landing recovery"""

	state_timer -= delta

	# Ensure player reference
	if not player:
		player = owner as CharacterBody2D

	if player:
		# Slow down
		var slow_factor = state_timer / LEAP_RECOVERY_DURATION
		player.velocity = leap_direction * LEAP_SPEED * slow_factor * 0.3
		player.move_and_slide()

	if state_timer <= 0.0:
		_complete_leap()

# ============================================================================
# STATE TRANSITIONS
# ============================================================================

func _enter_leap() -> void:
	"""Enters leap phase"""

	current_state = State.LEAPING
	state_timer = LEAP_DURATION

	# Activate hitbox
	if hitbox:
		hitbox.monitoring = true
		hitbox.visible = true
		if hitbox.has_method("set_damage"):
			hitbox.set_damage(_calculate_leap_damage())

	# Play leap animation
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		# Lunge forward
		tween.tween_property(sprite, "position:x", leap_direction.x * 15, LEAP_DURATION)
		# Normal scale
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), LEAP_DURATION * 0.3)

	# Audio (whoosh)
	AudioManager.play_sfx("player_leap_attack", 0.15)

	print("[LeapEnderSystem] Leaping!")

func _enter_recovery() -> void:
	"""Enters recovery phase"""

	current_state = State.RECOVERY
	state_timer = LEAP_RECOVERY_DURATION

	# Deactivate hitbox
	if hitbox:
		hitbox.monitoring = false
		hitbox.visible = false

	print("[LeapEnderSystem] Recovery")

func _complete_leap() -> void:
	"""Completes leap ender"""

	current_state = State.IDLE
	player.velocity = Vector2.ZERO

	# Unlock combat
	if combat_system and combat_system.has_method("set_combat_enabled"):
		combat_system.set_combat_enabled(true)

	# Reset sprite
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "position", Vector2.ZERO, 0.1)

	print("[LeapEnderSystem] Completed")

	leap_ender_completed.emit()
	EventBus.leap_ender_completed.emit()

# ============================================================================
# HIT DETECTION
# ============================================================================

var hit_enemies: Array[Node] = []

func _check_leap_hits() -> void:
	"""Checks for enemies hit during leap"""

	# Get enemies in AoE
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if enemy in hit_enemies:
			continue  # Already hit

		var distance = player.global_position.distance_to(enemy.global_position)

		if distance <= LEAP_AOE_RADIUS:
			_hit_enemy(enemy)

func _hit_enemy(enemy: Node) -> void:
	"""Applies hit to enemy"""

	hit_enemies.append(enemy)

	# Apply damage
	var damage = _calculate_leap_damage()
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, player)

	# Apply knockback (enhanced)
	var dir_to_enemy = enemy.global_position - player.global_position

	# CRITICAL: Prevent NaN from normalizing zero vector
	var knockback_dir: Vector2
	if dir_to_enemy.length_squared() < 0.01:
		knockback_dir = Vector2(1, 0)  # Default direction
	else:
		knockback_dir = dir_to_enemy.normalized()

	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(knockback_dir, LEAP_KNOCKBACK_FORCE, LEAP_KNOCKBACK_DURATION)
	elif enemy.has_node("KnockbackComponent"):
		var kb = enemy.get_node("KnockbackComponent")
		if kb.has_method("apply_knockback"):
			kb.apply_knockback(knockback_dir, LEAP_KNOCKBACK_FORCE, LEAP_KNOCKBACK_DURATION)

	# Register hit with combat manager
	if CombatManager and CombatManager.has_method("register_hit"):
		CombatManager.register_hit(damage, enemy)

	# VFX
	_spawn_hit_effect(enemy.global_position)

	# Emit hit signal
	EventBus.hit_registered.emit(player, enemy, damage)

	print("[LeapEnderSystem] Hit enemy: %s (damage: %d, knockback: %.0f)" % [enemy.name, damage, LEAP_KNOCKBACK_FORCE])

	# Teleport to nearest enemy after successful hit
	_teleport_to_nearest_enemy(enemy)

func _calculate_leap_damage() -> int:
	"""Calculates leap ender damage"""

	var base_damage: int = 10  # Base attack damage

	# Get base from combat system if available
	if combat_system:
		var damages = combat_system.get("attack_damages")
		if damages and damages.size() > 0:
			base_damage = damages[0]

	# Apply combo multiplier
	var combo_mult: float = 1.0
	if combo_tracker:
		combo_mult = combo_tracker.get_combo_multiplier()

	# Apply leap multiplier
	var leap_mult: float = LEAP_DAMAGE_MULTIPLIER

	var final_damage = base_damage * combo_mult * leap_mult

	return int(round(final_damage))

# ============================================================================
# EFFECTS
# ============================================================================

func _spawn_hit_effect(hit_position: Vector2) -> void:
	"""Spawns hit VFX"""

	# Check if VFX scene exists
	if not ResourceLoader.exists("res://vfx/particles/leap_impact.tscn"):
		print("[LeapEnderSystem] Leap impact VFX not found, skipping")
		return

	var vfx_scene = preload("res://vfx/particles/leap_impact.tscn")
	var vfx = vfx_scene.instantiate()

	get_tree().root.add_child(vfx)
	vfx.global_position = hit_position

	# Auto-cleanup
	await get_tree().create_timer(1.0).timeout
	if vfx:
		vfx.queue_free()

func _teleport_to_nearest_enemy(current_enemy: Node) -> void:
	"""Teleports player to nearest enemy after successful hit"""

	if not player:
		return

	# Get all enemies
	var all_enemies = get_tree().get_nodes_in_group("enemies")

	var nearest_enemy: Node = null
	var nearest_distance: float = INF

	# Find nearest enemy (excluding current one)
	for enemy in all_enemies:
		if enemy == current_enemy:
			continue  # Skip the enemy we just hit

		if not is_instance_valid(enemy):
			continue  # Skip invalid/dead enemies

		# Check if enemy is alive
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue

		var distance = player.global_position.distance_to(enemy.global_position)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	# Teleport to nearest enemy
	if nearest_enemy:
		var teleport_offset = 60.0  # 60px away from enemy
		var dir_from_enemy = player.global_position - nearest_enemy.global_position

		# CRITICAL: Prevent NaN from normalizing zero vector
		var direction: Vector2
		if dir_from_enemy.length_squared() < 0.01:
			direction = Vector2(1, 0)  # Default direction if at same position
		else:
			direction = dir_from_enemy.normalized()

		var teleport_pos = nearest_enemy.global_position + (direction * teleport_offset)

		print("[LeapEnderSystem] Teleporting to nearest enemy: %s (distance: %.0f)" % [nearest_enemy.name, nearest_distance])

		# Spawn teleport VFX at old position
		_spawn_hit_effect(player.global_position)

		# Safe teleport: reset velocity first to prevent physics conflicts
		player.velocity = Vector2.ZERO

		# Safety: Check for NaN before teleporting
		if is_nan(teleport_pos.x) or is_nan(teleport_pos.y):
			print("[LeapEnderSystem] ERROR: Teleport position is NaN! Aborting teleport.")
			_complete_leap()
			return

		# Teleport
		player.global_position = teleport_pos

		# Spawn teleport VFX at new position
		_spawn_hit_effect(teleport_pos)

		# Audio feedback
		AudioManager.play_sfx("player_leap_attack", 0.12)

		# Small camera shake
		if player.has_node("PlayerCamera"):
			player.get_node("PlayerCamera").add_trauma(0.15)
	else:
		print("[LeapEnderSystem] No other enemies found for teleport")

func _on_leap_available() -> void:
	"""Called when leap ender becomes available"""

	# Reset hit list for new leap
	hit_enemies.clear()

	# Visual hint (optional)
	print("[LeapEnderSystem] Leap available (hold direction + attack)")

# ============================================================================
# UTILITY
# ============================================================================

func is_leaping() -> bool:
	"""Returns true if currently executing leap ender"""
	return current_state != State.IDLE

func can_leap() -> bool:
	"""Returns true if leap ender can be triggered"""
	return current_state == State.IDLE and combo_tracker and combo_tracker.check_leap_ender_input()
