extends Node
## VictorySequence — Handles the dramatic visual sequence after a boss is defeated.
## Game logic (Magicka, healing, progression) is handled by run_node_room.
class_name VictorySequence

signal sequence_started
signal sequence_completed

# ============ CONFIGURATION ============
@export var boss: Node2D
@export var unlock_flag: String = ""

## Timing (seconds)
@export_group("Timing")
@export var hitstop_duration: float = 0.3
@export var slowmo_scale: float = 0.3
@export var slowmo_duration: float = 2.0
@export var dissolve_duration: float = 1.5
@export var post_defeat_wait: float = 1.0

## Visual options
@export_group("Visuals")
@export var flash_color: Color = Color(2.0, 2.0, 2.0, 1.0)
@export var shake_intensity: float = 12.0
@export var shake_duration: float = 0.8
@export var death_vfx_count: int = 3
@export var death_vfx_spread: float = 80.0

# ============ PRELOADS ============
const DEATH_VFX_SCENE: PackedScene = preload("res://vfx/boss/boss_death_explosion.tscn")

# ============ STATE ============
var _is_running: bool = false


func start() -> void:
	"""Starts the full victory sequence. Call after boss HP reaches 0."""
	if _is_running:
		return
	_is_running = true
	sequence_started.emit()
	print("[VictorySequence] Starting for boss: ", boss.name if boss and is_instance_valid(boss) else "Unknown")

	if not boss or not is_instance_valid(boss):
		print("[VictorySequence] ERROR: Boss is null or invalid, skipping")
		_finish()
		return

	# 1. Hitstop — dramatic freeze on the killing blow
	if GlobalTimeEffects:
		GlobalTimeEffects.hit_stop(hitstop_duration)
	await get_tree().create_timer(hitstop_duration, true, false, true).timeout

	# 2. Slow motion — dramatic defeat unfolds
	if GlobalTimeEffects:
		GlobalTimeEffects.slow_motion(slowmo_scale, slowmo_duration)

	# 3. Focus camera on boss
	_focus_camera()

	# 4. Play boss death animation (override in child or use default dissolve)
	await _play_death_animation()

	# 5. White flash on boss
	_flash_boss()

	await get_tree().create_timer(0.3).timeout

	# 6. Death VFX — multiple staggered explosions
	_spawn_death_vfx()

	# 7. Camera shake
	_shake_camera()

	await get_tree().create_timer(0.5).timeout

	# 8. Dissolve boss sprite
	await _dissolve_boss()

	# 9. Set unlock flag
	if not unlock_flag.is_empty() and GameManager:
		GameManager.set_flag(unlock_flag, true)

	# 10. Post-defeat pause
	await get_tree().create_timer(post_defeat_wait).timeout

	# 11. Deactivate boss camera
	_deactivate_camera()

	_finish()


func start_minimal() -> void:
	"""Lightweight victory for group bosses (HeroGroup/Kollektiv).
	Skips death animation — just VFX, hitstop, and dissolve."""
	if _is_running:
		return
	_is_running = true
	sequence_started.emit()

	if not boss or not is_instance_valid(boss):
		_finish()
		return

	# Hitstop
	if GlobalTimeEffects:
		GlobalTimeEffects.hit_stop(hitstop_duration)
	await get_tree().create_timer(hitstop_duration, true, false, true).timeout

	# Slowmo
	if GlobalTimeEffects:
		GlobalTimeEffects.slow_motion(slowmo_scale, slowmo_duration * 0.7)

	# Flash + VFX + Shake
	_flash_boss()
	await get_tree().create_timer(0.2).timeout
	_spawn_death_vfx()
	_shake_camera()

	# Dissolve
	await _dissolve_boss()

	await get_tree().create_timer(post_defeat_wait * 0.5).timeout

	_finish()


# ============ DEATH ANIMATION ============
func _play_death_animation() -> void:
	"""Plays boss death animation if available, otherwise waits briefly."""
	if boss and is_instance_valid(boss) and boss.has_method("play_death_animation"):
		await boss.play_death_animation()
	else:
		await get_tree().create_timer(0.5).timeout


# ============ VISUAL EFFECTS ============
func _flash_boss() -> void:
	"""White flash on the boss sprite at moment of death."""
	if not boss or not is_instance_valid(boss):
		return

	var sprite: Node = _get_boss_sprite()
	if not sprite:
		return

	var original_modulate: Color = sprite.modulate
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", flash_color, 0.05)
	tween.tween_property(sprite, "modulate", original_modulate, 0.25)


func _spawn_death_vfx() -> void:
	"""Spawns staggered explosion particles around the boss."""
	if not boss or not is_instance_valid(boss):
		return

	var base_pos: Vector2 = boss.global_position
	var scene_root: Node = get_tree().current_scene

	for i in range(death_vfx_count):
		var offset := Vector2(
			randf_range(-death_vfx_spread, death_vfx_spread),
			randf_range(-death_vfx_spread, death_vfx_spread)
		)

		var vfx: GPUParticles2D = DEATH_VFX_SCENE.instantiate()
		scene_root.add_child(vfx)
		vfx.global_position = base_pos + offset

		# Stagger each explosion slightly
		if i < death_vfx_count - 1:
			await get_tree().create_timer(0.15).timeout

	print("[VictorySequence] Death VFX spawned: %d explosions" % death_vfx_count)


func _dissolve_boss() -> void:
	"""Fades the boss sprite to transparent."""
	if not boss or not is_instance_valid(boss):
		return

	var sprite: Node = _get_boss_sprite()
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, dissolve_duration)
		await tween.finished
	else:
		# No sprite found — just wait the dissolve time
		await get_tree().create_timer(dissolve_duration).timeout


# ============ CAMERA ============
func _focus_camera() -> void:
	"""Zooms camera towards boss."""
	if not boss or not is_instance_valid(boss):
		return

	var camera_ctrl := _get_camera_controller()
	if camera_ctrl:
		camera_ctrl.focus_on_boss(0.5)


func _shake_camera() -> void:
	"""Screen shake on death explosion."""
	if not boss or not is_instance_valid(boss):
		return

	var camera_ctrl := _get_camera_controller()
	if camera_ctrl:
		camera_ctrl.shake(shake_intensity, shake_duration)


func _deactivate_camera() -> void:
	"""Returns camera control to normal."""
	if not boss or not is_instance_valid(boss):
		return

	var camera_ctrl := _get_camera_controller()
	if camera_ctrl:
		camera_ctrl.deactivate()


func _get_camera_controller() -> BossCameraController:
	if boss.has_node("Components/BossCameraController"):
		return boss.get_node("Components/BossCameraController")
	# Also check direct children (for group bosses that aren't BaseBoss)
	if boss.has_node("BossCameraController"):
		return boss.get_node("BossCameraController")
	return null


# ============ HELPERS ============
func _get_boss_sprite() -> Node:
	"""Finds the boss sprite node (Sprite2D or AnimatedSprite2D)."""
	if not boss or not is_instance_valid(boss):
		return null

	# Try common names first
	for name in ["Sprite2D", "AnimatedSprite2D", "BossSprite"]:
		var node := boss.get_node_or_null(name)
		if node:
			return node

	# Search children
	for child in boss.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child

	return null


func _finish() -> void:
	_is_running = false
	sequence_completed.emit()
	print("[VictorySequence] Sequence completed")
