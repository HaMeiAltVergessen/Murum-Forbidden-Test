extends Node2D
## Shadow Abyss Spawn VFX for P2 joining

# ============ REFERENCES ============
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var particles: GPUParticles2D = $Particles if has_node("Particles") else null
@onready var light: PointLight2D = $Light if has_node("Light") else null
@onready var audio: AudioStreamPlayer2D = $Audio if has_node("Audio") else null

# ============ ANIMATION VARIABLES ============
var animation_time: float = 0.0
var is_closing: bool = false

func _ready() -> void:
	"""Initialize the spawn VFX"""
	play_open_animation()

func _process(delta: float) -> void:
	"""Animate the shadow abyss"""
	animation_time += delta

	# Pulsing light effect
	if light:
		light.energy = 0.5 + sin(animation_time * 3.0) * 0.2

	# Pulsing sprite effect
	if sprite and not is_closing:
		var scale_factor = 1.0 + sin(animation_time * 2.0) * 0.1
		sprite.scale = Vector2(scale_factor, scale_factor)

func play_open_animation() -> void:
	"""Play the opening animation"""
	print("[ShadowAbyss] Playing open animation")

	# Enable all effects
	if sprite:
		sprite.visible = true
		sprite.modulate = Color(0.2, 0.1, 0.3, 0.0)

		# Fade in
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 0.5)

	if particles:
		particles.emitting = true

	if light:
		light.enabled = true
		light.energy = 0.0

		# Fade in light
		var tween = create_tween()
		tween.tween_property(light, "energy", 0.5, 0.5)

	if audio:
		audio.play()

func play_close_animation() -> void:
	"""Play the closing animation"""
	print("[ShadowAbyss] Playing close animation")
	is_closing = true

	# Stop particles
	if particles:
		particles.emitting = false

	# Fade out
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.5)

	if light:
		var tween = create_tween()
		tween.tween_property(light, "energy", 0.0, 0.5)
