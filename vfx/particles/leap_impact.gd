extends GPUParticles2D
## Leap Impact VFX - Auto-cleanup particle effect for leap ender

func _ready() -> void:
	# Start emitting
	emitting = true

	# Auto-cleanup after lifetime
	await get_tree().create_timer(lifetime + 0.1).timeout
	queue_free()
