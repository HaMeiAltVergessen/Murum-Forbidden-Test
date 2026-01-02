extends Camera2D
## CoopCamera - Adaptive camera system for local co-op
## Supports Shared-Screen (co-op) and Split-Screen (PvP) modes
class_name CoopCamera

# ============ REFERENCES ============
var player1: CharacterBody2D = null
var player2: CharacterBody2D = null

# ============ CAMERA MODE ============
enum CameraMode { SINGLE_PLAYER, SHARED_SCREEN, SPLIT_SCREEN }
var current_mode: CameraMode = CameraMode.SINGLE_PLAYER

# ============ SHARED-SCREEN SETTINGS ============
@export_group("Shared-Screen")
@export var follow_lerp_speed: float = 3.0
@export var base_zoom: float = 1.5
@export var min_zoom: float = 1.0
@export var max_zoom: float = 2.5
@export var zoom_distance_threshold: float = 400.0  # Distance for min_zoom
@export var zoom_lerp_speed: float = 2.0

# ============ SPLIT-SCREEN SETTINGS ============
@export_group("Split-Screen")
@export var split_transition_duration: float = 0.5

# ============ ROOM BOUNDS ============
var room_bounds: Rect2 = Rect2()
var use_bounds: bool = false

# ============ STATE ============
var target_position: Vector2 = Vector2.ZERO
var target_zoom: float = 1.5
var is_transitioning: bool = false

func _ready() -> void:
	# Co-op Manager Signals
	if CoopManager:
		CoopManager.p2_joined.connect(_on_p2_joined)
		CoopManager.p2_left.connect(_on_p2_left)

	# Initial: Single-Player-Mode
	set_mode(CameraMode.SINGLE_PLAYER)

	print("[CoopCamera] Initialized in SINGLE_PLAYER mode")

func _process(delta: float) -> void:
	match current_mode:
		CameraMode.SINGLE_PLAYER:
			update_single_player_camera(delta)
		CameraMode.SHARED_SCREEN:
			update_shared_screen_camera(delta)
		CameraMode.SPLIT_SCREEN:
			# Split-Screen is handled by separate scene
			pass

# ============ SINGLE-PLAYER MODE ============

func update_single_player_camera(delta: float) -> void:
	if not player1 or not is_instance_valid(player1):
		return

	# Follow P1
	target_position = player1.global_position

	# Smooth Follow
	global_position = global_position.lerp(target_position, follow_lerp_speed * delta)

	# Bounds-Clipping
	apply_room_bounds()

# ============ SHARED-SCREEN MODE ============

func update_shared_screen_camera(delta: float) -> void:
	if not player1 or not is_instance_valid(player1) or not player2 or not is_instance_valid(player2):
		# Fallback to Single-Player
		set_mode(CameraMode.SINGLE_PLAYER)
		return

	# Calculate Midpoint
	var midpoint = (player1.global_position + player2.global_position) / 2.0
	target_position = midpoint

	# Calculate Distance between players
	var distance = player1.global_position.distance_to(player2.global_position)

	# Dynamic Zoom based on distance
	calculate_dynamic_zoom(distance)

	# Smooth Follow
	global_position = global_position.lerp(target_position, follow_lerp_speed * delta)

	# Smooth Zoom
	var current_zoom_value = zoom.x
	var new_zoom_value = lerp(current_zoom_value, target_zoom, zoom_lerp_speed * delta)
	zoom = Vector2(new_zoom_value, new_zoom_value)

	# Bounds-Clipping
	apply_room_bounds()

func calculate_dynamic_zoom(distance: float) -> void:
	"""Calculate target zoom based on player distance

	Closer players → Zoomed in (base_zoom)
	Farther players → Zoomed out (min_zoom)
	"""
	if distance <= 0:
		target_zoom = base_zoom
		return

	var zoom_factor = clamp(distance / zoom_distance_threshold, 0.0, 1.0)
	target_zoom = lerp(base_zoom, min_zoom, zoom_factor)
	target_zoom = clamp(target_zoom, min_zoom, max_zoom)

# ============ ROOM BOUNDS ============

func set_room_bounds(bounds: Rect2) -> void:
	"""Set room bounds for camera constraints"""
	room_bounds = bounds
	use_bounds = true

	# Set camera limits
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)

	print("[CoopCamera] Room bounds set: ", bounds)

func clear_room_bounds() -> void:
	"""Clear room bounds (free camera)"""
	use_bounds = false

	# Reset limits
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000

	print("[CoopCamera] Room bounds cleared")

func apply_room_bounds() -> void:
	"""Clamp camera position within room bounds"""
	if not use_bounds:
		return

	# Clamp position within bounds accounting for viewport size
	var viewport_size = get_viewport_rect().size / zoom
	var half_viewport = viewport_size / 2.0

	var clamped_x = clamp(
		global_position.x,
		room_bounds.position.x + half_viewport.x,
		room_bounds.end.x - half_viewport.x
	)

	var clamped_y = clamp(
		global_position.y,
		room_bounds.position.y + half_viewport.y,
		room_bounds.end.y - half_viewport.y
	)

	global_position = Vector2(clamped_x, clamped_y)

# ============ MODE SWITCHING ============

func set_mode(mode: CameraMode) -> void:
	"""Switch camera mode"""
	if current_mode == mode:
		return

	print("[CoopCamera] Switching mode: %s → %s" % [CameraMode.keys()[current_mode], CameraMode.keys()[mode]])

	current_mode = mode

	match mode:
		CameraMode.SINGLE_PLAYER:
			zoom = Vector2(base_zoom, base_zoom)
			enabled = true

		CameraMode.SHARED_SCREEN:
			zoom = Vector2(base_zoom, base_zoom)
			enabled = true

		CameraMode.SPLIT_SCREEN:
			# Start split-screen transition
			transition_to_split_screen()

func transition_to_split_screen() -> void:
	"""Transition to split-screen mode with fade"""
	is_transitioning = true

	# Create fade-out
	var fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	get_tree().current_scene.add_child(fade)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)

	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, split_transition_duration / 2.0)

	await tween.finished

	# Activate split-screen
	activate_split_screen()

	# Fade-in
	tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, split_transition_duration / 2.0)

	await tween.finished
	fade.queue_free()

	is_transitioning = false

func activate_split_screen() -> void:
	"""Activate split-screen rendering"""
	# Deactivate this camera
	enabled = false

	# Activate split-screen manager
	var split_manager = get_tree().get_first_node_in_group("split_screen_manager")
	if split_manager and split_manager.has_method("activate"):
		split_manager.activate(player1, player2)
		print("[CoopCamera] Split-screen activated")
	else:
		push_error("[CoopCamera] Split-screen manager not found!")
		# Fallback to shared-screen
		enabled = true
		set_mode(CameraMode.SHARED_SCREEN)

func deactivate_split_screen() -> void:
	"""Deactivate split-screen and return to shared-screen"""
	# Reactivate shared-screen
	enabled = true

	# Deactivate split-screen manager
	var split_manager = get_tree().get_first_node_in_group("split_screen_manager")
	if split_manager and split_manager.has_method("deactivate"):
		split_manager.deactivate()

	set_mode(CameraMode.SHARED_SCREEN)
	print("[CoopCamera] Returned to shared-screen")

# ============ PLAYER REFERENCES ============

func set_player1(player: CharacterBody2D) -> void:
	"""Set Player 1 reference"""
	player1 = player
	print("[CoopCamera] Player 1 set: ", player.name if player else "null")

func set_player2(player: CharacterBody2D) -> void:
	"""Set Player 2 reference"""
	player2 = player
	print("[CoopCamera] Player 2 set: ", player.name if player else "null")

# ============ SIGNALS ============

func _on_p2_joined() -> void:
	"""Handle P2 joining"""
	if CoopManager:
		player2 = CoopManager.get_p2_instance()
		set_mode(CameraMode.SHARED_SCREEN)

func _on_p2_left() -> void:
	"""Handle P2 leaving"""
	player2 = null
	set_mode(CameraMode.SINGLE_PLAYER)

# ============ UTILITY ============

func shake(intensity: float = 5.0, duration: float = 0.3) -> void:
	"""Camera shake effect for impacts, explosions, etc."""
	var shake_tween = create_tween()
	var original_offset = offset

	var shake_count = int(duration * 60)  # 60 FPS

	for i in range(shake_count):
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(self, "offset", shake_offset, 0.016)

	shake_tween.tween_property(self, "offset", original_offset, 0.1)

func focus_on_position(pos: Vector2, duration: float = 1.0) -> void:
	"""Focus camera on specific position (cutscenes, boss spawn, etc.)"""
	var tween = create_tween()
	tween.tween_property(self, "global_position", pos, duration)
	await tween.finished
