extends Node
## AirComboSystem - Manages aerial combat and juggle mechanics
class_name AirComboSystem

# ============ CONFIGURATION ============
@export var enabled: bool = true
@export var air_attack_damage: int = 15  # Damage per air hit
@export var juggle_force: float = 400.0  # Force to keep enemy airborne
@export var max_air_combo: int = 10  # Maximum air combo hits
@export var slam_damage_multiplier: float = 2.0  # Damage multiplier for slam finisher
@export var slam_force: float = 800.0  # Downward slam force

# ============ TIMING ============
const AIR_COMBO_WINDOW: float = 1.0  # Time window for next air hit
const MIN_HEIGHT_FOR_AIR_ATTACK: float = 50.0  # Minimum height to perform air attacks

# ============ STATE ============
var current_air_combo: int = 0
var air_combo_timer: float = 0.0
var is_airborne: bool = false
var juggled_enemy: Node = null  # Currently juggled enemy (changed from BaseEnemy to Node)

# ============ REFERENCES ============
var player: CharacterBody2D = null
var combat_system: Node = null

# ============ SIGNALS ============
signal air_combo_started(enemy: Node)
signal air_hit_registered(count: int, enemy: Node)
signal air_combo_ended(final_count: int)
signal slam_finisher_ready()
signal slam_executed(enemy: Node, damage: int)


func _ready() -> void:
	if not enabled:
		return

	# Get references
	player = owner as CharacterBody2D
	if not player:
		push_error("[AirComboSystem] Owner must be player CharacterBody2D")
		return

	# Get CombatSystem
	combat_system = player.get_node_or_null("CombatSystem")

	# Connect to launcher events
	_connect_launcher_events()

	# Connect to Ende der Schwerkraft
	if EventBus.has_signal("ende_schwerkraft_executed"):
		EventBus.ende_schwerkraft_executed.connect(_on_ende_schwerkraft)

	print("[AirComboSystem] Initialized")


func _process(delta: float) -> void:
	if not enabled:
		return

	# Update air combo timer
	if current_air_combo > 0:
		air_combo_timer -= delta
		if air_combo_timer <= 0.0:
			_end_air_combo()

	# Check player airborne state
	_update_airborne_state()

	# Check for air attack input
	if _can_perform_air_attack() and Input.is_action_just_pressed("light_attack"):
		_perform_air_attack()

	# Check for slam finisher input (requires both wolkenbruch_slam AND attack)
	# Air Finisher has priority over Wolkenbruch when air combo count >= 3
	if _can_perform_slam() and Input.is_action_just_pressed("wolkenbruch_slam") and Input.is_action_pressed("light_attack"):
		_perform_slam_finisher()


# ============ LAUNCHER EVENT CONNECTION ============
func _connect_launcher_events() -> void:
	"""Connects to launcher system events"""
	# Find LauncherSystem in player
	var launcher_system = player.get_node_or_null("LauncherSystem")
	if launcher_system:
		if launcher_system.has_signal("enemy_launched"):
			launcher_system.enemy_launched.connect(_on_enemy_launched)
			print("[AirComboSystem] Connected to LauncherSystem")


# ============ AIRBORNE STATE ============
func _update_airborne_state() -> void:
	"""Updates whether player is airborne"""
	is_airborne = not player.is_on_floor()


func _on_enemy_launched(enemy: Node) -> void:
	"""Called when launcher system launches an enemy"""
	print("[AirComboSystem] Enemy launched, starting air combo tracking")

	# Set as juggled enemy
	juggled_enemy = enemy

	# Start air combo tracking
	current_air_combo = 0
	air_combo_timer = AIR_COMBO_WINDOW

	# Emit signal
	air_combo_started.emit(enemy)
	EventBus.emit_signal("air_combo_started", enemy)  # Will add to EventBus


func _on_ende_schwerkraft(enemy: Node) -> void:
	"""Called when Ende der Schwerkraft launches enemy"""
	print("[AirComboSystem] Ready for air combo after Ende der Schwerkraft")

	# Set juggle target for immediate air combo
	juggled_enemy = enemy

	# Reset counter for fresh air combo
	current_air_combo = 0
	air_combo_timer = AIR_COMBO_WINDOW

	# Emit signal
	air_combo_started.emit(enemy)
	if EventBus:
		EventBus.emit_signal("air_combo_started", enemy)


# ============ AIR ATTACK EXECUTION ============
func _can_perform_air_attack() -> bool:
	"""Returns true if player can perform air attack"""
	if not enabled:
		return false

	# Must be airborne
	if not is_airborne:
		return false

	# Must have juggled enemy (and enemy must still be valid/alive)
	if not juggled_enemy or not is_instance_valid(juggled_enemy):
		return false

	# Must be within combo window
	if air_combo_timer <= 0.0:
		return false

	# Check if enemy is in range
	if not _is_enemy_in_air_range(juggled_enemy):
		return false

	# Check max combo limit
	if current_air_combo >= max_air_combo:
		return false

	return true


func _is_enemy_in_air_range(enemy: Node) -> bool:
	"""Checks if enemy is in range for air attack"""
	const AIR_ATTACK_RANGE: float = 100.0

	if not enemy:
		return false

	var distance: float = player.global_position.distance_to(enemy.global_position)
	return distance <= AIR_ATTACK_RANGE


func _perform_air_attack() -> void:
	"""Performs an air attack on juggled enemy"""
	if not juggled_enemy:
		return

	print("[AirComboSystem] Air attack %d!" % (current_air_combo + 1))

	# Increment combo
	current_air_combo += 1
	air_combo_timer = AIR_COMBO_WINDOW  # Reset timer

	# Calculate juggle direction (upward + toward player)
	var direction_to_player: Vector2 = (player.global_position - juggled_enemy.global_position).normalized()
	var juggle_direction: Vector2 = Vector2(
		direction_to_player.x * 100.0,  # Slight horizontal pull
		-juggle_force  # Upward force
	)

	# Apply juggle knockback
	if juggled_enemy.has_node("KnockbackComponent"):
		var knockback: KnockbackComponent = juggled_enemy.get_node("KnockbackComponent")
		knockback.apply_knockback(juggle_direction.normalized(), juggle_direction.length(), 0.3)

	# Deal damage
	if juggled_enemy.has_node("HealthComponent"):
		var health: HealthComponent = juggled_enemy.get_node("HealthComponent")
		health.take_damage(air_attack_damage)

	# Play air hit effect
	_play_air_hit_effect()

	# Emit signals
	air_hit_registered.emit(current_air_combo, juggled_enemy)
	EventBus.emit_signal("air_hit_registered", current_air_combo, juggled_enemy)

	# Check if slam is ready
	if current_air_combo >= 3:
		slam_finisher_ready.emit()


func _play_air_hit_effect() -> void:
	"""Plays visual/audio effects for air hit"""
	# Play sound
	AudioManager.play_sfx_at_position("combat/air_hit", player.global_position, 0.4)

	# TODO: Spawn air hit VFX particle
	# Will be created in later step


# ============ SLAM FINISHER ============
func _can_perform_slam() -> bool:
	"""Returns true if player can perform slam finisher"""
	if not enabled:
		return false

	# Must be airborne
	if not is_airborne:
		return false

	# Check if Wolkenbruch is active (has priority)
	var wolkenbruch = player.get_node_or_null("Wolkenbruch")
	if wolkenbruch and wolkenbruch.has_method("is_active"):
		if wolkenbruch.is_active():
			return false

	# Must have active air combo (at least 3 hits)
	if current_air_combo < 3:
		return false

	# Must have juggled enemy (and enemy must still be valid/alive)
	if not juggled_enemy or not is_instance_valid(juggled_enemy):
		return false

	return true


func _perform_slam_finisher() -> void:
	"""Performs slam finisher to end air combo"""
	if not juggled_enemy:
		return

	print("[AirComboSystem] SLAM FINISHER! (Air combo: %d)" % current_air_combo)

	# Calculate slam damage (base damage × multiplier × air combo)
	var slam_damage: int = int(air_attack_damage * slam_damage_multiplier * current_air_combo)

	# Calculate slam direction (straight down)
	var slam_direction: Vector2 = Vector2(0, slam_force)

	# Apply slam knockback
	if juggled_enemy.has_node("KnockbackComponent"):
		var knockback: KnockbackComponent = juggled_enemy.get_node("KnockbackComponent")
		knockback.apply_knockback(slam_direction.normalized(), slam_force, 0.5)

	# Deal massive damage
	if juggled_enemy.has_node("HealthComponent"):
		var health: HealthComponent = juggled_enemy.get_node("HealthComponent")
		health.take_damage(slam_damage)

	# Play slam effect
	_play_slam_effect()

	# Emit signals
	slam_executed.emit(juggled_enemy, slam_damage)
	EventBus.emit_signal("slam_executed", juggled_enemy, slam_damage)

	# Boost player downward for slam
	player.velocity.y = slam_force

	# End air combo
	_end_air_combo()


func _play_slam_effect() -> void:
	"""Plays visual/audio effects for slam finisher"""
	# Play sound
	AudioManager.play_sfx_at_position("combat/slam", player.global_position, 0.7)

	# TODO: Spawn slam VFX particle
	# Will be created in later step


# ============ AIR COMBO MANAGEMENT ============
func _end_air_combo() -> void:
	"""Ends the current air combo"""
	if current_air_combo == 0:
		return

	print("[AirComboSystem] Air combo ended at %d hits" % current_air_combo)

	var final_count: int = current_air_combo

	# Reset state
	current_air_combo = 0
	air_combo_timer = 0.0
	juggled_enemy = null

	# Emit signal
	air_combo_ended.emit(final_count)
	EventBus.emit_signal("air_combo_ended", final_count)


# ============ GETTERS ============
func get_air_combo_count() -> int:
	"""Returns current air combo count"""
	return current_air_combo


func get_juggled_enemy() -> Node:
	"""Returns currently juggled enemy"""
	return juggled_enemy


func is_in_air_combo() -> bool:
	"""Returns true if currently in air combo"""
	return current_air_combo > 0 and juggled_enemy != null


func get_combo_time_remaining() -> float:
	"""Returns time remaining for next air hit"""
	return air_combo_timer


func get_combo_progress() -> float:
	"""Returns air combo timer progress (0.0-1.0)"""
	if air_combo_timer <= 0.0:
		return 0.0
	return air_combo_timer / AIR_COMBO_WINDOW


func can_slam() -> bool:
	"""Returns true if slam finisher is available"""
	return _can_perform_slam()


# ============ CONTROL ============
func enable() -> void:
	"""Enables air combo system"""
	enabled = true
	print("[AirComboSystem] Enabled")


func disable() -> void:
	"""Disables air combo system"""
	enabled = false
	_end_air_combo()
	print("[AirComboSystem] Disabled")


func force_end_combo() -> void:
	"""Manually ends air combo"""
	_end_air_combo()


# ============ DEBUG ============
func get_debug_info() -> Dictionary:
	"""Returns debug information"""
	return {
		"enabled": enabled,
		"air_combo": current_air_combo,
		"time_remaining": air_combo_timer,
		"juggled_enemy": juggled_enemy.name if juggled_enemy else "None",
		"can_slam": can_slam()
	}
