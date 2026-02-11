extends Node
## HUDManager - Coordinates all HUD components for dual-player display
## Manages P1 HUD, P2 HUD, Gold Display, Join Prompt, and P2 Tutorial

# ============ HUD REFERENCES ============
var p1_hud: CanvasLayer = null
var p2_hud: CanvasLayer = null
var p1_abilities: CanvasLayer = null
var p2_abilities: CanvasLayer = null
var gold_display: CanvasLayer = null
var join_prompt: CanvasLayer = null
var p2_tutorial: CanvasLayer = null
var death_screen: CanvasLayer = null

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
	"""Load all HUD components (COMMIT 021: Persistent HUDs across scenes)"""
	# CRITICAL FIX: Add HUDs to HUDManager (autoload) instead of current_scene
	# This makes HUDs persist across scene transitions

	# P1 HUD
	var p1_hud_scene = load("res://ui/hud/p1_hud.tscn")
	if p1_hud_scene:
		p1_hud = p1_hud_scene.instantiate()
		add_child(p1_hud)  # Add to HUDManager (persistent)
		print("[HUDManager] P1 HUD loaded (persistent)")
	else:
		print("[HUDManager] WARNING: P1 HUD scene not found")

	# P2 HUD (initially hidden)
	var p2_hud_scene = load("res://ui/hud/p2_hud.tscn")
	if p2_hud_scene:
		p2_hud = p2_hud_scene.instantiate()
		add_child(p2_hud)  # Add to HUDManager (persistent)
		print("[HUDManager] P2 HUD loaded (persistent)")
	else:
		print("[HUDManager] WARNING: P2 HUD scene not found")

	# P1 Abilities Display
	var p1_abilities_scene = load("res://ui/hud/p1_abilities.tscn")
	if p1_abilities_scene:
		p1_abilities = p1_abilities_scene.instantiate()
		add_child(p1_abilities)  # Add to HUDManager (persistent)
		print("[HUDManager] P1 Abilities loaded (persistent)")
	else:
		print("[HUDManager] WARNING: P1 Abilities scene not found")

	# P2 Abilities Display
	var p2_abilities_scene = load("res://ui/hud/p2_abilities.tscn")
	if p2_abilities_scene:
		p2_abilities = p2_abilities_scene.instantiate()
		add_child(p2_abilities)  # Add to HUDManager (persistent)
		print("[HUDManager] P2 Abilities loaded (persistent)")
	else:
		print("[HUDManager] WARNING: P2 Abilities scene not found")

	# Gold Display
	var gold_display_scene = load("res://ui/hud/gold_display.tscn")
	if gold_display_scene:
		gold_display = gold_display_scene.instantiate()
		add_child(gold_display)  # Add to HUDManager (persistent)
		print("[HUDManager] Gold Display loaded (persistent)")
	else:
		print("[HUDManager] WARNING: Gold Display scene not found")

	# Join Prompt (initially hidden)
	var join_prompt_scene = load("res://ui/hud/join_prompt.tscn")
	if join_prompt_scene:
		join_prompt = join_prompt_scene.instantiate()
		add_child(join_prompt)  # Add to HUDManager (persistent)
		join_prompt.visible = false  # Hide by default
		print("[HUDManager] Join Prompt loaded (persistent, hidden)")
	else:
		print("[HUDManager] WARNING: Join Prompt scene not found")

	# P2 Tutorial
	var p2_tutorial_scene = load("res://ui/hud/p2_tutorial.tscn")
	if p2_tutorial_scene:
		p2_tutorial = p2_tutorial_scene.instantiate()
		add_child(p2_tutorial)  # Add to HUDManager (persistent)
		print("[HUDManager] P2 Tutorial loaded (persistent)")
	else:
		print("[HUDManager] WARNING: P2 Tutorial scene not found")

	# Death Screen (persistent across all scenes)
	var death_screen_scene = load("res://ui/death_screen.tscn")
	if death_screen_scene:
		death_screen = death_screen_scene.instantiate()
		add_child(death_screen)
		print("[HUDManager] Death Screen loaded (persistent)")
	else:
		print("[HUDManager] WARNING: Death Screen scene not found")

	huds_loaded = true

# ============ PLAYER REFERENCES ============

func set_p1_reference(player: CharacterBody2D) -> void:
	"""Set P1 reference for HUD"""
	if p1_hud and p1_hud.has_method("set_player"):
		p1_hud.set_player(player)
		print("[HUDManager] P1 reference set")

	# Set P1 abilities reference
	if p1_abilities and p1_abilities.has_method("set_player"):
		p1_abilities.set_player(player)
		print("[HUDManager] P1 abilities reference set")

func set_p2_reference(player: CharacterBody2D) -> void:
	"""Set P2 reference for HUD"""
	if p2_hud and p2_hud.has_method("set_player"):
		p2_hud.set_player(player)
		print("[HUDManager] P2 reference set")

	# Set P2 abilities reference
	if p2_abilities and p2_abilities.has_method("set_player"):
		p2_abilities.set_player(player)
		print("[HUDManager] P2 abilities reference set")

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
	if p1_abilities:
		p1_abilities.visible = false
	if p2_abilities:
		p2_abilities.visible = false
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

	if p1_abilities:
		p1_abilities.visible = true

	if p2_abilities:
		# P2 abilities handles its own visibility based on p2_joined signal
		pass

	if gold_display:
		gold_display.visible = true

	if join_prompt and not (CoopManager and CoopManager.is_p2_active):
		join_prompt.visible = true

	print("[HUDManager] All HUD shown")

func hide_join_prompt() -> void:
	"""Hide join prompt"""
	if join_prompt and join_prompt.has_method("hide_prompt"):
		join_prompt.hide_prompt()
