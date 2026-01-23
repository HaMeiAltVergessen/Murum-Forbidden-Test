extends Node
class_name AshwormLargeAI

## AI Controller for Large Ashworm
## AoE ground wave attack
## Godot 4.4 compatible

# ============================================================================
# CONSTANTS
# ============================================================================

const DETECTION_RANGE: float = 1050.0
const AOE_RANGE: float = 750.0
const CRAWL_SPEED: float = 100.0
const CRAWL_DURATION: float = 2.0
const BURROW_DURATION: float = 1.0
const TELEGRAPH_DURATION: float = 0.5
const LUNGE_DURATION: float = 0.4
const VULNERABLE_DURATION: float = 1.5

# ============================================================================
# STATE
# ============================================================================

enum State {
	IDLE,
	CRAWL,
	BURROW,
	UNDERGROUND,
	TELEGRAPH,
	AOE_LUNGE,
	VULNERABLE
}

var current_state: State = State.IDLE
var state_timer: float = 0.0
var aoe_center: Vector2 = Vector2.ZERO

# ============================================================================
# REFERENCES
# ============================================================================

var owner_enemy: CharacterBody2D
var target_player: CharacterBody2D
var sprite: Sprite2D
var original_modulate: Color

# Visual effect nodes (created dynamically)
var telegraph_circles: Array[Node2D] = []

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

	print("[AshwormLargeAI] Initialized, target: %s" % (target_player.name if target_player else "none"))

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
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.AOE_LUNGE:
			_process_aoe_lunge(delta)
		State.VULNERABLE:
			_process_vulnerable()

# ============================================================================
# STATE PROCESSING
# ============================================================================

func _process_idle() -> void:
	var distance = owner_enemy.global_position.distance_to(target_player.global_position)
	if distance <= DETECTION_RANGE:
		_change_state(State.CRAWL)

func _process_crawl(_delta: float) -> void:
	var distance = owner_enemy.global_position.distance_to(target_player.global_position)

	if distance <= AOE_RANGE or state_timer >= CRAWL_DURATION:
		_change_state(State.BURROW)
		return

	var direction = (target_player.global_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity.x = direction.x * CRAWL_SPEED
	# Note: gravity applied in _physics_process

	if sprite and "flip_h" in sprite:
		sprite.flip_h = direction.x < 0

func _process_burrow() -> void:
	owner_enemy.velocity = Vector2.ZERO

	# Large burrow: Move down + shake effect (ground crack)
	if sprite and state_timer < BURROW_DURATION:
		var burrow_progress = state_timer / BURROW_DURATION
		sprite.position.y = burrow_progress * 140.0  # Move 140px down (large sized)

		# Shake effect (ground rumble)
		if int(state_timer * 20) % 2 == 0:
			sprite.position.x = randf_range(-3, 3)
		else:
			sprite.position.x = 0

	if state_timer >= BURROW_DURATION:
		if sprite:
			sprite.position.x = 0  # Stop shake
		_change_state(State.UNDERGROUND)

func _process_underground() -> void:
	owner_enemy.velocity = Vector2.ZERO

	if owner_enemy.has_node("HurtboxComponent"):
		owner_enemy.get_node("HurtboxComponent").monitorable = false

	# Keep sprite underground
	if sprite:
		sprite.position.y = 140.0
		sprite.position.x = 0

	aoe_center = target_player.global_position

	if state_timer >= 0.3:
		_change_state(State.TELEGRAPH)

func _process_telegraph(_delta: float) -> void:
	# Create expanding warning lines
	if telegraph_circles.is_empty():
		_create_telegraph_circles()

	# Animate lines as expanding thin rings
	for i in range(telegraph_circles.size()):
		var line = telegraph_circles[i]
		if line:
			var t = (state_timer / TELEGRAPH_DURATION) + (i * 0.15)  # Stagger each ring
			t = clamp(t, 0.0, 1.0)
			var current_radius = lerp(0.0, float(AOE_RANGE), t)

			# Thin line expanding from center (only 3px thick)
			var line_thickness = 3.0
			line.size = Vector2(current_radius * 2, line_thickness)
			line.position = aoe_center - Vector2(current_radius, line_thickness / 2)
			line.modulate.a = 0.6 - (t * 0.5)  # Fade out as expanding

	if state_timer >= TELEGRAPH_DURATION:
		_clear_telegraph_circles()
		_change_state(State.AOE_LUNGE)

func _process_aoe_lunge(_delta: float) -> void:
	# Massive jump from underground
	if state_timer == 0:
		# Camera shake
		_apply_camera_shake(0.4)

		# Audio
		if AudioManager:
			AudioManager.play_sfx("enemies/geist_death", 0.2)  # Placeholder impact sound

	# Sprite bursts from underground (140px → 0px)
	if sprite:
		var emerge_progress = min(1.0, state_timer / 0.2)
		sprite.position.y = lerp(140.0, 0.0, emerge_progress)
		sprite.position.x = 0

	# Deal AoE damage
	if state_timer >= 0.1 and state_timer < 0.15:
		_deal_aoe_damage()

	if state_timer >= LUNGE_DURATION:
		_change_state(State.VULNERABLE)

func _process_vulnerable() -> void:
	owner_enemy.velocity = Vector2.ZERO

	# Make fully vulnerable
	if owner_enemy.has_node("HurtboxComponent"):
		owner_enemy.get_node("HurtboxComponent").monitorable = true

	if sprite:
		sprite.position.y = 0.0  # Keep at ground level
		sprite.modulate = original_modulate

		# Stagger animation (slight shake)
		if int(state_timer * 10) % 2 == 0:
			sprite.position.x = randf_range(-1, 1)
		else:
			sprite.position.x = 0

	if state_timer >= VULNERABLE_DURATION:
		if sprite:
			sprite.position = Vector2.ZERO
		_change_state(State.CRAWL)

# ============================================================================
# AOE MECHANICS
# ============================================================================

func _create_telegraph_circles() -> void:
	"""Creates visual telegraph warning lines (thin rings)"""
	for i in range(3):
		var line = ColorRect.new()
		line.size = Vector2(4, 4)  # Thin line, will be scaled
		line.position = aoe_center - Vector2(2, 2)  # Center on target
		line.color = Color(1, 0, 0, 0.5 - i * 0.15)  # Fade each ring
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_tree().root.add_child(line)
		telegraph_circles.append(line)

func _clear_telegraph_circles() -> void:
	"""Removes telegraph circles"""
	for circle in telegraph_circles:
		if is_instance_valid(circle):
			circle.queue_free()
	telegraph_circles.clear()

func _deal_aoe_damage() -> void:
	"""Deals damage to players in AoE range"""
	var players = get_tree().get_nodes_in_group("player")
	players.append_array(get_tree().get_nodes_in_group("player2"))

	for player in players:
		if not is_instance_valid(player):
			continue

		var distance = aoe_center.distance_to(player.global_position)
		if distance <= AOE_RANGE:
			# Knockback
			var knockback_dir = (player.global_position - aoe_center).normalized()
			if player is CharacterBody2D:
				player.velocity = knockback_dir * 400.0
				player.velocity.y = -250.0  # Upward pop

			# Damage via hurtbox
			var hurtbox = player.get_node_or_null("HurtboxComponent")
			if hurtbox and hurtbox.has_method("take_damage"):
				hurtbox.take_damage(25, knockback_dir * 400.0, 0.4)
				print("[AshwormLargeAI] AoE hit %s (distance: %.1f)" % [player.name, distance])

func _apply_camera_shake(trauma: float) -> void:
	"""Apply camera shake"""
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.has_node("PlayerCamera"):
			player.get_node("PlayerCamera").add_trauma(trauma)

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _change_state(new_state: State) -> void:
	current_state = new_state
	state_timer = 0.0

	match new_state:
		State.BURROW:
			print("[AshwormLargeAI] BURROW (ground crack)")
			if AudioManager:
				AudioManager.play_sfx("enemies/geist_hurt", 0.15)
		State.TELEGRAPH:
			print("[AshwormLargeAI] TELEGRAPH (expanding circles)")
		State.AOE_LUNGE:
			print("[AshwormLargeAI] AoE LUNGE (massive impact)")
		State.VULNERABLE:
			print("[AshwormLargeAI] VULNERABLE (stagger window)")

func cancel_attack() -> void:
	if current_state in [State.BURROW, State.TELEGRAPH, State.AOE_LUNGE]:
		_clear_telegraph_circles()
		_change_state(State.VULNERABLE)
		if owner_enemy.has_node("HurtboxComponent"):
			owner_enemy.get_node("HurtboxComponent").monitorable = true
		if sprite:
			sprite.visible = true
			sprite.modulate = original_modulate
