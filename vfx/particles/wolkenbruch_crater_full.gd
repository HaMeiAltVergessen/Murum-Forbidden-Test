extends GPUParticles2D
## VFX for full-power Wolkenbruch crater effect

func _ready() -> void:
	# Auto-cleanup after particles finish
	one_shot = true
	emitting = true

	# Queue free after lifetime
	await get_tree().create_timer(lifetime + 0.5).timeout
	queue_free()

func emit_particles() -> void:
	"""Triggers particle emission"""
	emitting = true
