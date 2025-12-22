extends GPUParticles2D
## Block effect VFX - Auto-cleanup particle effect

func _ready() -> void:
	# Start emitting
	emitting = true

	# Auto-cleanup after lifetime
	await get_tree().create_timer(lifetime + 0.1).timeout
	queue_free()
