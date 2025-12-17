extends Camera2D
## PlayerCamera handles smooth following, room bounds, and camera shake
class_name PlayerCamera

# ============ CONFIGURATION ============
@export var follow_smoothing: float = 5.0
@export var zoom_level: float = 1.0

# ============ CAMERA SHAKE ============
@export var max_shake_offset: float = 20.0
@export var trauma_decay_rate: float = 1.0

var trauma: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO

# ============ ROOM BOUNDS ============
var room_bounds: Rect2 = Rect2()
var use_room_bounds: bool = false


func _ready() -> void:
	# Set initial zoom
	zoom = Vector2(zoom_level, zoom_level)

	# Make this camera current
	make_current()

	# Connect to combo system for shake effects
	if CombatManager:
		CombatManager.combo_increased.connect(_on_combo_increased)

	print("[PlayerCamera] Initialized")


func _process(delta: float) -> void:
	_process_camera_shake(delta)


# ============ CAMERA SHAKE ============
func add_trauma(amount: float) -> void:
	"""Adds trauma for camera shake effect"""
	trauma = min(trauma + amount, 1.0)


func _process_camera_shake(delta: float) -> void:
	"""Updates camera shake based on trauma"""
	if trauma > 0:
		# Decay trauma
		trauma = max(0.0, trauma - trauma_decay_rate * delta)

		# Calculate shake
		var shake_amount: float = trauma * trauma  # Squared for better feel
		shake_offset = Vector2(
			randf_range(-max_shake_offset, max_shake_offset) * shake_amount,
			randf_range(-max_shake_offset, max_shake_offset) * shake_amount
		)

		offset = shake_offset
	else:
		offset = Vector2.ZERO


# ============ ROOM BOUNDS ============
func set_room_bounds(bounds: Rect2) -> void:
	"""Sets the camera bounds for the current room"""
	room_bounds = bounds
	use_room_bounds = true

	# Update limit settings
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.position.x + bounds.size.x)
	limit_bottom = int(bounds.position.y + bounds.size.y)

	# Enable limits
	limit_smoothed = true

	print("[PlayerCamera] Room bounds set: ", bounds)


func clear_room_bounds() -> void:
	"""Clears room bounds (camera follows freely)"""
	use_room_bounds = false
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000


# ============ CAMERA CONTROL ============
func set_zoom_level(new_zoom: float) -> void:
	"""Sets camera zoom level"""
	zoom_level = new_zoom
	zoom = Vector2(zoom_level, zoom_level)


func shake_light() -> void:
	"""Applies a light camera shake"""
	add_trauma(0.2)


func shake_medium() -> void:
	"""Applies a medium camera shake"""
	add_trauma(0.4)


func shake_heavy() -> void:
	"""Applies a heavy camera shake"""
	add_trauma(0.6)


func shake_combo(combo_count: int) -> void:
	"""Applies combo-scaled camera shake"""
	# Scale trauma based on combo count (0.15 - 0.30)
	var base_trauma: float = 0.15
	var trauma_per_combo: float = 0.01
	var max_trauma: float = 0.30

	var trauma_amount: float = base_trauma + (combo_count * trauma_per_combo)
	trauma_amount = min(trauma_amount, max_trauma)

	add_trauma(trauma_amount)


# ============ SIGNAL HANDLERS ============
func _on_combo_increased(new_count: int, _multiplier: float) -> void:
	"""Called when combo increases - triggers combo-scaled shake"""
	shake_combo(new_count)
