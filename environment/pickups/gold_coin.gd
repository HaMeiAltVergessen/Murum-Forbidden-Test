extends Area2D
class_name GoldCoin

## Gold coin pickup that adds currency to player

# ============================================================================
# EXPORTS
# ============================================================================

@export var gold_value: int = 1
@export var pickup_radius: float = 60.0
@export var magnet_speed: float = 300.0

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# ============================================================================
# STATE
# ============================================================================

var player: Node2D = null
var is_being_attracted: bool = false
var lifetime: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect signals
	body_entered.connect(_on_body_entered)

	# Add to group
	add_to_group("pickups")
	add_to_group("gold_coins")

	# Spawn animation
	_play_spawn_animation()

	# Set collision layers
	collision_layer = 0  # Don't collide with anything
	collision_mask = 2   # Detect player (layer 2)

	print("[GoldCoin] Spawned with value: %d" % gold_value)

# ============================================================================
# PHYSICS
# ============================================================================

func _physics_process(delta: float) -> void:
	lifetime += delta

	# Auto-despawn after 30 seconds
	if lifetime > 30.0:
		_despawn()
		return

	# Check for nearby player
	if not is_being_attracted:
		_check_for_player()

	# Move towards player if attracted
	if is_being_attracted and player and is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		global_position += direction * magnet_speed * delta

		# Check if close enough to collect
		if global_position.distance_to(player.global_position) < 20.0:
			_collect()

func _check_for_player() -> void:
	"""Checks for nearby player to attract coin"""

	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		return

	var distance = global_position.distance_to(player_node.global_position)

	if distance < pickup_radius:
		player = player_node
		is_being_attracted = true

# ============================================================================
# COLLECTION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	"""Called when player touches coin"""

	if not body.is_in_group("player"):
		return

	_collect()

func _collect() -> void:
	"""Collects the coin and adds gold to player"""

	# Add gold to GameManager
	GameManager.add_coins(gold_value)

	# Visual/audio feedback
	_play_collect_effects()

	# Emit signal
	EventBus.show_notification.emit("+%d Gold" % gold_value, 1.5)

	print("[GoldCoin] Collected: %d gold" % gold_value)

	# Remove coin
	queue_free()

# ============================================================================
# EFFECTS
# ============================================================================

func _play_spawn_animation() -> void:
	"""Plays spawn animation"""

	if not sprite:
		return

	# Pop-in effect
	sprite.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _play_collect_effects() -> void:
	"""Plays collection effects"""

	# Audio
	if AudioManager:
		AudioManager.play_sfx("pickup_coin", 0.1)

	# Visual sparkle (simple scale/fade)
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.2)

func _despawn() -> void:
	"""Despawns coin with fade"""

	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		await tween.finished

	queue_free()
	print("[GoldCoin] Despawned (timeout)")
