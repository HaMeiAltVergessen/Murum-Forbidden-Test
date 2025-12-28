extends Area2D
## Simple door that loads a target scene

@export var target_scene: String = "res://levels/test_room.tscn"
@export var spawn_position: Vector2 = Vector2(300, 950)

var player_in_area: bool = false
var prompt_label: Label = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Find or create prompt label
	if has_node("DoorLabel"):
		prompt_label = get_node("DoorLabel")


func _process(_delta: float) -> void:
	if player_in_area and Input.is_action_just_pressed("interact"):
		_load_scene()


func _on_body_entered(body: Node2D) -> void:
	if body is Murum:
		player_in_area = true
		if prompt_label:
			prompt_label.text = "E - Enter TestRoom"


func _on_body_exited(body: Node2D) -> void:
	if body is Murum:
		player_in_area = false
		if prompt_label:
			prompt_label.text = "TestRoom"


func _load_scene() -> void:
	print("[Door] Loading scene: ", target_scene)

	# Store spawn position in GameManager
	if GameManager.has_method("set_spawn_override"):
		GameManager.set_spawn_override(spawn_position)

	get_tree().change_scene_to_file(target_scene)
