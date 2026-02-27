extends Node
class_name WeaponGlowSystem

## Generic weapon glow system that pulses a Sprite2D when combo attacks are ready.
## Signal-based: listens to EventBus, knows nothing about the combat system directly.

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var weapon_sprite_path: NodePath
@export var combo_ready_color: Color = Color(1.5, 1.2, 0.5)  # Gold pulse
@export var finisher_ready_color: Color = Color(2.0, 0.6, 0.2)  # Orange-red pulse
@export var pulse_speed: float = 0.4  # Seconds per pulse cycle
@export var is_player_2: bool = false  # Which player this belongs to

# ============================================================================
# STATE
# ============================================================================

var weapon_sprite: Sprite2D = null
var glow_tween: Tween = null
var original_modulate: Color = Color.WHITE
var is_glowing: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get weapon sprite reference
	if weapon_sprite_path:
		weapon_sprite = get_node_or_null(weapon_sprite_path)

	if not weapon_sprite:
		# Fallback: try sibling nodes
		var parent = get_parent()
		if parent:
			weapon_sprite = parent.get_node_or_null("StaffSprite") if not is_player_2 else parent.get_node_or_null("SenseSprite")

	if weapon_sprite:
		original_modulate = weapon_sprite.modulate

	# Connect to EventBus signals
	if not is_player_2:
		# P1 signals
		EventBus.combo_finisher_ready.connect(_on_combo_finisher_ready)
		EventBus.machtbruch_available.connect(_on_machtbruch_available)
		EventBus.combo_broken.connect(_on_combo_broken)
		EventBus.combo_finisher_executed.connect(_on_combo_executed)
		EventBus.machtbruch_released.connect(_on_ability_used)
		EventBus.machtbruch_cancelled.connect(_on_ability_used_no_args)
	else:
		# P2 signals
		EventBus.p2_combo_finisher_ready.connect(_on_combo_finisher_ready)
		EventBus.p2_combo_broken.connect(_on_combo_broken)
		EventBus.p2_combo_finisher_executed.connect(_on_combo_executed)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_combo_finisher_ready() -> void:
	start_glow(combo_ready_color)

func _on_machtbruch_available() -> void:
	start_glow(finisher_ready_color)

func _on_combo_broken(_final_count: int = 0) -> void:
	stop_glow()

func _on_combo_executed(_count: int = 0) -> void:
	flash_once(Color.WHITE)

func _on_ability_used(_tier: int = 0, _damage: int = 0, _radius: float = 0.0) -> void:
	stop_glow()

func _on_ability_used_no_args() -> void:
	stop_glow()

# ============================================================================
# GLOW CONTROL
# ============================================================================

func start_glow(color: Color) -> void:
	if not weapon_sprite or not weapon_sprite.visible:
		return

	is_glowing = true
	_kill_tween()

	glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(weapon_sprite, "modulate", color, pulse_speed)
	glow_tween.tween_property(weapon_sprite, "modulate", original_modulate, pulse_speed)

func stop_glow() -> void:
	if not is_glowing:
		return

	is_glowing = false
	_kill_tween()

	if weapon_sprite:
		weapon_sprite.modulate = original_modulate

func flash_once(color: Color) -> void:
	_kill_tween()
	is_glowing = false

	if not weapon_sprite:
		return

	glow_tween = create_tween()
	glow_tween.tween_property(weapon_sprite, "modulate", color, 0.1)
	glow_tween.tween_property(weapon_sprite, "modulate", original_modulate, 0.3)

# ============================================================================
# UTILITY
# ============================================================================

func _kill_tween() -> void:
	if glow_tween and glow_tween.is_valid():
		glow_tween.kill()
		glow_tween = null
