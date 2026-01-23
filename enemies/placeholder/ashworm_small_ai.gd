extends Node
class_name AshwormSmallAI

## AI Controller for Small Ashworm
## Burrows underground and lunges at player
## Godot 4.4 compatible

# ============================================================================
# CONSTANTS
# ============================================================================

const DETECTION_RANGE: float = 750.0
const LUNGE_RANGE: float = 150.0
const CRAWL_SPEED: float = 60.0
const CRAWL_DURATION: float = 3.0
const BURROW_DURATION: float = 0.5
const LUNGE_DURATION: float = 0.3
const SURFACE_DURATION: float = 0.3

# ============================================================================
# STATE
# ============================================================================

enum State {
	IDLE,
	CRAWL,
	BURROW,
	UNDERGROUND,
	LUNGE,
	SURFACE
}

var current_state: State = State.IDLE
var state_timer: float = 0.0
var lunge_target_position: Vector2 = Vector2.ZERO

# ============================================================================
# REFERENCES
# ============================================================================

var owner_enemy: CharacterBody2D
var target_player: CharacterBody2D
var sprite: Sprite2D
var original_modulate: Color

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	owner_enemy = owner as CharacterBody2D
	call_deferred("_find_player")

	if owner_enemy:
		sprite = owner_enemy.get_node_or_null("Sprite2D")
		if sprite:
			original_modulate = sprite.modulate

func _find_player() -> void:
	# Try P1 first
	target_player = get_tree().get_first_node_in_group("player")

	# If no P1, try P2
	if not target_player:
		target_player = get_tree().get_first_node_in_group("player2")

	# Register with CombatManager
	if target_player and owner_enemy:
		CombatManager.register_enemy(owner_enemy)

	print("[AshwormSmallAI] Initialized, target: %s" % (target_player.name if target_player else "none"))

# ============================================================================
# AI UPDATE
# ============================================================================

func _process(delta: float) -> void:
	if not owner_enemy or not target_player:
		if not target_player:
			_find_player()
		return

	# Skip when stunned
	if owner_enemy.is_stunned:
		owner_enemy.velocity = Vector2.ZERO
		return

	# Update state timer
	state_timer += delta

	# State machine
	match current_state:
		State.IDLE:
			_process_idle()
		State.CRAWL:
			_process_crawl(delta)
		State.BURROW:
			_process_burrow()
		State.UNDERGROUND:
			_process_underground()
		State.LUNGE:
			_process_lunge(delta)
		State.SURFACE:
			_process_surface()

# ============================================================================
# STATE PROCESSING
# ============================================================================

func _process_idle() -> void:
	var distance = owner_enemy.global_position.distance_to(target_player.global_position)

	if distance > DETECTION_RANGE:
		owner_enemy.velocity = Vector2.ZERO
		return

	# Start crawling toward player
	_change_state(State.CRAWL)

func _process_crawl(_delta: float) -> void:
	var distance = owner_enemy.global_position.distance_to(target_player.global_position)

	# Check if in lunge range or crawl time expired
	if distance <= LUNGE_RANGE or state_timer >= CRAWL_DURATION:
		_change_state(State.BURROW)
		return

	# Crawl toward player (velocity applied, move_and_slide in _physics_process)
	var direction = (target_player.global_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity.x = direction.x * CRAWL_SPEED
	# Note: gravity applied in _physics_process

	# Face direction
	if sprite and "flip_h" in sprite:
		sprite.flip_h = direction.x < 0

func _process_burrow() -> void:
	owner_enemy.velocity = Vector2.ZERO

	# Visual: Hide sprite gradually (burrowing underground)
	if sprite and state_timer < BURROW_DURATION:
		var alpha = 1.0 - (state_timer / BURROW_DURATION)
		sprite.modulate.a = alpha

	if state_timer >= BURROW_DURATION:
		# Fully underground - become invulnerable
		_change_state(State.UNDERGROUND)

func _process_underground() -> void:
	owner_enemy.velocity = Vector2.ZERO

	# Make invulnerable
	if owner_enemy.has_node("HurtboxComponent"):
		var hurtbox = owner_enemy.get_node("HurtboxComponent")
		hurtbox.monitorable = false

	# Hide sprite completely
	if sprite:
		sprite.visible = false

	# Store target position for lunge
	lunge_target_position = target_player.global_position

	# Prepare to lunge after brief moment
	if state_timer >= 0.2:
		_change_state(State.LUNGE)

func _process_lunge(_delta: float) -> void:
	# Lunge out of ground toward target position
	var direction = (lunge_target_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity = direction * 300.0  # Fast lunge (move_and_slide in _physics_process)

	# Show sprite emerging
	if sprite:
		sprite.visible = true
		var alpha = min(1.0, state_timer / LUNGE_DURATION)
		sprite.modulate.a = alpha

	# Enable hitbox during lunge
	if owner_enemy.has_node("HitboxComponent"):
		var hitbox = owner_enemy.get_node("HitboxComponent")
		hitbox.monitoring = true

	# Audio
	if state_timer == 0:  # First frame
		if AudioManager:
			AudioManager.play_sfx("enemies/geist_attack", 0.15)

	if state_timer >= LUNGE_DURATION:
		_change_state(State.SURFACE)

func _process_surface() -> void:
	owner_enemy.velocity = Vector2.ZERO

	# Make vulnerable again
	if owner_enemy.has_node("HurtboxComponent"):
		var hurtbox = owner_enemy.get_node("HurtboxComponent")
		hurtbox.monitorable = true

	# Disable hitbox
	if owner_enemy.has_node("HitboxComponent"):
		var hitbox = owner_enemy.get_node("HitboxComponent")
		hitbox.monitoring = false

	# Restore sprite
	if sprite:
		sprite.visible = true
		sprite.modulate = original_modulate

	if state_timer >= SURFACE_DURATION:
		# Repeat pattern
		_change_state(State.CRAWL)

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _change_state(new_state: State) -> void:
	current_state = new_state
	state_timer = 0.0

	# State entry logic
	match new_state:
		State.CRAWL:
			print("[AshwormSmallAI] State: CRAWL")
		State.BURROW:
			print("[AshwormSmallAI] State: BURROW (invulnerable)")
			if AudioManager:
				AudioManager.play_sfx("enemies/geist_hurt", 0.1)  # Placeholder burrow sound
		State.UNDERGROUND:
			print("[AshwormSmallAI] State: UNDERGROUND")
		State.LUNGE:
			print("[AshwormSmallAI] State: LUNGE (attack)")
		State.SURFACE:
			print("[AshwormSmallAI] State: SURFACE (vulnerable)")

# ============================================================================
# UTILITY
# ============================================================================

func cancel_attack() -> void:
	"""Called when enemy is stunned/interrupted"""
	if current_state in [State.BURROW, State.LUNGE]:
		_change_state(State.SURFACE)

		# Restore vulnerability
		if owner_enemy.has_node("HurtboxComponent"):
			var hurtbox = owner_enemy.get_node("HurtboxComponent")
			hurtbox.monitorable = true

		# Restore sprite
		if sprite:
			sprite.visible = true
			sprite.modulate = original_modulate
