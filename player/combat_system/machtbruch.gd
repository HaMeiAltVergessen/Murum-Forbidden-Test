extends Node
class_name Machtbruch

## Resonance Burst explosion system
## Hold attack after 3rd combo hit to charge and release AoE explosion
## Scales with current resonance level (Weak/Medium/Strong)

# ============================================================================
# CONSTANTS
# ============================================================================

# Charge Timing
const CHARGE_DURATION: float = 0.5  # Time to fully charge
const HOLD_THRESHOLD: float = 0.3  # Minimum hold time to trigger

# Weak Tier (0-33% Resonanz)
const WEAK_DAMAGE: int = 20
const WEAK_RADIUS: float = 100.0
const WEAK_CAMERA_TRAUMA: float = 0.2

# Medium Tier (34-66% Resonanz)
const MEDIUM_DAMAGE: int = 35
const MEDIUM_RADIUS: float = 150.0
const MEDIUM_CAMERA_TRAUMA: float = 0.35

# Strong Tier (67-100% Resonanz)
const STRONG_DAMAGE: int = 50
const STRONG_RADIUS: float = 200.0
const STRONG_CAMERA_TRAUMA: float = 0.5

# Resonance
const RESONANCE_CONSUMPTION: float = 0.5  # Consumes 50% of current resonance

# VFX
const CHARGE_PARTICLE_COUNT: int = 30
const EXPLOSION_HITSTOP: float = 0.15

# ============================================================================
# STATE
# ============================================================================

enum BurstTier { WEAK, MEDIUM, STRONG }

var is_available: bool = false
var is_charging: bool = false
var charge_timer: float = 0.0
var charge_complete: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

var player: CharacterBody2D = null
var combo_tracker: Node = null
var resonance_system: Node = null
var movement_controller: Node = null

# VFX
var charge_vfx: Node = null

# ============================================================================
# SIGNALS
# ============================================================================

signal machtbruch_available
signal machtbruch_charge_started
signal machtbruch_charge_completed
signal machtbruch_released(tier: BurstTier, damage: int, radius: float)
signal machtbruch_cancelled

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get player reference (via parent CombatSystem)
	var combat_system = get_parent()
	if combat_system:
		player = combat_system.owner as CharacterBody2D

	# Fallback
	if not player:
		player = owner as CharacterBody2D

	if not player:
		print("[Machtbruch] ERROR: Could not find player reference!")
		return

	# Get combo tracker reference
	combo_tracker = player.get_node_or_null("CombatSystem/ComboTracker")
	if combo_tracker:
		# Connect to combo finisher ready (3rd hit)
		if combo_tracker.has_signal("combo_finisher_ready"):
			combo_tracker.combo_finisher_ready.connect(_on_finisher_ready)
			print("[Machtbruch] Connected to ComboTracker.combo_finisher_ready")
	else:
		print("[Machtbruch] WARNING: ComboTracker not found!")

	# Get resonance system reference
	resonance_system = player.get_node_or_null("CombatSystem/ResonanceSystem")
	if not resonance_system:
		print("[Machtbruch] WARNING: ResonanceSystem not found!")

	# Get movement controller
	movement_controller = player.get_node_or_null("MovementController")

	print("[Machtbruch] Initialized (Resonance Burst)")

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	# Start charging when attack button pressed (if available)
	if event.is_action_pressed("light_attack"):
		if is_available and not is_charging:
			_start_charge()

	# Release burst when attack button released
	if event.is_action_released("light_attack"):
		if is_charging:
			_release_burst()

# ============================================================================
# AVAILABILITY
# ============================================================================

func _on_finisher_ready() -> void:
	"""Called when combo finisher is ready (3rd hit)"""
	print("[Machtbruch] Machtbruch now AVAILABLE (combo finisher ready)")
	is_available = true

	# Emit signal
	machtbruch_available.emit()
	EventBus.machtbruch_available.emit()

func reset_availability() -> void:
	"""Resets availability (called after use or combo break)"""
	if is_available:
		print("[Machtbruch] Availability reset")
	is_available = false
	is_charging = false
	charge_timer = 0.0
	charge_complete = false

# ============================================================================
# CHARGING
# ============================================================================

func _start_charge() -> void:
	"""Starts charging Machtbruch"""
	print("[Machtbruch] ===== CHARGE STARTED =====")

	is_charging = true
	charge_timer = 0.0
	charge_complete = false

	# Lock player movement
	if movement_controller:
		movement_controller.set_physics_process(false)

	# Freeze player velocity
	if player:
		player.velocity = Vector2.ZERO

	# Spawn charge VFX
	_spawn_charge_vfx()

	# Audio
	AudioManager.play_sfx("player_machtbruch_charge", 0.15)

	# Emit signal
	machtbruch_charge_started.emit()
	EventBus.machtbruch_charge_started.emit()

func _process(delta: float) -> void:
	"""Updates charge timer"""
	if not is_charging:
		return

	charge_timer += delta

	# Check if charge complete
	if charge_timer >= CHARGE_DURATION and not charge_complete:
		_on_charge_complete()

func _on_charge_complete() -> void:
	"""Called when charge duration reached"""
	print("[Machtbruch] Charge COMPLETE (%.2fs)" % CHARGE_DURATION)

	charge_complete = true

	# Visual feedback (flash charge VFX)
	if charge_vfx and charge_vfx.has_method("flash"):
		charge_vfx.flash()

	# Audio cue
	AudioManager.play_sfx("player_machtbruch_ready", 0.2)

	# Emit signal
	machtbruch_charge_completed.emit()
	EventBus.machtbruch_charge_completed.emit()

# ============================================================================
# RELEASE
# ============================================================================

func _release_burst() -> void:
	"""Releases resonance burst explosion"""

	# Check if held long enough
	if charge_timer < HOLD_THRESHOLD:
		print("[Machtbruch] Released too early (%.2fs < %.2fs)" % [charge_timer, HOLD_THRESHOLD])
		_cancel_charge()
		return

	print("[Machtbruch] ===== BURST RELEASED (held %.2fs) =====" % charge_timer)

	# Get resonance level
	if not resonance_system:
		print("[Machtbruch] ERROR: ResonanceSystem not available!")
		_cancel_charge()
		return

	var resonance_percent = resonance_system.get_resonance_normalized()
	print("[Machtbruch] Current resonance: %.1f%%" % (resonance_percent * 100.0))

	# Determine burst tier
	var tier = _get_burst_tier(resonance_percent)
	var tier_name = ["WEAK", "MEDIUM", "STRONG"][tier]
	print("[Machtbruch] Burst tier: %s" % tier_name)

	# Consume resonance (50% of current)
	if resonance_system.has_method("consume_resonance"):
		resonance_system.consume_resonance(RESONANCE_CONSUMPTION)
	else:
		print("[Machtbruch] WARNING: consume_resonance() not available!")

	# Execute explosion
	_execute_explosion(tier)

	# Cleanup
	_cleanup_charge()

	# Reset availability
	reset_availability()

func _cancel_charge() -> void:
	"""Cancels charge (released too early)"""
	print("[Machtbruch] Charge CANCELLED")

	_cleanup_charge()
	reset_availability()

	# Emit signal
	machtbruch_cancelled.emit()
	EventBus.machtbruch_cancelled.emit()

func _cleanup_charge() -> void:
	"""Cleans up charge state"""
	is_charging = false
	charge_timer = 0.0
	charge_complete = false

	# Unlock player movement
	if movement_controller:
		movement_controller.set_physics_process(true)

	# Remove charge VFX
	if charge_vfx:
		charge_vfx.queue_free()
		charge_vfx = null

# ============================================================================
# EXPLOSION
# ============================================================================

func _get_burst_tier(resonance_percent: float) -> BurstTier:
	"""Determines burst tier based on resonance percentage"""
	if resonance_percent >= 0.67:
		return BurstTier.STRONG
	elif resonance_percent >= 0.34:
		return BurstTier.MEDIUM
	else:
		return BurstTier.WEAK

func _execute_explosion(tier: BurstTier) -> void:
	"""Executes AoE explosion based on tier"""

	# Get tier stats
	var damage: int
	var radius: float
	var trauma: float

	match tier:
		BurstTier.WEAK:
			damage = WEAK_DAMAGE
			radius = WEAK_RADIUS
			trauma = WEAK_CAMERA_TRAUMA
		BurstTier.MEDIUM:
			damage = MEDIUM_DAMAGE
			radius = MEDIUM_RADIUS
			trauma = MEDIUM_CAMERA_TRAUMA
		BurstTier.STRONG:
			damage = STRONG_DAMAGE
			radius = STRONG_RADIUS
			trauma = STRONG_CAMERA_TRAUMA

	print("[Machtbruch] EXPLOSION! Tier: %d, Damage: %d, Radius: %.0f" % [tier, damage, radius])

	# Apply AoE damage to all enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = player.global_position.distance_to(enemy.global_position)

		if distance <= radius:
			# Apply damage
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, player)
				hit_count += 1
				print("[Machtbruch] Hit %s for %d damage (dist: %.1f)" % [enemy.name, damage, distance])

	print("[Machtbruch] Hit %d enemies" % hit_count)

	# Spawn explosion VFX
	_spawn_explosion_vfx(tier)

	# Audio
	var sfx_name = ["player_machtbruch_weak", "player_machtbruch_medium", "player_machtbruch_strong"][tier]
	AudioManager.play_sfx(sfx_name, 0.0)

	# Camera shake
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(trauma)

	# Hitstop
	GlobalTimeEffects.hit_stop(EXPLOSION_HITSTOP)

	# Emit signal
	machtbruch_released.emit(tier, damage, radius)
	EventBus.machtbruch_released.emit(tier, damage, radius)

# ============================================================================
# VFX
# ============================================================================

func _spawn_charge_vfx() -> void:
	"""Spawns charging VFX around player"""

	if not ResourceLoader.exists("res://vfx/particles/machtbruch_charge.tscn"):
		print("[Machtbruch] Charge VFX not found, skipping")
		return

	var charge_scene = preload("res://vfx/particles/machtbruch_charge.tscn")
	charge_vfx = charge_scene.instantiate()
	player.add_child(charge_vfx)

	if charge_vfx.has_property("emitting"):
		charge_vfx.emitting = true

func _spawn_explosion_vfx(tier: BurstTier) -> void:
	"""Spawns explosion VFX based on tier"""

	var vfx_path: String
	match tier:
		BurstTier.WEAK:
			vfx_path = "res://vfx/particles/machtbruch_weak.tscn"
		BurstTier.MEDIUM:
			vfx_path = "res://vfx/particles/machtbruch_medium.tscn"
		BurstTier.STRONG:
			vfx_path = "res://vfx/particles/machtbruch_strong.tscn"

	if not ResourceLoader.exists(vfx_path):
		print("[Machtbruch] Explosion VFX not found: %s" % vfx_path)
		return

	var explosion_scene = load(vfx_path)
	var explosion = explosion_scene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.global_position = player.global_position

	if explosion.has_property("emitting"):
		explosion.emitting = true

	# Auto-cleanup
	await get_tree().create_timer(2.0).timeout
	if explosion:
		explosion.queue_free()

# ============================================================================
# UTILITY
# ============================================================================

func is_machtbruch_available() -> bool:
	"""Returns true if Machtbruch can be activated"""
	return is_available and not is_charging

func is_machtbruch_charging() -> bool:
	"""Returns true if currently charging"""
	return is_charging
