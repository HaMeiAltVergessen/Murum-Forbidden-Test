extends Node
class_name StaffController

## Controls staff throw mechanic

# ============================================================================
# CONSTANTS
# ============================================================================

const THROW_COST: int = 15
const THROW_SPEED: float = 850.0
const MAX_RANGE: float = 600.0
const RETURN_SPEED: float = 900.0
const DAMAGE: int = 50  # 2.5x damage for 2-shot kills
const COOLDOWN_AFTER_CATCH: float = 0.2

const STAFF_PROJECTILE_SCENE = preload("res://player/projectiles/staff_projectile.tscn")

# ============================================================================
# STATE
# ============================================================================

enum State { READY, THROWN, RETURNING, COOLDOWN }

var current_state: State = State.READY
var cooldown_timer: float = 0.0

var active_staff: Node2D = null

# ============================================================================
# REFERENCES
# ============================================================================

@onready var player: CharacterBody2D = owner

# ============================================================================
# SIGNALS
# ============================================================================

signal staff_thrown
signal staff_returning
signal staff_caught
signal throw_failed(reason: String)

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("staff_throw"):
		attempt_throw()
	# Gamepad: RT + X (X = light_attack button)
	elif event.is_action_pressed("light_attack"):
		if _is_rt_pressed():
			attempt_throw()

func _is_rt_pressed() -> bool:
	"""Check if RT is pressed (either as button or analog trigger)"""
	# Button 7 (some controllers)
	if Input.is_action_pressed("gamepad_modifier"):
		return true
	# Axis 5 (analog trigger on Xbox/PS controllers)
	if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
		return true
	return false

# ============================================================================
# THROW LOGIC
# ============================================================================

func attempt_throw() -> void:
	if current_state != State.READY:
		throw_failed.emit("Staff not ready")
		return

	if cooldown_timer > 0.0:
		throw_failed.emit("Cooldown active")
		return

	if not _has_mana():
		throw_failed.emit("Not enough mana")
		_show_no_mana_feedback()
		return

	_consume_mana()
	_throw_staff()

func _throw_staff() -> void:
	print("[StaffController] Throwing staff")

	current_state = State.THROWN

	var direction = _get_throw_direction()

	active_staff = STAFF_PROJECTILE_SCENE.instantiate()
	get_tree().root.add_child(active_staff)

	active_staff.global_position = player.global_position
	active_staff.direction = direction
	active_staff.speed = THROW_SPEED
	active_staff.damage = DAMAGE
	active_staff.max_range = MAX_RANGE
	active_staff.return_speed = RETURN_SPEED
	active_staff.owner_player = player

	active_staff.staff_max_range_reached.connect(_on_staff_start_return)
	active_staff.staff_hit_wall.connect(_on_staff_start_return)
	active_staff.staff_caught.connect(_on_staff_caught)

	if AudioManager:
		AudioManager.play_sfx_at_position("player/staff_throw", player.global_position, 0.1)

	staff_thrown.emit()
	_disable_melee_attack()

func _get_throw_direction() -> Vector2:
	var mouse_pos = player.get_global_mouse_position()
	var direction = (mouse_pos - player.global_position).normalized()

	if direction.length() < 0.1:
		var sprite = player.get_node_or_null("Sprite2D")
		if sprite:
			var facing = 1 if not sprite.flip_h else -1
			direction = Vector2(facing, 0)

	return direction

# ============================================================================
# RETURN LOGIC
# ============================================================================

func _on_staff_start_return() -> void:
	if current_state != State.THROWN:
		return

	print("[StaffController] Staff returning")

	current_state = State.RETURNING

	if AudioManager:
		AudioManager.play_sfx_at_position("player/staff_return", player.global_position, 0.08)

	staff_returning.emit()

func _on_staff_caught() -> void:
	if current_state != State.RETURNING:
		return

	print("[StaffController] Staff caught")

	current_state = State.COOLDOWN
	cooldown_timer = COOLDOWN_AFTER_CATCH

	if active_staff:
		active_staff.queue_free()
		active_staff = null

	if AudioManager:
		AudioManager.play_sfx_at_position("player/staff_catch", player.global_position, 0.12)

	staff_caught.emit()
	_enable_melee_attack()

# ============================================================================
# COOLDOWN
# ============================================================================

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

		if cooldown_timer <= 0.0:
			current_state = State.READY

# ============================================================================
# MANA MANAGEMENT
# ============================================================================

func _has_mana() -> bool:
	if not player:
		return false

	var mana_component = player.get_node_or_null("ManaComponent")
	if not mana_component:
		return false

	return mana_component.current_mana >= THROW_COST

func _consume_mana() -> void:
	if not player:
		return

	var mana_component = player.get_node_or_null("ManaComponent")
	if mana_component:
		mana_component.current_mana -= THROW_COST
		EventBus.player_mana_changed.emit(mana_component.current_mana, mana_component.max_mana)

func _show_no_mana_feedback() -> void:
	if AudioManager:
		AudioManager.play_sfx_at_position("ui/error", player.global_position, 0.1)

	EventBus.mana_insufficient.emit()

# ============================================================================
# ATTACK CONTROL
# ============================================================================

func _disable_melee_attack() -> void:
	var combat_system = player.get_node_or_null("CombatSystem")
	if combat_system and "melee_enabled" in combat_system:
		combat_system.melee_enabled = false

func _enable_melee_attack() -> void:
	var combat_system = player.get_node_or_null("CombatSystem")
	if combat_system and "melee_enabled" in combat_system:
		combat_system.melee_enabled = true

# ============================================================================
# UTILITY
# ============================================================================

func is_staff_ready() -> bool:
	return current_state == State.READY and cooldown_timer <= 0.0

func get_state_name() -> String:
	match current_state:
		State.READY: return "READY"
		State.THROWN: return "THROWN"
		State.RETURNING: return "RETURNING"
		State.COOLDOWN: return "COOLDOWN"
		_: return "UNKNOWN"
