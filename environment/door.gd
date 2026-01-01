extends Area2D
## Simple door that loads a target scene

@export var target_scene: String = "res://levels/test_room.tscn"
@export var spawn_position: Vector2 = Vector2(300, 950)

var player_in_area: bool = false
var prompt_label: Label = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Find prompt label
	if has_node("PromptLabel"):
		prompt_label = get_node("PromptLabel")
	elif has_node("DoorLabel"):
		prompt_label = get_node("DoorLabel")


func _process(_delta: float) -> void:
	if player_in_area and Input.is_action_just_pressed("interact"):
		_load_scene()


func _on_body_entered(body: Node2D) -> void:
	if body is Murum:
		player_in_area = true
		if prompt_label:
			var scene_name = target_scene.get_file().get_basename()
			prompt_label.text = "E - Enter " + scene_name


func _on_body_exited(body: Node2D) -> void:
	if body is Murum:
		player_in_area = false
		if prompt_label:
			var scene_name = target_scene.get_file().get_basename()
			prompt_label.text = scene_name


func _load_scene() -> void:
	print("[Door] Loading scene: ", target_scene)

	# Play door SFX
	AudioManager.play_sfx("door_open")

	# Store spawn position in GameManager
	GameManager.player_spawn_position = spawn_position

	# Preserve player across scene transitions
	if GameManager.player and is_instance_valid(GameManager.player):
		var player = GameManager.player

		# Remove player from current scene (but don't free it)
		if player.get_parent():
			player.get_parent().remove_child(player)

		# Add player to root temporarily (persists across scene change)
		get_tree().root.add_child(player)

		print("[Door] Player preserved for transition to ", target_scene)

	# Change scene
	get_tree().change_scene_to_file(target_scene)

	# GameManager will handle repositioning via scene_changed signal
