extends Area2D
class_name QuicksandPit

## F4 - Treibsand/Abgrund
## Pulls player towards center and deals damage over time
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal player_entered_pit(player: Node2D)
signal player_exited_pit(player: Node2D)
signal player_died_in_pit(player: Node2D)

# ============================================================================
# EXPORTS
# ============================================================================

@export var pull_strength: float = 50.0
@export var damage_per_second: int = 10
@export var instant_death_time: float = 5.0  ## Time until instant death
@export var pit_type: PitType = PitType.QUICKSAND

enum PitType {
	QUICKSAND,   # Sand/earth themed
	ABYSS,       # Void/darkness themed
	LAVA         # Fire/lava themed
}

# ============================================================================
# STATE
# ============================================================================

var players_inside: Dictionary = {}  # player -> time_inside

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var pull_particles: GPUParticles2D = $PullParticles if has_node("PullParticles") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

var damage_timer: Timer = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Godot 4.4: Explicitly set monitoring
	monitoring = true
	monitorable = false

	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Create damage timer
	damage_timer = Timer.new()
	damage_timer.one_shot = false
	damage_timer.wait_time = 1.0
	damage_timer.timeout.connect(_apply_damage)
	add_child(damage_timer)
	damage_timer.start()

	# Start animation if present
	if animated_sprite:
		animated_sprite.play("default")

	# Start particles
	if pull_particles:
		pull_particles.emitting = true

	add_to_group("traps")
	add_to_group("quicksand_pits")

	print("[QuicksandPit] %s initialized, type: %s" % [name, PitType.keys()[pit_type]])

# ============================================================================
# PHYSICS PROCESS - PULL EFFECT
# ============================================================================

func _physics_process(delta: float) -> void:
	"""Apply pull force to players inside"""
	if players_inside.is_empty():
		return

	# Update time for each player
	for player in players_inside.keys():
		if not is_instance_valid(player):
			players_inside.erase(player)
			continue

		# Increment time
		players_inside[player] += delta

		# Check instant death
		if players_inside[player] >= instant_death_time:
			_instant_death(player)
			continue

		# Apply pull force
		_apply_pull_force(player, delta)

func _apply_pull_force(player: Node2D, delta: float) -> void:
	"""Apply pull force towards pit center"""
	if not player is CharacterBody2D:
		return

	# Calculate direction to center
	var pit_center = global_position
	var direction = (pit_center - player.global_position).normalized()

	# Apply force to player velocity
	if player.has("velocity"):
		player.velocity += direction * pull_strength * delta

# ============================================================================
# BODY ENTER/EXIT
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	"""Player enters quicksand"""
	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	# Add to tracking
	players_inside[body] = 0.0

	# Signal
	player_entered_pit.emit(body)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/quicksand_enter", global_position, 0.3)

	print("[QuicksandPit] %s entered by %s" % [name, body.name])

func _on_body_exited(body: Node2D) -> void:
	"""Player exits quicksand"""
	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	# Remove from tracking
	if body in players_inside:
		players_inside.erase(body)

	# Signal
	player_exited_pit.emit(body)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/quicksand_exit", global_position, 0.2)

	print("[QuicksandPit] %s exited by %s" % [name, body.name])

# ============================================================================
# DAMAGE
# ============================================================================

func _apply_damage() -> void:
	"""Apply damage to all players inside (called every second)"""
	if players_inside.is_empty():
		return

	for player in players_inside.keys():
		if not is_instance_valid(player):
			continue

		# Deal damage
		var health_comp = player.get_node_or_null("HealthComponent")
		if health_comp and health_comp.has_method("take_damage"):
			health_comp.take_damage(damage_per_second)
			print("[QuicksandPit] %s dealt %d damage to %s (time: %.1fs)" % [name, damage_per_second, player.name, players_inside[player]])

# ============================================================================
# INSTANT DEATH
# ============================================================================

func _instant_death(player: Node2D) -> void:
	"""Player has been in pit too long - instant death"""
	player_died_in_pit.emit(player)

	# Try to kill player
	if player.has_method("die"):
		player.die()
		print("[QuicksandPit] %s killed %s (instant death)" % [name, player.name])
	else:
		# Fallback: deal massive damage
		var health_comp = player.get_node_or_null("HealthComponent")
		if health_comp and health_comp.has_method("take_damage"):
			health_comp.take_damage(9999)

	# Remove from tracking
	players_inside.erase(player)

# ============================================================================
# HELPERS
# ============================================================================

func get_pit_center() -> Vector2:
	"""Get the center position of the pit"""
	return global_position

func is_player_inside(player: Node2D) -> bool:
	"""Check if player is inside pit"""
	return player in players_inside

func get_time_in_pit(player: Node2D) -> float:
	"""Get how long player has been in pit"""
	return players_inside.get(player, 0.0)
