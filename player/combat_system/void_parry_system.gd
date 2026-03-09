extends Node
class_name VoidParrySystem

## Void Parry System for P2 (Lythrun) - Hold-based parry/block
## Extracted from lythrun_player.gd (COMMIT 019.5)
##
## - Parry Window: First 0.6s after LT press = Perfect Parry (AoE damage + stun)
## - Blocking: After parry window = Normal Block (invulnerable, no counter)
## - Player is invulnerable during both parry window and blocking
## - Uses InputManager.is_p2_action_pressed("void_parry") for hold-check

# ============================================================================
# CONSTANTS
# ============================================================================

# Void Parry Timing
const VOID_PARRY_WINDOW: float = 0.6       # Parry window (DOUBLED from 0.3s)
const PERFECT_PARRY_WINDOW: float = 0.24   # Perfect timing window (DOUBLED from 0.12s)

# Detection / AoE
const VOID_PARRY_RADIUS: float = 70.0              # Detection radius (same as P1)
const PERFECT_PARRY_AOE_RADIUS: float = 220.0       # AoE radius for perfect parry counter
const PERFECT_PARRY_DAMAGE: float = 40.0             # Damage dealt by perfect parry AoE
const PERFECT_PARRY_STUN_DURATION: float = 1.5       # Stun duration on perfect parry

# ============================================================================
# STATE
# ============================================================================

enum VoidParryState { IDLE, PARRY_WINDOW, BLOCKING }

var void_parry_state: VoidParryState = VoidParryState.IDLE
var parry_start_time: float = 0.0
var parry_window_timer: float = 0.0

# Visual Indicator (like P1's block_indicator)
var void_parry_indicator: Polygon2D = null
var void_parry_indicator_tween: Tween = null

# Parry Detection Area (like P1's BlockArea)
var void_parry_area: Area2D = null
var void_parry_collision: CollisionShape2D = null

# ============================================================================
# REFERENCES
# ============================================================================

var player: CharacterBody2D = null

# ============================================================================
# SIGNALS
# ============================================================================

signal parry_started
signal perfect_parry_executed
signal parry_ended

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get player reference (via parent CombatSystem -> owner)
	var combat_system = get_parent()
	if combat_system:
		player = combat_system.owner as CharacterBody2D
		if not player:
			print("[VoidParrySystem] WARNING: Could not get player from combat_system.owner")

	# Fallback: Try owner directly
	if not player:
		player = owner as CharacterBody2D

	if not player:
		print("[VoidParrySystem] ERROR: Could not find player reference!")
	else:
		print("[VoidParrySystem] Player reference set: %s" % player.name)

	# Create visual indicator and detection area
	_setup_void_parry_indicator()
	_setup_void_parry_area()

	print("[VoidParrySystem] Initialized (hold-based void parry/block)")

func _setup_void_parry_indicator() -> void:
	"""Creates visual indicator Polygon2D for void parry"""

	void_parry_indicator = Polygon2D.new()

	# Create circle polygon (same radius as P1)
	var points: PackedVector2Array = _create_circle_points(VOID_PARRY_RADIUS, 48)

	void_parry_indicator.polygon = points
	void_parry_indicator.position = Vector2.ZERO  # Centered on player
	void_parry_indicator.z_index = 0
	void_parry_indicator.visible = false  # Hidden by default

	# Purple color for P2 (shadow theme)
	void_parry_indicator.color = Color(0.6, 0.2, 0.8, 0.5)  # Purple

	if player:
		player.add_child(void_parry_indicator)
	else:
		add_child(void_parry_indicator)

	print("[VoidParrySystem] Void parry visual indicator created")

func _setup_void_parry_area() -> void:
	"""Creates detection Area2D for perfect parry counter"""

	void_parry_area = Area2D.new()
	void_parry_area.name = "VoidParryArea"

	# Create collision shape
	void_parry_collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = VOID_PARRY_RADIUS  # Same as visual indicator
	void_parry_collision.shape = shape

	void_parry_area.add_child(void_parry_collision)

	if player:
		player.add_child(void_parry_area)
	else:
		add_child(void_parry_area)

	# Collision setup (detect Enemy Hitboxes on Layer 128)
	void_parry_area.collision_layer = 0  # Don't interact as a hurtbox
	void_parry_area.collision_mask = 0
	void_parry_area.set_collision_mask_value(8, true)  # Enemy Hitboxes (Layer 128 = 2^7 = bit 8, 1-indexed)

	# CRITICAL: monitoring disabled by default, enabled during parry
	void_parry_area.monitoring = false
	void_parry_area.monitorable = false

	# Connect signal for parry counter
	void_parry_area.area_entered.connect(_on_void_parry_area_entered)

	print("[VoidParrySystem] Void parry detection area created - Radius: %.0f, Mask: %d" % [VOID_PARRY_RADIUS, void_parry_area.collision_mask])

func _create_circle_points(radius: float, num_points: int) -> PackedVector2Array:
	"""Creates a circle polygon with given radius and number of points"""
	var points: PackedVector2Array = []
	for i in range(num_points):
		var angle = (i / float(num_points)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

# ============================================================================
# INPUT (called from _process)
# ============================================================================

func _process(delta: float) -> void:
	process_parry(delta)

func process_parry(delta: float) -> void:
	"""Main state machine update - call from _process(delta)"""

	# CRITICAL: Check if LT is still held (for both PARRY_WINDOW and BLOCKING states)
	if void_parry_state != VoidParryState.IDLE:
		# If LT is no longer pressed, stop parry/blocking
		if InputManager and not InputManager.is_p2_action_pressed("void_parry"):
			print("[VoidParrySystem] Void Parry released (no longer pressed)")
			stop_parry()

	# Count down parry window timer
	if void_parry_state == VoidParryState.PARRY_WINDOW:
		parry_window_timer -= delta
		if parry_window_timer <= 0:
			# Transition to BLOCKING state
			_transition_to_blocking()

func _input(event: InputEvent) -> void:
	# Use InputManager for proper device filtering
	if not InputManager:
		return

	# Check for void parry input (LT pressed)
	if InputManager.is_p2_action_just_pressed("void_parry"):
		start_parry()

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func start_parry() -> void:
	"""Starts void parry window (LT pressed) - HOLD-BASED"""
	if void_parry_state != VoidParryState.IDLE:
		print("[VoidParrySystem] Already active, ignoring")
		return

	print("[VoidParrySystem] ===== PARRY WINDOW STARTED (%.2fs) =====" % VOID_PARRY_WINDOW)

	# Enter PARRY_WINDOW state
	void_parry_state = VoidParryState.PARRY_WINDOW
	parry_window_timer = VOID_PARRY_WINDOW
	parry_start_time = Time.get_ticks_msec() / 1000.0

	# Enable detection area (for Perfect Parry Counter)
	if void_parry_area:
		void_parry_area.monitoring = true
		print("[VoidParrySystem] Detection area enabled - Radius: %.0f" % VOID_PARRY_RADIUS)

	# Enable invulnerability immediately (CRITICAL FIX)
	print("[VoidParrySystem] About to set player invulnerable to TRUE")
	_set_void_parry_invulnerable(true)
	print("[VoidParrySystem] Finished setting player invulnerable")

	# Show visual indicator (gold pulsing during parry window)
	_show_void_parry_window_indicators()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_parry_activate")

	# Emit signals
	parry_started.emit()
	if EventBus:
		EventBus.parry_started.emit()

func stop_parry() -> void:
	"""Stops void parry/blocking (LT released)"""
	if void_parry_state == VoidParryState.IDLE:
		return

	print("[VoidParrySystem] Blocking ended")

	# Return to IDLE
	void_parry_state = VoidParryState.IDLE

	# Disable detection area
	if void_parry_area:
		void_parry_area.monitoring = false

	# Disable invulnerability
	_set_void_parry_invulnerable(false)

	# Hide visual indicator
	_hide_void_parry_indicators()

	# Emit signal
	parry_ended.emit()

# ============================================================================
# STATE TRANSITIONS
# ============================================================================

func _transition_to_blocking() -> void:
	"""Transitions from parry window to normal blocking (like P1)"""
	print("[VoidParrySystem] ===== PARRY WINDOW EXPIRED -> BLOCKING STATE =====")

	void_parry_state = VoidParryState.BLOCKING

	# Change visual indicator (purple for blocking)
	_show_void_blocking_indicators()

# ============================================================================
# COLLISION DETECTION
# ============================================================================

func _on_void_parry_area_entered(area: Area2D) -> void:
	"""Called when enemy hitbox enters void parry detection area"""
	print("[VoidParrySystem] ===== AREA ENTERED SIGNAL FIRED =====")
	print("[VoidParrySystem] Area: ", area.name if area else "null")

	# CRITICAL: Safe owner check to prevent crash on freed objects
	var owner_name = "null"
	if area and is_instance_valid(area.owner):
		owner_name = area.owner.name
	print("[VoidParrySystem] Area owner: ", owner_name)

	# Safety check
	if void_parry_state == VoidParryState.IDLE:
		print("[VoidParrySystem] State is IDLE, ignoring")
		return

	print("[VoidParrySystem] Enemy hitbox detected during ", "PARRY_WINDOW" if void_parry_state == VoidParryState.PARRY_WINDOW else "BLOCKING")

	# Calculate if perfect parry (only during PARRY_WINDOW state)
	var parry_time = (Time.get_ticks_msec() / 1000.0) - parry_start_time
	var is_perfect = (void_parry_state == VoidParryState.PARRY_WINDOW) and (parry_time <= PERFECT_PARRY_WINDOW)

	if is_perfect:
		print("[VoidParrySystem] ===== PERFECT PARRY ===== (%.3fs)" % parry_time)
		# CRITICAL: Call deferred to avoid physics callback issues
		call_deferred("_execute_perfect_parry")
	else:
		# Normal block (no counter)
		print("[VoidParrySystem] Normal block (no counter)")
		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("void_parry_success")

# ============================================================================
# PERFECT PARRY EXECUTION
# ============================================================================

func _execute_perfect_parry() -> void:
	"""Execute perfect parry AoE (called via call_deferred to avoid physics callback issues)"""
	print("[VoidParrySystem] Executing Perfect Parry AoE...")

	if not player:
		print("[VoidParrySystem] ERROR: Cannot execute perfect parry - player is null!")
		return

	# Screen flash
	spawn_perfect_parry_flash()

	# AoE damage + stun - use overlapping areas IMMEDIATELY
	var player_pos = player.global_position
	var enemies_in_range = []

	# Get all enemies in the game
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy and is_instance_valid(enemy):
			var distance = player_pos.distance_to(enemy.global_position)
			if distance <= PERFECT_PARRY_AOE_RADIUS:
				enemies_in_range.append(enemy)

	print("[VoidParrySystem] Found %d enemies in radius %.0f" % [enemies_in_range.size(), PERFECT_PARRY_AOE_RADIUS])

	# Apply Urgathons Erbe ability damage bonus
	var parry_damage = PERFECT_PARRY_DAMAGE
	if UpgradeManager and UpgradeManager.get_ability_damage_multiplier() > 1.0:
		parry_damage = parry_damage * UpgradeManager.get_ability_damage_multiplier()

	# Damage and stun all enemies in range
	for enemy in enemies_in_range:
		# Damage
		if enemy.has_method("take_damage"):
			enemy.take_damage(parry_damage)
			print("[VoidParrySystem] Perfect parry damage (direct) to %s" % enemy.name)
		elif enemy.has_node("HealthComponent"):
			var health = enemy.get_node("HealthComponent")
			if health.has_method("take_damage"):
				health.take_damage(int(parry_damage))
				print("[VoidParrySystem] Perfect parry damage (HealthComponent) to %s" % enemy.name)

		# Stun
		if enemy.has_method("apply_stun"):
			enemy.apply_stun(PERFECT_PARRY_STUN_DURATION)
			print("[VoidParrySystem] Stunned %s for %.1fs" % [enemy.name, PERFECT_PARRY_STUN_DURATION])

	# VFX
	spawn_void_parry_explosion_vfx(player_pos)

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_parry_perfect")

	# Camera shake
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(12.0, 0.5)

	# Emit signals
	perfect_parry_executed.emit()
	if EventBus:
		EventBus.perfect_parry_executed.emit(null)

# ============================================================================
# INVULNERABILITY
# ============================================================================

func _set_void_parry_invulnerable(invulnerable: bool) -> void:
	"""Sets player invulnerability state during void parry (same as P1's ParryBlockSystem)"""
	if not player:
		print("[VoidParrySystem] ERROR: Cannot set invulnerability - player is null!")
		return

	var hurtbox = player.get_node_or_null("HurtboxComponent")
	if not hurtbox:
		# Fallback: try player.hurtbox property
		if player.get("hurtbox"):
			hurtbox = player.hurtbox
		else:
			print("[VoidParrySystem] ERROR: Cannot set invulnerability - hurtbox is null!")
			return

	# CRITICAL FIX: Set invulnerability on HURTBOX, not HealthComponent!
	# HurtboxComponent.take_damage() checks its own is_invulnerable

	# Stop the hurtbox's invulnerability timer to prevent override
	if hurtbox.invulnerability_timer:
		hurtbox.invulnerability_timer.stop()
		print("[VoidParrySystem] Stopped HurtboxComponent invulnerability_timer")

	hurtbox.is_invulnerable = invulnerable
	print("[VoidParrySystem] Player invulnerability set to: %s (current value: %s)" % [invulnerable, hurtbox.is_invulnerable])

# ============================================================================
# VISUAL INDICATORS
# ============================================================================

func _show_void_parry_window_indicators() -> void:
	"""Shows indicator during parry window (gold pulsing, like P1)"""
	if not void_parry_indicator:
		return

	# Stop any existing tween
	if void_parry_indicator_tween and void_parry_indicator_tween.is_valid():
		void_parry_indicator_tween.kill()

	void_parry_indicator.visible = true
	# Gold color for parry window
	void_parry_indicator.color = Color(1.0, 0.84, 0.0, 0.5)  # Gold

	# Bright pulsing animation during parry window
	void_parry_indicator_tween = create_tween().set_loops()
	void_parry_indicator_tween.tween_property(void_parry_indicator, "modulate:a", 0.9, 0.15)
	void_parry_indicator_tween.tween_property(void_parry_indicator, "modulate:a", 1.0, 0.15)

func _show_void_blocking_indicators() -> void:
	"""Shows indicator for normal blocking (purple shadow theme)"""
	if not void_parry_indicator:
		return

	# Stop any existing tween (stop pulsing)
	if void_parry_indicator_tween and void_parry_indicator_tween.is_valid():
		void_parry_indicator_tween.kill()
		void_parry_indicator_tween = null

	void_parry_indicator.visible = true
	# Purple color for P2's shadow blocking
	void_parry_indicator.color = Color(0.6, 0.2, 0.8, 0.3)  # Purple, dimmer
	# Reset modulate (in case it was mid-pulse)
	void_parry_indicator.modulate.a = 1.0

func _hide_void_parry_indicators() -> void:
	"""Hides visual indicator"""
	# Stop any existing tween
	if void_parry_indicator_tween and void_parry_indicator_tween.is_valid():
		void_parry_indicator_tween.kill()
		void_parry_indicator_tween = null

	if void_parry_indicator:
		void_parry_indicator.visible = false
		# Reset modulate
		void_parry_indicator.modulate.a = 1.0

# ============================================================================
# VFX HELPERS
# ============================================================================

func spawn_void_parry_shield() -> void:
	"""Spawn void parry shield VFX (same as P1's parry flash)"""
	# Use P1's parry flash VFX
	if not ResourceLoader.exists("res://vfx/particles/parry_flash.tscn"):
		print("[VoidParrySystem] Parry flash VFX not found, skipping")
		return

	var flash_scene = load("res://vfx/particles/parry_flash.tscn")
	var flash = flash_scene.instantiate()

	if get_tree() and get_tree().root:
		get_tree().root.add_child(flash)
		if player:
			flash.global_position = player.global_position
		else:
			flash.global_position = Vector2.ZERO

		# Auto-cleanup after 1 second
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(flash):
			flash.queue_free()

	print("[VoidParrySystem] Void parry shield spawned")

func spawn_perfect_parry_flash() -> void:
	"""Spawn perfect parry screen flash"""
	# Placeholder violet flash
	var flash = ColorRect.new()
	flash.color = Color(0.6, 0, 1.0)
	flash.modulate.a = 0.6
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(flash)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)

		var tween = create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.2)
		tween.tween_callback(flash.queue_free)

func spawn_void_parry_explosion_vfx(pos: Vector2) -> void:
	"""Spawn void parry explosion VFX"""
	print("[VoidParrySystem] Void parry explosion at ", pos)

	# Visual placeholder - expanding purple circle
	var explosion = Polygon2D.new()

	# Create circle polygon
	var points: PackedVector2Array = _create_circle_points(10.0, 32)

	explosion.polygon = points
	explosion.position = pos
	explosion.z_index = 10  # Above everything
	explosion.color = Color(0.8, 0.3, 1.0, 0.7)  # Bright purple

	if player and player.get_parent():
		player.get_parent().add_child(explosion)
	elif get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(explosion)

	# Animate: Expand and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(explosion, "scale", Vector2(22, 22), 0.4)  # 220px radius
	tween.tween_property(explosion, "modulate:a", 0.0, 0.4)
	tween.tween_callback(explosion.queue_free)

# ============================================================================
# UTILITY
# ============================================================================

func is_blocking() -> bool:
	"""Returns true if currently blocking (BLOCKING state)"""
	return void_parry_state == VoidParryState.BLOCKING

func is_parrying() -> bool:
	"""Returns true if in parry window (PARRY_WINDOW state)"""
	return void_parry_state == VoidParryState.PARRY_WINDOW

func is_active() -> bool:
	"""Returns true if parry or block is active (not IDLE)"""
	return void_parry_state != VoidParryState.IDLE

func get_state() -> VoidParryState:
	"""Returns current void parry state"""
	return void_parry_state
