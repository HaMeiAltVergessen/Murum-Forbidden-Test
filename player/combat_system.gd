extends Node2D
## CombatSystem handles player combat, combos, and attack hitboxes
class_name CombatSystem

# ============ REFERENCES ============
@onready var player: CharacterBody2D = get_parent()
@onready var hitbox: Area2D = $HitboxComponent
@onready var movement_controller: MovementController = player.get_node_or_null("MovementController")
@onready var combo_tracker: ComboTracker = null  # Will create dynamically
@onready var resonance_system: ResonanceSystem = null  # Will create dynamically
@onready var staff_sprite: Node2D = null  # Will create dynamically

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

	# Create combo tracker
	_create_combo_tracker()

	# Create resonance system
	_create_resonance_system()

	# Create staff visual
	_create_staff_visual()


func _process(delta: float) -> void:
	_update_combo_timer(delta)
	_update_attack_timer(delta)
	_update_staff_facing()


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

	# Animate staff
	_animate_staff_attack(current_combo)

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


# ============ COMBO TRACKER ============
func _create_combo_tracker() -> void:
	"""Creates the combo tracker component."""
	combo_tracker = ComboTracker.new()
	combo_tracker.name = "ComboTracker"
	add_child(combo_tracker)

	print("[CombatSystem] ComboTracker created")


# ============ RESONANCE SYSTEM ============
func _create_resonance_system() -> void:
	"""Creates the resonance system component."""
	resonance_system = ResonanceSystem.new()
	resonance_system.name = "ResonanceSystem"
	add_child(resonance_system)

	# Connect to resonance full signal (preparation for Commit 003)
	resonance_system.resonance_full.connect(_on_resonance_full)

	print("[CombatSystem] ResonanceSystem created")


func _on_resonance_full() -> void:
	"""Called when resonance reaches 100% (preparation for Commit 003)."""
	print("[CombatSystem] Resonance full! (Mode activation in Commit 003)")


# ============ STAFF VISUAL ============
func _update_staff_facing() -> void:
	"""Updates staff position based on facing direction"""
	if not staff_sprite or not movement_controller:
		return

	var facing: int = movement_controller.get_facing_direction()

	# Flip staff horizontally based on facing direction
	# Facing right (1) = staff on right side
	# Facing left (-1) = staff on left side (flipped)
	staff_sprite.scale.x = facing


func _create_staff_visual() -> void:
	"""Creates a simple staff sprite using ColorRects"""
	# Create staff container
	staff_sprite = Node2D.new()
	staff_sprite.name = "StaffSprite"
	add_child(staff_sprite)

	# Staff handle (brown) - Much longer now!
	var handle: ColorRect = ColorRect.new()
	handle.size = Vector2(10, 80)  # 10x80 instead of 6x48
	handle.position = Vector2(30, -40)  # Further from player
	handle.color = Color(0.4, 0.25, 0.1, 1)
	staff_sprite.add_child(handle)

	# Staff top (purple/magic) - Bigger and more visible
	var top: ColorRect = ColorRect.new()
	top.size = Vector2(20, 20)  # 20x20 instead of 12x12
	top.position = Vector2(25, -50)  # At the top of the staff
	top.color = Color(0.7, 0.3, 1, 1)
	staff_sprite.add_child(top)

	# Staff is now ALWAYS visible!
	staff_sprite.visible = true
	staff_sprite.rotation = 0  # Default idle position


func _animate_staff_attack(attack_num: int) -> void:
	"""Animates the staff during attack"""
	if not staff_sprite:
		return

	# Different animations for each combo
	var tween: Tween = create_tween()

	match attack_num:
		1:  # Overhead swing
			tween.tween_property(staff_sprite, "rotation", -PI/3, attack_durations[0] * 0.3)
			tween.tween_property(staff_sprite, "rotation", PI/6, attack_durations[0] * 0.7)
		2:  # Side swing
			tween.tween_property(staff_sprite, "rotation", -PI/6, attack_durations[1] * 0.3)
			tween.tween_property(staff_sprite, "rotation", PI/3, attack_durations[1] * 0.7)
		3:  # Upward thrust
			tween.tween_property(staff_sprite, "rotation", PI/4, attack_durations[2] * 0.4)
			tween.tween_property(staff_sprite, "rotation", -PI/4, attack_durations[2] * 0.6)

	# Return to idle position after attack
	await tween.finished
	var return_tween: Tween = create_tween()
	return_tween.tween_property(staff_sprite, "rotation", 0.0, 0.1)


# ============ GETTERS ============
func can_attack() -> bool:
	"""Returns true if player can perform an attack"""
	return not is_attacking or attack_queued == false


func get_current_combo() -> int:
	"""Returns the current combo number (0-3)"""
	return current_combo
