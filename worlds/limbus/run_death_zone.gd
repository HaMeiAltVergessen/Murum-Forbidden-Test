extends Area2D
## Run Death Zone - Kills the player during a run (triggers RunManager death flow)
## Colored red for visibility in test rooms

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2  # Player layer


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Murum":
		_kill_player(body)


func _kill_player(player: Node2D) -> void:
	print("[RunDeathZone] Player entered death zone")

	# Try HealthComponent first (Murum uses this)
	if player.has_node("HealthComponent"):
		var hc = player.get_node("HealthComponent")
		if hc.has_method("take_damage"):
			hc.take_damage(hc.max_health + 1)
			return

	# Fallback: direct take_damage on player
	if player.has_method("take_damage"):
		player.take_damage(9999)
		return

	# Last resort: emit death signal directly
	EventBus.player_died.emit()
