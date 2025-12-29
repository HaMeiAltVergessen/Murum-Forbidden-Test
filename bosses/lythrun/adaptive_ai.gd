extends Node
## Adaptive AI Foundation for Lythrun Boss
## Tracks player behavior and adjusts boss difficulty

# ============================================================================
# REFERENCES
# ============================================================================

@export var boss: BaseBoss

# ============================================================================
# TRACKING VARIABLES
# ============================================================================

var player_parry_success_count: int = 0
var player_dodge_count: int = 0
var player_staff_throw_count: int = 0
var player_aggressive_playstyle: bool = false

# ============================================================================
# ADAPTIVE MODIFIERS
# ============================================================================

var telegraph_duration_modifier: float = 1.0  # Becomes shorter with many parries
var attack_speed_modifier: float = 1.0  # Increases with passive player

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	await get_tree().process_frame

	# Connect to player signals
	_connect_player_signals()

	print("[AdaptiveAI] Initialized for boss: ", boss.name if boss else "Unknown")


func _connect_player_signals() -> void:
	"""Connects to player signals for behavior tracking"""

	var player = get_tree().get_first_node_in_group("player")

	if not player:
		print("[AdaptiveAI] No player found")
		return

	# Connect signals if they exist
	if player.has_signal("parry_success"):
		player.parry_success.connect(_on_player_parry_success)

	if player.has_signal("dodge_performed"):
		player.dodge_performed.connect(_on_player_dodge)

	if player.has_signal("staff_thrown"):
		player.staff_thrown.connect(_on_player_staff_throw)

	print("[AdaptiveAI] Connected to player signals")


# ============================================================================
# PLAYER BEHAVIOR TRACKING
# ============================================================================

func _on_player_parry_success() -> void:
	"""Called when player successfully parries"""

	player_parry_success_count += 1

	# After 3+ successful parries: Shorten telegraphs
	if player_parry_success_count >= 3:
		telegraph_duration_modifier = 0.7
		print("[AdaptiveAI] Player parries frequently - Telegraphs shortened to 70%")


func _on_player_dodge() -> void:
	"""Called when player dodges"""

	player_dodge_count += 1


func _on_player_staff_throw() -> void:
	"""Called when player throws staff"""

	player_staff_throw_count += 1

	# Player uses Staff Throw frequently → Aggressive playstyle
	if player_staff_throw_count >= 5:
		player_aggressive_playstyle = true
		print("[AdaptiveAI] Aggressive player detected (Staff Throws: %d)" % player_staff_throw_count)


# ============================================================================
# ADAPTIVE DIFFICULTY METHODS
# ============================================================================

func get_telegraph_duration(base_duration: float) -> float:
	"""Returns modified telegraph duration based on player skill"""
	return base_duration * telegraph_duration_modifier


func get_attack_speed_multiplier() -> float:
	"""Returns attack speed multiplier"""
	return attack_speed_modifier


func should_counter_staff_throw() -> bool:
	"""Returns if boss should counter staff throws (catches staff mid-air)"""

	# After many staff throws: 30% chance to counter
	return player_staff_throw_count >= 8 and randf() < 0.3


# ============================================================================
# ANALYTICS
# ============================================================================

func get_player_behavior_stats() -> Dictionary:
	"""Returns player behavior statistics"""

	return {
		"parry_count": player_parry_success_count,
		"dodge_count": player_dodge_count,
		"staff_throw_count": player_staff_throw_count,
		"is_aggressive": player_aggressive_playstyle,
		"telegraph_modifier": telegraph_duration_modifier,
		"attack_speed_modifier": attack_speed_modifier
	}
