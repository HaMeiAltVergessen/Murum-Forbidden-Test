extends Area2D

## Death Box - Kills player on contact (for out of bounds areas)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Set collision layers
	collision_layer = 0
	collision_mask = 2  # Player layer

func _on_body_entered(body: Node2D) -> void:
	"""Kills player if they fall into death box"""

	if not body.is_in_group("player"):
		return

	# Kill player
	if body.has_method("take_damage"):
		body.take_damage(9999)  # Instant death

	print("[DeathBox] Player fell out of bounds")
