extends Node2D
## CombatSystem handles player combat, combos, and attack hitboxes
class_name CombatSystem

# ============ REFERENCES ============
@onready var player: CharacterBody2D = get_parent()
@onready var hitbox: Area2D = $HitboxComponent
@onready var movement_controller: MovementController = player.get_node_or_null("MovementController")

# ============ ATTACK CONFIGURATION ============
@export var attack_damages: Array[int] = [10, 12, 15]  # Damage for attacks 1, 2, 3
@export var attack_durations: Array[float] = [0.3, 0.35, 0.4]  # Duration of each attack
@export var combo_window: float = 0.5  # Time window to continue combo

# ============ COMBO STATE ============
var current_combo: int = 0  # 0 = no combo, 1-3 = attack number
var is_attacking: bool = false
var combo_timer: float = 0.0
var attack_timer: float = 0.0

# ============ ATTACK QUEUE ============
var attack_queued: bool = false


func _ready() -> void:
	if not hitbox:
		push_error("[CombatSystem] HitboxComponent not found as child!")
		return

	# Ensure hitbox is deactivated initially
	hitbox.monitoring = false
	hitbox.visible = false


func _process(delta: float) -> void:
	_update_combo_timer(delta)
	_update_attack_timer(delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("light_attack"):
		_request_attack()


# ============ ATTACK SYSTEM ============
func _request_attack() -> void:
	"""Requests an attack (queues it if currently attacking)"""
	if is_attacking:
		attack_queued = true
		return

	_perform_attack()


func _perform_attack() -> void:
	"""Executes an attack in the combo sequence"""
	# Determine next combo number
	if combo_timer > 0 and current_combo < 3:
		current_combo += 1
	else:
		current_combo = 1

	is_attacking = true
	attack_queued = false
	combo_timer = combo_window
	attack_timer = attack_durations[current_combo - 1]

	# Update hitbox damage
	if hitbox.has_method("set_damage"):
		hitbox.set_damage(attack_damages[current_combo - 1])

	# Activate hitbox
	_activate_hitbox()

	# Stop horizontal movement during attack
	if player:
		player.velocity.x = 0

	# Play audio
	AudioManager.play_sfx("attack_" + str(current_combo))

	# Emit signal
	EventBus.player_attacked.emit(current_combo)

	print("[CombatSystem] Attack ", current_combo, " - Damage: ", attack_damages[current_combo - 1])


func _update_attack_timer(delta: float) -> void:
	"""Updates the attack animation timer"""
	if not is_attacking:
		return

	attack_timer -= delta

	if attack_timer <= 0:
		_end_attack()


func _end_attack() -> void:
	"""Ends the current attack"""
	is_attacking = false
	_deactivate_hitbox()

	# Check for queued attack
	if attack_queued:
		_perform_attack()


func _update_combo_timer(delta: float) -> void:
	"""Updates the combo window timer"""
	if combo_timer > 0:
		combo_timer -= delta

		if combo_timer <= 0:
			_reset_combo()


func _reset_combo() -> void:
	"""Resets the combo counter"""
	current_combo = 0
	print("[CombatSystem] Combo reset")


# ============ HITBOX MANAGEMENT ============
func _activate_hitbox() -> void:
	"""Activates the hitbox for damage detection"""
	if not hitbox:
		return

	hitbox.monitoring = true
	hitbox.visible = true

	# Position hitbox based on facing direction
	if movement_controller:
		var facing: int = movement_controller.get_facing_direction()
		hitbox.scale.x = abs(hitbox.scale.x) * facing


func _deactivate_hitbox() -> void:
	"""Deactivates the hitbox"""
	if not hitbox:
		return

	hitbox.monitoring = false
	hitbox.visible = false


# ============ GETTERS ============
func can_attack() -> bool:
	"""Returns true if player can perform an attack"""
	return not is_attacking or attack_queued == false


func get_current_combo() -> int:
	"""Returns the current combo number (0-3)"""
	return current_combo
