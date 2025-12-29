extends Area2D

## Death Box - Kills player on contact (for out of bounds areas)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Set collision layers
	collision_layer = 0
	collision_mask = 6  # Player layer (2) + Enemy layer (4) = 2 + 4 = 6

func _on_body_entered(body: Node2D) -> void:
	"""Kills player or enemies if they fall into death box"""

	# Kill player
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(9999)  # Instant death
		print("[DeathBox] Player fell out of bounds")
		return

	# Kill enemy
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(9999)  # Instant death
		print("[DeathBox] Enemy fell out of bounds")
		return
