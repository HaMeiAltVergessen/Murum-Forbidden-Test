extends Node
## LauncherSystem - Handles launching enemies into the air for aerial combos
class_name LauncherSystem

# ============ CONFIGURATION ============
@export var enabled: bool = true
@export var launch_force: float = 600.0  # Upward launch velocity
@export var launch_horizontal_force: float = 100.0  # Horizontal push
@export var launcher_mana_cost: int = 15  # Mana cost for launcher attack
@export var launcher_damage: int = 20  # Damage dealt by launcher
@export var launcher_cooldown: float = 2.0  # Cooldown between launchers

# ============ INPUT ============
const LAUNCHER_INPUT: String = "staff_throw"  # Q key by default

# ============ STATE ============
var is_on_cooldown: bool = false
var cooldown_timer: float = 0.0
var launched_enemies: Array[BaseEnemy] = []  # Currently airborne enemies

# ============ REFERENCES ============
var player: CharacterBody2D = null
var mana_component: Node = null
var combat_system: Node = null

# ============ SIGNALS ============
signal launcher_activated()
signal enemy_launched(enemy: BaseEnemy)
signal launcher_cooldown_started(duration: float)
signal launcher_ready()


func _ready() -> void:
	if not enabled:
		return

	# Get references
	player = owner as CharacterBody2D
	if not player:
		push_error("[LauncherSystem] Owner must be player CharacterBody2D")
		return

	# Get ManaComponent
	mana_component = player.get_node_or_null("ManaComponent")
	if not mana_component:
		push_warning("[LauncherSystem] ManaComponent not found")

	# Get CombatSystem
	combat_system = player.get_node_or_null("CombatSystem")

	print("[LauncherSystem] Initialized")


func _process(delta: float) -> void:
	if not enabled:
		return

	# Handle cooldown
	if is_on_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			_end_cooldown()

	# Check for launcher input (Hold Up + Attack or special input)
	if _can_use_launcher() and _check_launcher_input():
		_execute_launcher()


# ============ LAUNCHER EXECUTION ============
func _can_use_launcher() -> bool:
	"""Returns true if launcher can be used"""
	if not enabled:
		return false

	if is_on_cooldown:
		return false

	# Check if player is in valid state (not attacking, not dashing, etc)
	if combat_system and combat_system.is_attacking:
		return false

	# Check mana
	if not _has_sufficient_mana():
		return false

	return true


func _check_launcher_input() -> bool:
	"""Checks if launcher input is pressed"""
	# For now, use staff_throw input + holding up
	var up_held: bool = Input.is_action_pressed("jump")
	var launcher_pressed: bool = Input.is_action_just_pressed(LAUNCHER_INPUT)

	return launcher_pressed and up_held


func _has_sufficient_mana() -> bool:
	"""Checks if player has enough mana"""
	if not mana_component:
		return true  # No mana component = always allowed

	if not mana_component.has_method("has_mana"):
		return true

	return mana_component.has_mana(launcher_mana_cost)


func _execute_launcher() -> void:
	"""Executes launcher attack"""
	print("[LauncherSystem] Executing launcher!")

	# Consume mana
	if mana_component and mana_component.has_method("use_mana"):
		mana_component.use_mana(launcher_mana_cost)

	# Find nearby enemies
	var enemies_to_launch: Array[BaseEnemy] = _find_launchable_enemies()

	if enemies_to_launch.is_empty():
		print("[LauncherSystem] No enemies in range")
		_start_cooldown()  # Still go on cooldown
		return

	# Launch all nearby enemies
	for enemy in enemies_to_launch:
		_launch_enemy(enemy)

	# Play launcher animation/effect
	_play_launcher_effect()

	# Start cooldown
	_start_cooldown()

	# Emit signals
	launcher_activated.emit()
	EventBus.emit_signal("launcher_activated")  # Will add to EventBus


func _find_launchable_enemies() -> Array[BaseEnemy]:
	"""Finds enemies within launcher range"""
	var launchable: Array[BaseEnemy] = []
	const LAUNCHER_RANGE: float = 80.0  # Range in front of player

	# Get all enemies in scene
	var enemies: Array = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not enemy is BaseEnemy:
			continue

		var base_enemy: BaseEnemy = enemy as BaseEnemy

		# Skip dead or already launched enemies
		if base_enemy.is_dead:
			continue

		# Check distance
		var distance: float = player.global_position.distance_to(base_enemy.global_position)
		if distance > LAUNCHER_RANGE:
			continue

		# Check if in front of player
		var dir_vec = base_enemy.global_position - player.global_position

		# CRITICAL: Prevent NaN from normalizing zero vector
		var direction_to_enemy: Vector2
		if dir_vec.length_squared() < 0.01:
			direction_to_enemy = Vector2(1, 0)  # Default direction
		else:
			direction_to_enemy = dir_vec.normalized()

		var player_facing: float = player.scale.x  # 1 = right, -1 = left

		if player_facing > 0 and direction_to_enemy.x < 0:
			continue  # Enemy is behind
		if player_facing < 0 and direction_to_enemy.x > 0:
			continue  # Enemy is behind

		launchable.append(base_enemy)

	return launchable


func _launch_enemy(enemy: BaseEnemy) -> void:
	"""Launches a single enemy into the air"""
	if not enemy:
		return

	print("[LauncherSystem] Launching enemy: ", enemy.name)

	# Calculate launch direction (up + slightly away from player)
	var dir_vec = enemy.global_position - player.global_position

	# CRITICAL: Prevent NaN from normalizing zero vector
	var direction_to_enemy: Vector2
	if dir_vec.length_squared() < 0.01:
		direction_to_enemy = Vector2(1, 0)  # Default direction
	else:
		direction_to_enemy = dir_vec.normalized()

	var launch_direction: Vector2 = Vector2(
		direction_to_enemy.x * launch_horizontal_force,
		-launch_force  # Negative = upward
	)

	# Apply knockback component for launch
	if enemy.has_node("KnockbackComponent"):
		var knockback: KnockbackComponent = enemy.get_node("KnockbackComponent")
		knockback.apply_knockback(launch_direction.normalized(), launch_direction.length(), 0.5)
	else:
		# Fallback: directly set velocity
		enemy.velocity = launch_direction

	# Enter juggle state
	if enemy.has_method("enter_juggle_state"):
		enemy.enter_juggle_state()

	# Deal damage
	if enemy.has_node("HealthComponent"):
		var health_comp = enemy.get_node("HealthComponent")
		if health_comp and health_comp.has_method("take_damage"):
			health_comp.take_damage(launcher_damage)

	# Track launched enemy
	if not launched_enemies.has(enemy):
		launched_enemies.append(enemy)

	# Connect to enemy death to remove from tracking
	if not enemy.is_connected("tree_exited", _on_enemy_removed):
		enemy.tree_exited.connect(_on_enemy_removed.bind(enemy))

	# Emit signals
	enemy_launched.emit(enemy)
	EventBus.emit_signal("enemy_launched", enemy)  # Will add to EventBus


func _play_launcher_effect() -> void:
	"""Plays visual/audio effects for launcher"""
	# Play sound
	AudioManager.play_sfx_at_position("combat/launcher", player.global_position, 0.5)

	# TODO: Spawn launcher VFX particle (launch_burst)
	# Will be created in later step


# ============ COOLDOWN MANAGEMENT ============
func _start_cooldown() -> void:
	"""Starts launcher cooldown"""
	is_on_cooldown = true
	cooldown_timer = launcher_cooldown
	launcher_cooldown_started.emit(launcher_cooldown)
	print("[LauncherSystem] Cooldown started: %.1fs" % launcher_cooldown)


func _end_cooldown() -> void:
	"""Ends launcher cooldown"""
	is_on_cooldown = false
	cooldown_timer = 0.0
	launcher_ready.emit()
	print("[LauncherSystem] Ready!")


# ============ ENEMY TRACKING ============
func _on_enemy_removed(enemy: BaseEnemy) -> void:
	"""Called when a launched enemy is removed from scene"""
	if launched_enemies.has(enemy):
		launched_enemies.erase(enemy)


func get_launched_enemies() -> Array[BaseEnemy]:
	"""Returns list of currently launched enemies"""
	return launched_enemies.duplicate()


func is_enemy_launched(enemy: BaseEnemy) -> bool:
	"""Checks if enemy is currently launched"""
	return launched_enemies.has(enemy)


# ============ GETTERS ============
func get_cooldown_remaining() -> float:
	"""Returns cooldown time remaining"""
	return cooldown_timer


func is_ready() -> bool:
	"""Returns true if launcher is ready to use"""
	return not is_on_cooldown and _has_sufficient_mana()


# ============ CONTROL ============
func enable() -> void:
	"""Enables launcher system"""
	enabled = true
	print("[LauncherSystem] Enabled")


func disable() -> void:
	"""Disables launcher system"""
	enabled = false
	print("[LauncherSystem] Disabled")


func reset_cooldown() -> void:
	"""Immediately resets cooldown (debug/powerup)"""
	_end_cooldown()
