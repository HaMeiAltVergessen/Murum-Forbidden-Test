extends Area2D
## Boss Door - Rune-sealed door to boss arena

signal door_unlocked
signal door_entered

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var barrier: StaticBody2D = $Barrier if has_node("Barrier") else null
@onready var light: PointLight2D = $PointLight2D if has_node("PointLight2D") else null
@onready var prompt_label: Label = $PromptLabel if has_node("PromptLabel") else null
@onready var particles: GPUParticles2D = $RuneParticles if has_node("RuneParticles") else null

@export var locked: bool = true
@export var interaction_text: String = "Versiegelt durch uralte Magie"
@export var unlocked_text: String = "[E] Zur Boss-Arena (Lythrun)"
@export var target_scene: String = "res://worlds/world_1_ruins/rooms/room_05_boss_arena.tscn"

var player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if prompt_label:
		prompt_label.visible = false

	_update_door_state()


func _update_door_state() -> void:
	"""Updates door visual based on locked state"""

	if locked:
		# Locked state
		if sprite and sprite.sprite_frames:
			if sprite.sprite_frames.has_animation("locked"):
				sprite.play("locked")

		if barrier:
			barrier.set_collision_layer_value(1, true)

		if light:
			light.color = Color.RED
			light.energy = 0.5

		if particles:
			particles.emitting = true
	else:
		# Unlocked state
		if sprite and sprite.sprite_frames:
			if sprite.sprite_frames.has_animation("open"):
				sprite.play("open")

		if barrier:
			barrier.set_collision_layer_value(1, false)

		if light:
			light.color = Color.GOLD
			light.energy = 1.0

		if particles:
			particles.emitting = false


func lock_door() -> void:
	"""Locks the door"""
	locked = true
	_update_door_state()
	print("[BossDoor] Door locked")


func unlock_door() -> void:
	"""Unlocks the door"""
	locked = false

	# Play unlock animation
	play_unlock_animation()

	door_unlocked.emit()
	print("[BossDoor] Door unlocked")


func play_unlock_animation() -> void:
	"""Plays the unlock animation sequence"""

	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("unlock"):
			sprite.play("unlock")
			await sprite.animation_finished

	_update_door_state()


func is_locked() -> bool:
	"""Returns if door is locked"""
	return locked


func _on_body_entered(body: Node2D) -> void:
	"""Called when a body enters the door area"""

	if body.is_in_group("player"):
		player_in_range = true

		if prompt_label:
			prompt_label.visible = true
			if locked:
				prompt_label.text = interaction_text
			else:
				prompt_label.text = unlocked_text


func _on_body_exited(body: Node2D) -> void:
	"""Called when a body exits the door area"""

	if body.is_in_group("player"):
		player_in_range = false

		if prompt_label:
			prompt_label.visible = false


func _process(_delta: float) -> void:
	"""Handles player interaction"""

	if not player_in_range:
		return

	# CRITICAL: Filter input through InputManager (P1 = keyboard-only when P2 active)
	var interact_pressed = false

	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		# Fallback if InputManager missing
		interact_pressed = Input.is_action_just_pressed("interact")

	if interact_pressed:
		if not locked:
			_enter_boss_arena()
		else:
			_play_locked_feedback()


func _enter_boss_arena() -> void:
	"""Transitions to boss arena"""

	print("[BossDoor] Entering boss arena: ", target_scene)

	door_entered.emit()

	# Disable player input during transition
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("disable_movement"):
		player.disable_movement()

	# Preserve P1 across scene transitions (COMMIT 021 - Co-op)
	if GameManager.player and is_instance_valid(GameManager.player):
		var p1 = GameManager.player

		# Remove P1 from current scene (but don't free it)
		if p1.get_parent():
			p1.get_parent().remove_child(p1)

		# Add P1 to root temporarily (persists across scene change)
		get_tree().root.add_child(p1)

		print("[BossDoor] P1 preserved for boss arena transition")

	# Preserve P2 across scene transitions (COMMIT 021 - Co-op)
	if CoopManager and CoopManager.is_p2_active:
		var p2 = CoopManager.get_p2_instance()
		if p2 and is_instance_valid(p2):
			# Remove P2 from current scene (but don't free it)
			if p2.get_parent():
				p2.get_parent().remove_child(p2)

			# Add P2 to root temporarily (persists across scene change)
			get_tree().root.add_child(p2)

			print("[BossDoor] P2 preserved for boss arena transition")

	# Fade transition (if SceneManager exists)
	if has_node("/root/SceneManager"):
		var scene_manager = get_node("/root/SceneManager")
		if scene_manager.has_method("change_scene"):
			scene_manager.change_scene(target_scene)
			return

	# Fallback: direct scene change
	get_tree().change_scene_to_file(target_scene)


func _play_locked_feedback() -> void:
	"""Plays feedback when trying to open locked door"""

	# Shake animation
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("locked_shake"):
			sprite.play("locked_shake")

	# SFX
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx("door_locked")

	print("[BossDoor] Door is locked")
