extends Area2D
class_name ShadowTendril

## F3.3 - Schattenranke (W3 Kosmischer Horror)
## Grabs from wall/floor, holds player (4x attack to escape), P2 can help
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal tendril_emerged()
signal tendril_grabbed(player: Node2D)
signal tendril_released(player: Node2D)
signal tendril_destroyed()
signal tendril_retreated()

# ============================================================================
# ENUMS
# ============================================================================

enum State {
	HIDDEN,       # Invisible, waiting for player
	EMERGING,     # Warning animation, emerging
	STRIKING,     # Lunging at player
	GRABBING,     # Holding player
	RETREATING,   # Pulling back after grab/miss
	COOLDOWN      # Waiting to reset
}

# ============================================================================
# EXPORTS
# ============================================================================

@export var damage_hit: int = 15            ## Damage on miss (strike hit)
@export var damage_grab_per_second: int = 5  ## DoT while grabbed
@export var grab_hits_to_escape: int = 4     ## Attack presses to break free
@export var grab_hp: int = 15               ## HP for P2 to destroy grab
@export var auto_release_time: float = 3.0   ## Max grab time (safety)
@export var trigger_range: float = 150.0
@export var cooldown: float = 5.0
@export var knockback_force: float = 200.0

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.HIDDEN
var grabbed_player: Node2D = null
var escape_progress: int = 0
var grab_time: float = 0.0
var current_grab_hp: int = 0

# ============================================================================
# REFERENCES
# ============================================================================

@onready var tendril_visual: AnimatedSprite2D = $TendrilVisual if has_node("TendrilVisual") else null
@onready var crack_visual: Node2D = $CrackVisual if has_node("CrackVisual") else null
@onready var grab_hitbox: Area2D = $GrabHitbox if has_node("GrabHitbox") else null
@onready var hurtbox_area: Area2D = $HurtboxArea if has_node("HurtboxArea") else null
@onready var escape_label: Label = $EscapeLabel if has_node("EscapeLabel") else null

var grab_damage_timer: Timer = null
var cooldown_timer: Timer = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Main detection area (trigger range)
	monitoring = true
	monitorable = false

	collision_layer = 0
	set_collision_layer_value(7, true)
	collision_mask = 0
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)

	body_entered.connect(_on_trigger_body_entered)

	# Set trigger range
	var shape = get_node_or_null("CollisionShape2D")
	if shape and shape.shape is CircleShape2D:
		shape.shape.radius = trigger_range

	# Grab hitbox (for striking)
	if grab_hitbox:
		grab_hitbox.monitoring = false
		grab_hitbox.monitorable = false
		grab_hitbox.body_entered.connect(_on_strike_hit)

		grab_hitbox.collision_layer = 0
		grab_hitbox.set_collision_layer_value(7, true)
		grab_hitbox.collision_mask = 0
		grab_hitbox.set_collision_mask_value(2, true)
		grab_hitbox.set_collision_mask_value(3, true)

	# Hurtbox (P2 can attack to free P1)
	if hurtbox_area:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false
		hurtbox_area.area_entered.connect(_on_tendril_hit_by_attack)

		hurtbox_area.collision_layer = 0
		hurtbox_area.set_collision_layer_value(4, true)   # Enemy layer
		hurtbox_area.collision_mask = 0
		hurtbox_area.set_collision_mask_value(16, true)   # Hitbox layer

	# Grab damage timer
	grab_damage_timer = Timer.new()
	grab_damage_timer.one_shot = false
	grab_damage_timer.wait_time = 1.0
	grab_damage_timer.timeout.connect(_apply_grab_damage)
	add_child(grab_damage_timer)

	# Cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = cooldown
	cooldown_timer.timeout.connect(_on_cooldown_end)
	add_child(cooldown_timer)

	# Hide visuals initially
	if tendril_visual:
		tendril_visual.visible = false
	if crack_visual:
		crack_visual.visible = false
	if escape_label:
		escape_label.visible = false

	add_to_group("traps")
	add_to_group("shadow_tendrils")

	print("[ShadowTendril] %s initialized (grab HP: %d, escape hits: %d)" % [name, grab_hp, grab_hits_to_escape])

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	if current_state == State.GRABBING and grabbed_player:
		grab_time += delta

		# Auto-release safety
		if grab_time >= auto_release_time:
			_release_player()
			return

		# Keep player locked in place
		if is_instance_valid(grabbed_player):
			grabbed_player.global_position = global_position + Vector2(0, -20)
			if grabbed_player is CharacterBody2D:
				grabbed_player.velocity = Vector2.ZERO

		# Update escape label
		if escape_label:
			escape_label.text = "%d/%d" % [escape_progress, grab_hits_to_escape]

	# Tendril pulse when grabbing
	if current_state == State.GRABBING and tendril_visual:
		var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.2 + 0.8
		tendril_visual.modulate.a = pulse

func _input(event: InputEvent) -> void:
	if current_state != State.GRABBING or not grabbed_player:
		return

	# Check attack input from grabbed player
	var is_p1 = grabbed_player.is_in_group("player")
	var attack_action = "p1_attack" if is_p1 else "p2_attack"

	if event.is_action_pressed(attack_action):
		escape_progress += 1
		print("[ShadowTendril] Escape progress: %d/%d" % [escape_progress, grab_hits_to_escape])

		# Visual feedback
		if tendril_visual:
			var tween = create_tween()
			tween.tween_property(tendril_visual, "modulate", Color(2.0, 2.0, 2.0), 0.05)
			tween.tween_property(tendril_visual, "modulate", Color(0.3, 0.0, 0.4), 0.1)

		if escape_progress >= grab_hits_to_escape:
			_release_player()

# ============================================================================
# TRIGGER
# ============================================================================

func _on_trigger_body_entered(body: Node2D) -> void:
	if current_state != State.HIDDEN:
		return

	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	_start_emerge(body)

# ============================================================================
# EMERGE
# ============================================================================

func _start_emerge(target: Node2D) -> void:
	current_state = State.EMERGING

	# Show crack
	if crack_visual:
		crack_visual.visible = true
		crack_visual.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(crack_visual, "modulate:a", 1.0, 0.15)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/tendril_crack", global_position, 0.2)

	tendril_emerged.emit()

	# Short delay then strike
	await get_tree().create_timer(0.3).timeout
	if current_state == State.EMERGING:
		_strike()

func _strike() -> void:
	"""Tendril lunges out"""
	current_state = State.STRIKING

	# Show tendril
	if tendril_visual:
		tendril_visual.visible = true
		tendril_visual.scale.y = 0.0
		var tween = create_tween()
		tween.tween_property(tendril_visual, "scale:y", 1.0, 0.15).set_ease(Tween.EASE_OUT)

	# Enable grab hitbox briefly
	if grab_hitbox:
		grab_hitbox.monitoring = true

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/tendril_strike", global_position, 0.3)

	# Check for hit after short window
	await get_tree().create_timer(0.2).timeout

	# If didn't grab anyone, check for direct hit
	if current_state == State.STRIKING:
		# Try to hit players in grab area
		if grab_hitbox:
			var hit_someone = false
			for body in grab_hitbox.get_overlapping_bodies():
				if body.is_in_group("player") or body.is_in_group("player2"):
					_grab_player(body)
					hit_someone = true
					break

			if not hit_someone:
				# Miss — retreat
				if grab_hitbox:
					grab_hitbox.monitoring = false
				_start_retreat()

# ============================================================================
# GRAB
# ============================================================================

func _on_strike_hit(body: Node2D) -> void:
	"""Body enters grab zone during strike"""
	if current_state != State.STRIKING:
		return

	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	_grab_player(body)

func _grab_player(player: Node2D) -> void:
	"""Grab and hold player"""
	current_state = State.GRABBING
	grabbed_player = player
	escape_progress = 0
	grab_time = 0.0
	current_grab_hp = grab_hp

	if grab_hitbox:
		grab_hitbox.monitoring = false

	# Lock player movement
	if "movement_locked" in player:
		player.movement_locked = true
	elif "can_move" in player:
		player.can_move = false

	# Enable hurtbox (P2 can attack tendril)
	if hurtbox_area:
		hurtbox_area.monitoring = true
		hurtbox_area.monitorable = true

	# Show escape label
	if escape_label:
		escape_label.visible = true
		escape_label.text = "0/%d" % grab_hits_to_escape

	# Start DoT
	grab_damage_timer.start()

	tendril_grabbed.emit(player)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/tendril_grab", global_position, 0.35)

	print("[ShadowTendril] %s grabbed %s" % [name, player.name])

func _release_player() -> void:
	"""Release grabbed player"""
	if not grabbed_player:
		return

	var player = grabbed_player

	# Unlock movement
	if is_instance_valid(player):
		if "movement_locked" in player:
			player.movement_locked = false
		elif "can_move" in player:
			player.can_move = true

		# Knockback away
		var knockback_dir = (player.global_position - global_position).normalized()
		if knockback_dir.length() < 0.1:
			knockback_dir = Vector2.UP
		if player is CharacterBody2D:
			player.velocity = knockback_dir * knockback_force

	grabbed_player = null
	grab_damage_timer.stop()

	# Hide hurtbox
	if hurtbox_area:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false

	# Hide escape label
	if escape_label:
		escape_label.visible = false

	tendril_released.emit(player)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/tendril_release", global_position, 0.25)

	print("[ShadowTendril] %s released player" % name)

	_start_retreat()

# ============================================================================
# P2 HELP — ATTACK TENDRIL TO FREE PARTNER
# ============================================================================

func _on_tendril_hit_by_attack(area: Area2D) -> void:
	"""P2 attacks tendril to free P1"""
	if current_state != State.GRABBING:
		return

	if not (area.is_in_group("hitbox") or area.name == "HitboxComponent" or "hitbox" in area.name.to_lower()):
		return

	# Get damage
	var hit_damage = 10
	if area.has_method("get_damage"):
		hit_damage = area.get_damage()
	elif "damage" in area:
		hit_damage = area.damage

	current_grab_hp -= hit_damage

	# Visual feedback
	if tendril_visual:
		var tween = create_tween()
		tween.tween_property(tendril_visual, "modulate", Color(2.0, 0.5, 0.5), 0.05)
		tween.tween_property(tendril_visual, "modulate", Color(0.3, 0.0, 0.4), 0.1)

	print("[ShadowTendril] Tendril hit! HP: %d" % current_grab_hp)

	if current_grab_hp <= 0:
		tendril_destroyed.emit()
		_release_player()

# ============================================================================
# GRAB DAMAGE
# ============================================================================

func _apply_grab_damage() -> void:
	"""Apply DoT while player is grabbed"""
	if current_state != State.GRABBING or not grabbed_player:
		return

	if not is_instance_valid(grabbed_player):
		_release_player()
		return

	var health_comp = grabbed_player.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(damage_grab_per_second)

# ============================================================================
# RETREAT
# ============================================================================

func _start_retreat() -> void:
	"""Tendril retreats back"""
	current_state = State.RETREATING

	# Visual: shrink back
	if tendril_visual:
		var tween = create_tween()
		tween.tween_property(tendril_visual, "scale:y", 0.0, 0.3)
		tween.tween_callback(func(): tendril_visual.visible = false)

	if crack_visual:
		var tween = create_tween()
		tween.tween_property(crack_visual, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): crack_visual.visible = false)

	tendril_retreated.emit()

	# Enter cooldown
	current_state = State.COOLDOWN
	cooldown_timer.start()

func _on_cooldown_end() -> void:
	"""Ready to trigger again"""
	current_state = State.HIDDEN
	print("[ShadowTendril] %s ready" % name)
