extends Node
## HUDManager - Coordinates all HUD components for dual-player display
## Manages P1 HUD, P2 HUD, Gold Display, Join Prompt, and P2 Tutorial

# ============ HUD REFERENCES ============
var p1_hud: CanvasLayer = null
var p2_hud: CanvasLayer = null
var gold_display: CanvasLayer = null
var join_prompt: CanvasLayer = null
var p2_tutorial: CanvasLayer = null

# ============ STATE ============
var huds_loaded: bool = false

func _ready() -> void:
	print("[HUDManager] Initialized")

	# Wait for scene tree to be ready
	await get_tree().process_frame

	# Load HUDs
	load_huds()

	# Connect signals
	if CoopManager:
		CoopManager.p2_joined.connect(_on_p2_joined)
		CoopManager.p2_left.connect(_on_p2_left)

func load_huds() -> void:
	"""Load all HUD components"""
	var current_scene = get_tree().current_scene

	if not current_scene:
		push_error("[HUDManager] No current scene found!")
		return

	# P1 HUD
	var p1_hud_scene = load("res://ui/hud/p1_hud.tscn")
	if p1_hud_scene:
		p1_hud = p1_hud_scene.instantiate()
		current_scene.add_child(p1_hud)
		print("[HUDManager] P1 HUD loaded")
	else:
		print("[HUDManager] WARNING: P1 HUD scene not found")

	# P2 HUD (initially hidden)
	var p2_hud_scene = load("res://ui/hud/p2_hud.tscn")
	if p2_hud_scene:
		p2_hud = p2_hud_scene.instantiate()
		current_scene.add_child(p2_hud)
		print("[HUDManager] P2 HUD loaded")
	else:
		print("[HUDManager] WARNING: P2 HUD scene not found")

	# Gold Display
	var gold_display_scene = load("res://ui/hud/gold_display.tscn")
	if gold_display_scene:
		gold_display = gold_display_scene.instantiate()
		current_scene.add_child(gold_display)
		print("[HUDManager] Gold Display loaded")
	else:
		print("[HUDManager] WARNING: Gold Display scene not found")

	# Join Prompt
	var join_prompt_scene = load("res://ui/hud/join_prompt.tscn")
	if join_prompt_scene:
		join_prompt = join_prompt_scene.instantiate()
		current_scene.add_child(join_prompt)
		print("[HUDManager] Join Prompt loaded")
	else:
		print("[HUDManager] WARNING: Join Prompt scene not found")

	# P2 Tutorial
	var p2_tutorial_scene = load("res://ui/hud/p2_tutorial.tscn")
	if p2_tutorial_scene:
		p2_tutorial = p2_tutorial_scene.instantiate()
		current_scene.add_child(p2_tutorial)
		print("[HUDManager] P2 Tutorial loaded")
	else:
		print("[HUDManager] WARNING: P2 Tutorial scene not found")

	huds_loaded = true

# ============ PLAYER REFERENCES ============

func set_p1_reference(player: CharacterBody2D) -> void:
	"""Set P1 reference for HUD"""
	if p1_hud and p1_hud.has_method("set_player"):
		p1_hud.set_player(player)
		print("[HUDManager] P1 reference set")

func set_p2_reference(player: CharacterBody2D) -> void:
	"""Set P2 reference for HUD"""
	if p2_hud and p2_hud.has_method("set_player"):
		p2_hud.set_player(player)
		print("[HUDManager] P2 reference set")

# ============ SIGNALS ============

func _on_p2_joined() -> void:
	"""Handle P2 joining"""
	var p2 = CoopManager.get_p2_instance() if CoopManager else null
	if p2:
		set_p2_reference(p2)

func _on_p2_left() -> void:
	"""Handle P2 leaving"""
	# P2 HUD will hide itself automatically via signal

# ============ HUD VISIBILITY ============

func hide_all_hud() -> void:
	"""Hide all HUD elements (for cutscenes, etc.)"""
	if p1_hud:
		p1_hud.visible = false
	if p2_hud:
		p2_hud.visible = false
	if gold_display:
		gold_display.visible = false
	if join_prompt:
		join_prompt.visible = false

	print("[HUDManager] All HUD hidden")

func show_all_hud() -> void:
	"""Show all HUD elements"""
	if p1_hud:
		p1_hud.visible = true

	if p2_hud and CoopManager and CoopManager.is_p2_active:
		p2_hud.visible = true

	if gold_display:
		gold_display.visible = true

	if join_prompt and not (CoopManager and CoopManager.is_p2_active):
		join_prompt.visible = true

	print("[HUDManager] All HUD shown")

func hide_join_prompt() -> void:
	"""Hide join prompt"""
	if join_prompt and join_prompt.has_method("hide_prompt"):
		join_prompt.hide_prompt()
