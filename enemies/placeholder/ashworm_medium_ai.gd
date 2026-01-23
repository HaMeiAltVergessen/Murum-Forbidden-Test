extends Node
class_name AshwormMediumAI

## AI Controller for Medium Ashworm
## Double-lunge attack pattern
## Godot 4.4 compatible

# ============================================================================
# CONSTANTS
# ============================================================================

const DETECTION_RANGE: float = 900.0
const LUNGE_RANGE: float = 360.0
const CRAWL_SPEED: float = 80.0
const CRAWL_DURATION: float = 2.5
const BURROW_DURATION: float = 0.7
const LUNGE_DURATION: float = 0.3
const SURFACE_DURATION: float = 0.5

# ============================================================================
# STATE
# ============================================================================

enum State {
	IDLE,
	CRAWL,
	BURROW,
	UNDERGROUND,
	LUNGE_1,
	REBURROW,
	LUNGE_2,
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
	target_player = get_tree().get_first_node_in_group("player")
	if not target_player:
		target_player = get_tree().get_first_node_in_group("player2")

	if target_player and owner_enemy:
		CombatManager.register_enemy(owner_enemy)

	print("[AshwormMediumAI] Initialized, target: %s" % (target_player.name if target_player else "none"))

# ============================================================================
# AI UPDATE
# ============================================================================

func _process(delta: float) -> void:
	if not owner_enemy or not target_player:
		if not target_player:
			_find_player()
		return

	if owner_enemy.is_stunned:
		owner_enemy.velocity = Vector2.ZERO
		return

	state_timer += delta

	match current_state:
		State.IDLE:
			_process_idle()
		State.CRAWL:
			_process_crawl(delta)
		State.BURROW:
			_process_burrow()
		State.UNDERGROUND:
			_process_underground()
		State.LUNGE_1:
			_process_lunge(delta, true)
		State.REBURROW:
			_process_reburrow()
		State.LUNGE_2:
			_process_lunge(delta, false)
		State.SURFACE:
			_process_surface()

# ============================================================================
# STATE PROCESSING
# ============================================================================

func _process_idle() -> void:
	var distance = owner_enemy.global_position.distance_to(target_player.global_position)
	if distance <= DETECTION_RANGE:
		_change_state(State.CRAWL)

func _process_crawl(_delta: float) -> void:
	var distance = owner_enemy.global_position.distance_to(target_player.global_position)

	if distance <= LUNGE_RANGE or state_timer >= CRAWL_DURATION:
		_change_state(State.BURROW)
		return

	var direction = (target_player.global_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity = direction * CRAWL_SPEED
	owner_enemy.move_and_slide()

	if sprite and "flip_h" in sprite:
		sprite.flip_h = direction.x < 0

func _process_burrow() -> void:
	owner_enemy.velocity = Vector2.ZERO

	if sprite and state_timer < BURROW_DURATION:
		sprite.modulate.a = 1.0 - (state_timer / BURROW_DURATION)

	if state_timer >= BURROW_DURATION:
		_change_state(State.UNDERGROUND)

func _process_underground() -> void:
	owner_enemy.velocity = Vector2.ZERO

	if owner_enemy.has_node("HurtboxComponent"):
		owner_enemy.get_node("HurtboxComponent").monitorable = false

	if sprite:
		sprite.visible = false

	lunge_target_position = target_player.global_position

	if state_timer >= 0.2:
		_change_state(State.LUNGE_1)

func _process_lunge(_delta: float, is_first_lunge: bool) -> void:
	var direction = (lunge_target_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity = direction * 350.0
	owner_enemy.move_and_slide()

	if sprite:
		sprite.visible = true
		sprite.modulate.a = min(1.0, state_timer / LUNGE_DURATION)

	if owner_enemy.has_node("HitboxComponent"):
		owner_enemy.get_node("HitboxComponent").monitoring = true

	if state_timer == 0 and AudioManager:
		AudioManager.play_sfx("enemies/geist_attack", 0.15)

	if state_timer >= LUNGE_DURATION:
		if is_first_lunge:
			_change_state(State.REBURROW)
		else:
			_change_state(State.SURFACE)

func _process_reburrow() -> void:
	owner_enemy.velocity = Vector2.ZERO

	if sprite and state_timer < 0.3:
		sprite.modulate.a = 1.0 - (state_timer / 0.3)

	if state_timer >= 0.3:
		# Go underground and prepare second lunge from player's direction
		if sprite:
			sprite.visible = false

		if owner_enemy.has_node("HitboxComponent"):
			owner_enemy.get_node("HitboxComponent").monitoring = false

		# Teleport behind/around player for second lunge
		var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		lunge_target_position = target_player.global_position + offset

		if state_timer >= 0.5:
			_change_state(State.LUNGE_2)

func _process_surface() -> void:
	owner_enemy.velocity = Vector2.ZERO

	if owner_enemy.has_node("HurtboxComponent"):
		owner_enemy.get_node("HurtboxComponent").monitorable = true

	if owner_enemy.has_node("HitboxComponent"):
		owner_enemy.get_node("HitboxComponent").monitoring = false

	if sprite:
		sprite.visible = true
		sprite.modulate = original_modulate

	if state_timer >= SURFACE_DURATION:
		_change_state(State.CRAWL)

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _change_state(new_state: State) -> void:
	current_state = new_state
	state_timer = 0.0

	match new_state:
		State.BURROW:
			if AudioManager:
				AudioManager.play_sfx("enemies/geist_hurt", 0.1)
		State.LUNGE_1:
			print("[AshwormMediumAI] LUNGE 1")
		State.LUNGE_2:
			print("[AshwormMediumAI] LUNGE 2 (combo!)")

func cancel_attack() -> void:
	if current_state in [State.BURROW, State.LUNGE_1, State.LUNGE_2]:
		_change_state(State.SURFACE)
		if owner_enemy.has_node("HurtboxComponent"):
			owner_enemy.get_node("HurtboxComponent").monitorable = true
		if sprite:
			sprite.visible = true
			sprite.modulate = original_modulate
