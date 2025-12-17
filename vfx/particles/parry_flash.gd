extends GPUParticles2D
## Parry Flash - One-shot particle effect for perfect parry
## Automatically cleans up after emission

func _ready() -> void:
	# One-shot emission
	one_shot = true
	emitting = true

	# Auto-cleanup after particles done
	await get_tree().create_timer(lifetime).timeout
	queue_free()
