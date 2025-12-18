extends Marker2D
class_name SpawnPoint

## Marks player spawn position for room transitions

@export var spawn_id: String = "default"
@export var facing_direction: int = 1  # 1 = right, -1 = left

func _ready() -> void:
	# Use node name as ID if not set
	if spawn_id.is_empty():
		spawn_id = name.to_lower()

	add_to_group("spawn_points")

	# Visual indicator in editor
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw a small cross to indicate spawn position
		draw_line(Vector2(-16, 0), Vector2(16, 0), Color.GREEN, 2.0)
		draw_line(Vector2(0, -16), Vector2(0, 16), Color.GREEN, 2.0)

		# Draw direction arrow
		var arrow_end = Vector2(32 * facing_direction, 0)
		draw_line(Vector2.ZERO, arrow_end, Color.YELLOW, 3.0)
		draw_line(arrow_end, arrow_end + Vector2(-8 * facing_direction, -8), Color.YELLOW, 3.0)
		draw_line(arrow_end, arrow_end + Vector2(-8 * facing_direction, 8), Color.YELLOW, 3.0)
