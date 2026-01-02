extends Node2D
## SplitScreenManager - Vertical split-screen system for PvP mode
## Renders two separate viewports (P1 left, P2 right)
class_name SplitScreenManager

# ============ NODE REFERENCES ============
@onready var left_viewport_container: SubViewportContainer = $LeftViewport
@onready var right_viewport_container: SubViewportContainer = $RightViewport
@onready var left_viewport: SubViewport = $LeftViewport/SubViewport
@onready var right_viewport: SubViewport = $RightViewport/SubViewport
@onready var p1_camera: Camera2D = $LeftViewport/SubViewport/Camera2D
@onready var p2_camera: Camera2D = $RightViewport/SubViewport/Camera2D
@onready var split_line: ColorRect = $SplitLine

# ============ PLAYER REFERENCES ============
var player1: CharacterBody2D = null
var player2: CharacterBody2D = null
var is_active: bool = false

# ============ SPLIT-SCREEN LAYOUT ============
@export var split_line_width: float = 4.0
@export var split_line_color: Color = Color(0.2, 0.2, 0.2)
@export var camera_follow_lerp_speed: float = 5.0

func _ready() -> void:
	# Initially invisible
	visible = false

	# Style split-line
	if split_line:
		split_line.color = split_line_color

	# Setup viewport sizes
	setup_viewports()

	print("[SplitScreen] Manager initialized")

func setup_viewports() -> void:
	"""Setup viewport sizes for vertical split"""
	var viewport_size = get_viewport_rect().size

	# Left half (P1)
	if left_viewport_container:
		left_viewport_container.size = Vector2(viewport_size.x / 2 - split_line_width / 2, viewport_size.y)
		left_viewport_container.position = Vector2.ZERO

	if left_viewport:
		left_viewport.size = left_viewport_container.size if left_viewport_container else viewport_size / 2

	# Right half (P2)
	if right_viewport_container:
		right_viewport_container.size = Vector2(viewport_size.x / 2 - split_line_width / 2, viewport_size.y)
		right_viewport_container.position = Vector2(viewport_size.x / 2 + split_line_width / 2, 0)

	if right_viewport:
		right_viewport.size = right_viewport_container.size if right_viewport_container else viewport_size / 2

	# Split-line (center)
	if split_line:
		split_line.size = Vector2(split_line_width, viewport_size.y)
		split_line.position = Vector2(viewport_size.x / 2 - split_line_width / 2, 0)

func activate(p1: CharacterBody2D, p2: CharacterBody2D) -> void:
	"""Activate split-screen mode"""
	player1 = p1
	player2 = p2

	# Setup cameras
	setup_cameras()

	visible = true
	is_active = true

	print("[SplitScreen] Activated - P1: %s, P2: %s" % [p1.name if p1 else "null", p2.name if p2 else "null"])

func setup_cameras() -> void:
	"""Setup cameras for both viewports"""
	if p1_camera:
		p1_camera.enabled = true
		p1_camera.make_current()

	if p2_camera:
		p2_camera.enabled = true
		# Note: Each viewport has its own "current" camera

func deactivate() -> void:
	"""Deactivate split-screen mode"""
	visible = false
	is_active = false

	# Deactivate cameras
	if p1_camera:
		p1_camera.enabled = false

	if p2_camera:
		p2_camera.enabled = false

	print("[SplitScreen] Deactivated")

func _process(delta: float) -> void:
	if not is_active:
		return

	# P1 camera follows P1
	if player1 and is_instance_valid(player1) and p1_camera:
		var target_pos = player1.global_position
		p1_camera.global_position = p1_camera.global_position.lerp(target_pos, camera_follow_lerp_speed * delta)

	# P2 camera follows P2
	if player2 and is_instance_valid(player2) and p2_camera:
		var target_pos = player2.global_position
		p2_camera.global_position = p2_camera.global_position.lerp(target_pos, camera_follow_lerp_speed * delta)
