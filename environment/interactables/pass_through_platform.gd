extends StaticBody2D
class_name PassThroughPlatform

## Durchgangsboden - Man kann von unten durchspringen und mit Crouch durchfallen.
## Gegner koennen NICHT durchfallen.

# ============================================================================
# PROPERTIES
# ============================================================================

@export var platform_width: float = 256.0
@export var platform_height: float = 32.0
@export var platform_color: Color = Color(0.35, 0.35, 0.35, 0.5)

# ============================================================================
# STATE
# ============================================================================

## Spieler die gerade durchfallen (collision exception aktiv)
var _falling_through: Dictionary = {}  # player_node -> true

# ============================================================================
# REFERENCES
# ============================================================================

var collision_shape: CollisionShape2D
var visual: ColorRect
var detection_area: Area2D

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_build_nodes()
	add_to_group("pass_through_platforms")
	print("[PassThroughPlatform] Ready at %s" % global_position)


func _build_nodes() -> void:
	# --- Collision (one-way) ---
	collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(platform_width, platform_height)
	collision_shape.shape = rect
	collision_shape.position = Vector2(platform_width / 2.0, platform_height / 2.0)
	collision_shape.one_way_collision = true
	collision_shape.one_way_collision_margin = 4.0
	add_child(collision_shape)

	# --- Visual (halbtransparent) ---
	visual = ColorRect.new()
	visual.size = Vector2(platform_width, platform_height)
	visual.color = platform_color
	add_child(visual)

	# --- Detection Area (etwas groesser als Plattform, um Spieler zu erkennen) ---
	detection_area = Area2D.new()
	detection_area.collision_layer = 0
	detection_area.collision_mask = 2 | 4  # Layer 2 = Player1, Layer 3(bit 3=4) = Player2
	var area_shape := CollisionShape2D.new()
	var area_rect := RectangleShape2D.new()
	area_rect.size = Vector2(platform_width, platform_height + 20)
	area_shape.shape = area_rect
	area_shape.position = Vector2(platform_width / 2.0, platform_height / 2.0)
	detection_area.add_child(area_shape)
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	add_child(detection_area)


# ============================================================================
# FALL-THROUGH LOGIC
# ============================================================================

func _physics_process(_delta: float) -> void:
	# Pruefen ob Spieler in der Area crouchen
	for body in detection_area.get_overlapping_bodies():
		if not _is_player(body):
			continue

		var is_crouching := _player_is_crouching(body)

		if is_crouching and body not in _falling_through:
			_start_fall_through(body)
		elif not is_crouching and body in _falling_through:
			_stop_fall_through(body)


func _start_fall_through(player: CharacterBody2D) -> void:
	"""Spieler faellt durch die Plattform"""
	_falling_through[player] = true
	add_collision_exception_with(player)
	print("[PassThroughPlatform] Player falling through: %s" % player.name)


func _stop_fall_through(player: CharacterBody2D) -> void:
	"""Kollision wieder aktivieren"""
	_falling_through.erase(player)
	remove_collision_exception_with(player)


func _on_body_entered(_body: Node2D) -> void:
	pass


func _on_body_exited(body: Node2D) -> void:
	# Wenn Spieler die Area verlaesst, Exception aufheben
	if body in _falling_through:
		_stop_fall_through(body as CharacterBody2D)


# ============================================================================
# HELPERS
# ============================================================================

func _is_player(body: Node) -> bool:
	return body.is_in_group("player") or body.is_in_group("player2") or body.name == "Murum" or body.name == "Lythrun"


func _player_is_crouching(player: Node) -> bool:
	# MovementController haelt is_crouching
	var mc = player.get_node_or_null("MovementController")
	if mc and "is_crouching" in mc:
		return mc.is_crouching
	return false
