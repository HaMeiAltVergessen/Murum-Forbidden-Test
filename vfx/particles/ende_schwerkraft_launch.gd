extends GPUParticles2D
## Ende der Schwerkraft Launch - Upward launch particle effect
## Automatically cleans up after emission

func _ready() -> void:
	# One-shot emission
	one_shot = true
	emitting = true

	# Auto-cleanup after particles done
	await get_tree().create_timer(lifetime).timeout
	queue_free()
