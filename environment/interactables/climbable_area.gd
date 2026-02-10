extends Area2D
class_name ClimbableArea

## Kletterbarer Bereich fuer Leitern und Treppen.
## Als Szene beliebig oft im Level platzierbar.
## Spieler koennen sich mit Hoch/Runter vertikal bewegen (Gravity wird deaktiviert).

# ============================================================================
# INSPECTOR CONFIGURATION
# ============================================================================

enum ClimbableType { LADDER, STAIRCASE }

@export var climbable_type: ClimbableType = ClimbableType.LADDER
@export var climb_speed: float = 200.0  ## Vertikale Geschwindigkeit beim Klettern
@export var area_width: float = 64.0    ## Breite der Kletterzone
@export var area_height: float = 256.0  ## Hoehe der Kletterzone
@export var visual_color: Color = Color(0.6, 0.4, 0.2, 0.4)  ## Platzhalter-Farbe

# ============================================================================
# REFERENCES (built in _ready)
# ============================================================================

var _collision_shape: CollisionShape2D
var _visual: ColorRect

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_build_nodes()
	_configure_collision()
	add_to_group("climbable_areas")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _build_nodes() -> void:
	# --- Collision Shape (Erkennungszone) ---
	_collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(area_width, area_height)
	_collision_shape.shape = rect
	_collision_shape.position = Vector2(area_width / 2.0, area_height / 2.0)
	add_child(_collision_shape)

	# --- Visueller Platzhalter ---
	_visual = ColorRect.new()
	_visual.size = Vector2(area_width, area_height)
	_visual.color = visual_color
	add_child(_visual)

	# Sprossen fuer Leiter-Optik
	if climbable_type == ClimbableType.LADDER:
		_add_rung_visuals()


func _configure_collision() -> void:
	collision_layer = 0       # Existiert auf keinem physischen Layer
	collision_mask = 2 | 4    # Layer 2 (Player1) + Layer 3 (Player2)


func _add_rung_visuals() -> void:
	var rung_spacing: float = 32.0
	var rung_count: int = int(area_height / rung_spacing)
	var rung_color := Color(visual_color.r * 0.7, visual_color.g * 0.7, visual_color.b * 0.7, 0.8)

	for i in range(rung_count):
		var rung := ColorRect.new()
		rung.size = Vector2(area_width, 4.0)
		rung.position = Vector2(0, (i + 1) * rung_spacing - 2.0)
		rung.color = rung_color
		add_child(rung)


# ============================================================================
# PLAYER DETECTION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	var mc = body.get_node_or_null("MovementController")
	if mc and "current_climbable" in mc:
		mc.current_climbable = self


func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return

	var mc = body.get_node_or_null("MovementController")
	if mc and "current_climbable" in mc:
		# Nur loeschen wenn diese Area noch die aktive ist
		if mc.current_climbable == self:
			if mc.is_climbing:
				mc.stop_climbing()
			mc.current_climbable = null


# ============================================================================
# HELPERS
# ============================================================================

func _is_player(body: Node) -> bool:
	return (body.is_in_group("player") or body.is_in_group("player2")
		or body.name == "Murum" or body.name == "Lythrun")
