extends Node2D
## CombatSystem handles player combat, combos, and attack hitboxes
class_name CombatSystem

# ============ REFERENCES ============
@onready var player: CharacterBody2D = get_parent()
@onready var hitbox: Area2D = $HitboxComponent
@onready var movement_controller: MovementController = player.get_node_or_null("MovementController")

# ============ INPUT CONFIGURATION ============
@export var input_prefix: String = "p1_"  # P1 by default, P2 uses "p2_"
@onready var combo_tracker: ComboTracker = null  # Will create dynamically
@onready var resonance_system: ResonanceSystem = null  # Will create dynamically
@onready var parry_block_system: ParryBlockSystem = null  # Will create from scene
@onready var leap_ender_system: LeapEnderSystem = null  # Will create dynamically
@onready var machtbruch: Machtbruch = null  # Will create dynamically (COMMIT 019)
@onready var machtstoss: Machtstoss = null  # Will create dynamically (COMMIT 020)
@onready var urteil: Urteil = null  # Will create dynamically (COMMIT 021)
@onready var echo: Echo = null  # Will create dynamically (COMMIT 022)
@onready var staff_sprite: Node2D = null  # Will create dynamically
@onready var staff_top: ColorRect = null  # Staff tip for color changes

# ============ ATTACK CONFIGURATION ============
@export var attack_damages: Array[int] = [10, 12, 15]  # Damage for attacks 1, 2, 3
@export var attack_durations: Array[float] = [0.3, 0.35, 0.4]  # Duration of each attack
@export var combo_window: float = 0.5  # Time window to continue combo

# ============ COMBO STATE ============
var current_combo: int = 0  # 0 = no combo, 1-3 = attack number
var is_attacking: bool = false
var combo_timer: float = 0.0
var attack_timer: float = 0.0

# ============ ATTACK QUEUE ============
var attack_queued: bool = false

# ============ COMBAT CONTROL ============
var combat_enabled: bool = true


func _ready() -> void:
	if not hitbox:
		push_error("[CombatSystem] HitboxComponent not found as child!")
		return

	# Ensure hitbox is deactivated initially
	hitbox.monitoring = false
	hitbox.visible = false

	# Create combo tracker
	_create_combo_tracker()

	# Create resonance system
	_create_resonance_system()

	# Create parry/block system
	_create_parry_block_system()

	# Create leap ender system
	_create_leap_ender_system()

	# Create Machtbruch system (COMMIT 019)
	_create_machtbruch_system()

	# Create Machtstoß system (COMMIT 020)
	_create_machtstoss_system()

	# Create Urteil system (COMMIT 021)
	_create_urteil_system()

	# Create Echo system (COMMIT 022)
	_create_echo_system()

	# Create staff visual
	_create_staff_visual()


func _process(delta: float) -> void:
	_update_combo_timer(delta)
	_update_attack_timer(delta)
	_update_staff_facing()


func _input(event: InputEvent) -> void:
	var attack_action = input_prefix + "attack"
	# Fallback to "light_attack" if p1_attack doesn't exist (backwards compatibility)
	if not InputMap.has_action(attack_action):
		attack_action = "light_attack"

	if event.is_action_pressed(attack_action):
		_request_attack()


# ============ ATTACK SYSTEM ============
func _request_attack() -> void:
	"""Requests an attack (queues it if currently attacking)"""
	# Check if combat is enabled
	if not combat_enabled:
		return

	if is_attacking:
		attack_queued = true
		return

	_perform_attack()


func _perform_attack() -> void:
	"""Executes an attack in the combo sequence"""
	# Determine next combo number
	if combo_timer > 0 and current_combo < 3:
		current_combo += 1
	else:
		current_combo = 1

	is_attacking = true
	attack_queued = false
	combo_timer = combo_window
	attack_timer = attack_durations[current_combo - 1]

	# Update hitbox damage
	if hitbox.has_method("set_damage"):
		hitbox.set_damage(attack_damages[current_combo - 1])

	# Activate hitbox
	_activate_hitbox()

	# Stop horizontal movement during attack
	if player:
		player.velocity.x = 0

	# Play audio
	AudioManager.play_sfx("attack_" + str(current_combo))

	# Emit signal
	EventBus.player_attacked.emit(current_combo)

	# Update staff tip color (Black → White progression)
	_update_staff_tip_color(current_combo)

	# Animate player
	_animate_player_attack(current_combo)

	# Animate staff
	_animate_staff_attack(current_combo)

	print("[CombatSystem] Attack ", current_combo, " - Damage: ", attack_damages[current_combo - 1])


func _update_attack_timer(delta: float) -> void:
	"""Updates the attack animation timer"""
	if not is_attacking:
		return

	attack_timer -= delta

	if attack_timer <= 0:
		_end_attack()


func _end_attack() -> void:
	"""Ends the current attack"""
	is_attacking = false
	_deactivate_hitbox()

	# Check for queued attack
	if attack_queued:
		_perform_attack()


func _update_combo_timer(delta: float) -> void:
	"""Updates the combo window timer"""
	if combo_timer > 0:
		combo_timer -= delta

		if combo_timer <= 0:
			_reset_combo()


func _reset_combo() -> void:
	"""Resets the combo counter"""
	current_combo = 0
	print("[CombatSystem] Combo reset")


# ============ HITBOX MANAGEMENT ============
func _activate_hitbox() -> void:
	"""Activates the hitbox for damage detection"""
	if not hitbox:
		return

	# Call the hitbox's activate() method instead of setting properties directly
	if hitbox.has_method("activate"):
		hitbox.activate()
	else:
		# Fallback
		hitbox.monitoring = true
		hitbox.visible = true

	# Position hitbox based on facing direction
	if movement_controller:
		var facing: int = movement_controller.get_facing_direction()
		# Scale and position the hitbox based on facing
		hitbox.scale.x = abs(hitbox.scale.x) * facing
		# Also flip the position.x to match facing direction
		hitbox.position.x = abs(hitbox.position.x) * facing


func _deactivate_hitbox() -> void:
	"""Deactivates the hitbox"""
	if not hitbox:
		return

	# Call the hitbox's deactivate() method
	if hitbox.has_method("deactivate"):
		hitbox.deactivate()
	else:
		# Fallback
		hitbox.monitoring = false
		hitbox.visible = false


# ============ COMBO TRACKER ============
func _create_combo_tracker() -> void:
	"""Creates the combo tracker component."""
	combo_tracker = ComboTracker.new()
	combo_tracker.name = "ComboTracker"
	add_child(combo_tracker)

	# Connect to combo signals for visual feedback via EventBus
	EventBus.combo_increased.connect(_on_combo_increased)
	EventBus.combo_finisher_executed.connect(_on_finisher_executed)
	combo_tracker.combo_milestone_reached.connect(_on_combo_milestone)

	print("[CombatSystem] ComboTracker created with flash effects")


# ============ RESONANCE SYSTEM ============
func _create_resonance_system() -> void:
	"""Creates the resonance system component."""
	resonance_system = ResonanceSystem.new()
	resonance_system.name = "ResonanceSystem"
	add_child(resonance_system)

	# Connect to resonance full signal (preparation for Commit 003)
	resonance_system.resonance_full.connect(_on_resonance_full)

	print("[CombatSystem] ResonanceSystem created")


func _on_resonance_full() -> void:
	"""Called when resonance reaches 100% (preparation for Commit 003)."""
	print("[CombatSystem] Resonance full! (Mode activation in Commit 003)")


# ============ PARRY/BLOCK SYSTEM ============
func _create_parry_block_system() -> void:
	"""Creates the spatial parry/block system component."""
	# Load the ParryBlockSystem scene
	var parry_block_scene = preload("res://player/combat_system/parry_block_system.tscn")
	parry_block_system = parry_block_scene.instantiate()
	parry_block_system.name = "ParryBlockSystem"
	add_child(parry_block_system)

	# Connect to parry signals
	parry_block_system.perfect_parry_executed.connect(_on_perfect_parry)
	parry_block_system.normal_block_executed.connect(_on_normal_block)

	print("[CombatSystem] ParryBlockSystem created (spatial detection)")


func _on_perfect_parry(enemy: Node) -> void:
	"""Called when a perfect parry is executed."""
	print("[CombatSystem] Perfect parry on %s!" % enemy.name)


func _on_normal_block(enemy: Node) -> void:
	"""Called when a normal block is executed."""
	print("[CombatSystem] Normal block on %s!" % enemy.name)


# ============ LEAP ENDER SYSTEM ============
func _create_leap_ender_system() -> void:
	"""Creates the leap ender system component."""
	leap_ender_system = LeapEnderSystem.new()
	leap_ender_system.name = "LeapEnderSystem"
	add_child(leap_ender_system)

	# Connect to leap ender signals (optional)
	leap_ender_system.leap_ender_started.connect(_on_leap_ender_started)
	leap_ender_system.leap_ender_completed.connect(_on_leap_ender_completed)

	print("[CombatSystem] LeapEnderSystem created")


func _create_machtbruch_system() -> void:
	"""Creates the Machtbruch (Resonance Burst) system component (COMMIT 019)."""
	machtbruch = Machtbruch.new()
	machtbruch.name = "Machtbruch"
	add_child(machtbruch)

	print("[CombatSystem] Machtbruch created")


func _create_machtstoss_system() -> void:
	"""Creates the Machtstoß (Knockback Wave) system component (COMMIT 020)."""
	machtstoss = Machtstoss.new()
	machtstoss.name = "Machtstoss"
	add_child(machtstoss)

	print("[CombatSystem] Machtstoß created")


func _create_urteil_system() -> void:
	"""Creates the Urteil (Death Mark) system component (COMMIT 021)."""
	urteil = Urteil.new()
	urteil.name = "Urteil"
	add_child(urteil)

	print("[CombatSystem] Urteil der Zerstörung created")


func _create_echo_system() -> void:
	"""Creates the Echo (Mana Gain Buff) system component (COMMIT 022)."""
	echo = Echo.new()
	echo.name = "Echo"
	add_child(echo)

	print("[CombatSystem] Echo von Urgathon created")


func _on_leap_ender_started(direction: Vector2) -> void:
	"""Called when leap ender starts."""
	print("[CombatSystem] Leap ender started! Direction: %v" % direction)


func _on_leap_ender_completed() -> void:
	"""Called when leap ender completes."""
	print("[CombatSystem] Leap ender completed!")


# ============ STAFF VISUAL ============
func _update_staff_facing() -> void:
	"""Updates staff position based on facing direction"""
	if not staff_sprite or not movement_controller:
		return

	var facing: int = movement_controller.get_facing_direction()

	# Flip staff horizontally based on facing direction
	# Facing right (1) = staff on right side
	# Facing left (-1) = staff on left side (flipped)
	staff_sprite.scale.x = facing


func _create_staff_visual() -> void:
	"""Creates a simple staff sprite using ColorRects"""
	# Create staff container
	staff_sprite = Node2D.new()
	staff_sprite.name = "StaffSprite"
	add_child(staff_sprite)

	# Staff handle (brown) - Much longer now!
	var handle: ColorRect = ColorRect.new()
	handle.size = Vector2(10, 80)  # 10x80 instead of 6x48
	handle.position = Vector2(30, -40)  # Further from player
	handle.color = Color(0.4, 0.25, 0.1, 1)
	staff_sprite.add_child(handle)

	# Staff top (purple/magic) - Bigger and more visible
	staff_top = ColorRect.new()
	staff_top.name = "StaffTip"
	staff_top.size = Vector2(20, 20)  # 20x20 instead of 12x12
	staff_top.position = Vector2(25, -50)  # At the top of the staff
	staff_top.color = Color(0.7, 0.3, 1, 1)  # Initial purple
	staff_sprite.add_child(staff_top)

	# Staff is now ALWAYS visible!
	staff_sprite.visible = true
	staff_sprite.rotation = 0  # Default idle position


func _animate_staff_attack(attack_num: int) -> void:
	"""Animates the staff during attack"""
	if not staff_sprite:
		return

	# Different animations for each combo
	var tween: Tween = create_tween()

	match attack_num:
		1:  # Overhead swing
			tween.tween_property(staff_sprite, "rotation", -PI/3, attack_durations[0] * 0.3)
			tween.tween_property(staff_sprite, "rotation", PI/6, attack_durations[0] * 0.7)
		2:  # Side swing
			tween.tween_property(staff_sprite, "rotation", -PI/6, attack_durations[1] * 0.3)
			tween.tween_property(staff_sprite, "rotation", PI/3, attack_durations[1] * 0.7)
		3:  # Upward thrust
			tween.tween_property(staff_sprite, "rotation", PI/4, attack_durations[2] * 0.4)
			tween.tween_property(staff_sprite, "rotation", -PI/4, attack_durations[2] * 0.6)

	# Return to idle position after attack
	await tween.finished
	var return_tween: Tween = create_tween()
	return_tween.tween_property(staff_sprite, "rotation", 0.0, 0.1)


func _animate_player_attack(attack_num: int) -> void:
	"""Animates player sprite during attack"""
	var sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		return

	var tween = create_tween()
	tween.set_parallel(true)

	match attack_num:
		1:  # Quick jab - forward thrust
			tween.tween_property(sprite, "position:x", 15, attack_durations[0] * 0.4)
			tween.tween_property(sprite, "scale", Vector2(1.15, 0.85), attack_durations[0] * 0.4)
			tween.chain().tween_property(sprite, "position:x", 0, attack_durations[0] * 0.6)
			tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), attack_durations[0] * 0.6)
		2:  # Medium swing - upward arc
			tween.tween_property(sprite, "position:y", -20, attack_durations[1] * 0.3)
			tween.tween_property(sprite, "position:x", 10, attack_durations[1] * 0.3)
			tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), attack_durations[1] * 0.3)
			tween.chain().tween_property(sprite, "position:y", 0, attack_durations[1] * 0.7)
			tween.parallel().tween_property(sprite, "position:x", 0, attack_durations[1] * 0.7)
			tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), attack_durations[1] * 0.7)
		3:  # Heavy slam - big windup and strike (NO KNOCKBACK/PULLBACK)
			# Windup (up only, no pullback)
			tween.tween_property(sprite, "position:y", -25, attack_durations[2] * 0.2)
			tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), attack_durations[2] * 0.2)
			# Strike (forward slam, reduced from 20 to 15)
			tween.chain().tween_property(sprite, "position:x", 15, attack_durations[2] * 0.3)
			tween.parallel().tween_property(sprite, "position:y", 5, attack_durations[2] * 0.3)
			tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.15), attack_durations[2] * 0.3)
			# Recovery
			tween.chain().tween_property(sprite, "position:x", 0, attack_durations[2] * 0.5)
			tween.parallel().tween_property(sprite, "position:y", 0, attack_durations[2] * 0.5)
			tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), attack_durations[2] * 0.5)


func _update_staff_tip_color(attack_num: int) -> void:
	"""Updates staff tip color based on attack in combo (Black → White)"""
	if not staff_top:
		return

	var tip_color: Color
	match attack_num:
		1:  # Black/Dark gray (start of combo)
			tip_color = Color(0.2, 0.15, 0.25, 1.0)  # Dark purple-black
		2:  # Medium gray
			tip_color = Color(0.5, 0.45, 0.6, 1.0)  # Medium purple-gray
		3:  # White/Bright (end of combo)
			tip_color = Color(1.0, 0.95, 1.0, 1.0)  # Bright white-purple
		_:
			tip_color = Color(0.7, 0.3, 1.0, 1.0)  # Default purple

	# Animate color change
	var tween = create_tween()
	tween.tween_property(staff_top, "color", tip_color, 0.1)


# ============ GETTERS ============
func can_attack() -> bool:
	"""Returns true if player can perform an attack"""
	return combat_enabled and (not is_attacking or attack_queued == false)


func set_combat_enabled(enabled: bool) -> void:
	"""Enables/disables combat (for dodge, etc.)"""
	combat_enabled = enabled
	print("[CombatSystem] Combat %s" % ("enabled" if enabled else "disabled"))


func get_current_combo() -> int:
	"""Returns the current combo number (0-3)"""
	return current_combo


# ============ COMBO VISUAL FEEDBACK ============
func _on_combo_increased(new_count: int, _multiplier: float) -> void:
	"""Called when combo increases - flash player with blue tint"""
	var flash_color = _get_combo_flash_color(new_count)
	_flash_player(flash_color, 0.3)  # 3x longer (was 0.1)

func _on_combo_milestone(count: int) -> void:
	"""Called when combo milestone reached - bigger flash"""
	var flash_color = _get_milestone_flash_color(count)
	_flash_player(flash_color, 0.6)  # 3x longer (was 0.2)
	print("[CombatSystem] Combo milestone flash: %d hits!" % count)

func _on_finisher_executed(combo_count: int) -> void:
	"""Called when finisher executed - brightest flash"""
	var flash_color = Color(1.0, 2.0, 3.0, 1.0)  # 2x stronger - Bright cyan
	_flash_player(flash_color, 0.45)  # 3x longer (was 0.15)
	print("[CombatSystem] Finisher flash at combo %d!" % combo_count)

func _get_combo_flash_color(combo_count: int) -> Color:
	"""Returns blue spectrum color based on combo count (2x stronger)"""
	if combo_count < 5:
		return Color(1.4, 1.8, 2.6, 1.0)  # 2x stronger - Light blue
	elif combo_count < 10:
		return Color(1.0, 1.4, 3.0, 1.0)  # 2x stronger - Blue
	elif combo_count < 20:
		return Color(0.6, 1.0, 3.0, 1.0)  # 2x stronger - Dark blue
	else:
		return Color(0.8, 1.6, 3.0, 1.0)  # 2x stronger - Bright cyan

func _get_milestone_flash_color(milestone: int) -> Color:
	"""Returns special blue color for milestone (2x stronger)"""
	match milestone:
		5:
			return Color(1.2, 2.0, 3.0, 1.0)   # 2x stronger - Sky blue
		10:
			return Color(0.8, 1.6, 3.0, 1.0)   # 2x stronger - Ocean blue
		25:
			return Color(0.6, 1.2, 3.0, 1.0)   # 2x stronger - Deep blue
		50:
			return Color(1.0, 2.0, 3.0, 1.0)   # 2x stronger - Electric blue
		100:
			return Color(0.8, 2.4, 3.0, 1.0)   # 2x stronger - Ultra cyan
		_:
			return Color(1.0, 1.6, 3.0, 1.0)   # 2x stronger - Default blue

func _flash_player(flash_color: Color, duration: float) -> void:
	"""Flashes player sprite with given color"""
	var sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		return

	# Create flash tween
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", flash_color, 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, duration)
