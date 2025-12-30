extends Node
## Adaptive AI System for Lythrun Boss (Complete)
## Tracks player behavior and dynamically adjusts boss difficulty

# ============================================================================
# REFERENCES
# ============================================================================

@export var boss: BaseBoss

# ============================================================================
# TRACKING VARIABLES
# ============================================================================

# Player Behavior
var player_parry_success_count: int = 0
var player_parry_fail_count: int = 0
var player_dodge_count: int = 0
var player_dash_count: int = 0
var player_staff_throw_count: int = 0
var player_urgathon_usage_count: int = 0
var player_hit_count: int = 0  # How many times boss was hit

# Playstyle Detection
var player_aggressive_playstyle: bool = false
var player_defensive_playstyle: bool = false
var player_parry_focused: bool = false
var player_urgathon_reliant: bool = false

# ============================================================================
# ADAPTIVE MODIFIERS
# ============================================================================

# Phase 1
var telegraph_duration_modifier: float = 1.0  # Base: 1.0
var attack_speed_modifier: float = 1.0

# Phase 2+
var feint_attack_chance: float = 0.0  # Chance for fake telegraph
var aoe_radius_modifier: float = 1.0  # Larger AoE with many dashes
var defensive_mode_active: bool = false  # Against Urgathon

# Phase 3+
var pattern_shuffle_enabled: bool = false  # Random pattern order
var max_adaptation_active: bool = false

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

	if player.has_signal("parry_failed"):
		player.parry_failed.connect(_on_player_parry_failed)

	if player.has_signal("dodge_performed"):
		player.dodge_performed.connect(_on_player_dodge)

	if player.has_signal("dash_performed"):
		player.dash_performed.connect(_on_player_dash)

	if player.has_signal("staff_thrown"):
		player.staff_thrown.connect(_on_player_staff_throw)

	if player.has_signal("urgathon_activated"):
		player.urgathon_activated.connect(_on_player_urgathon)

	if player.has_signal("hit_landed"):
		player.hit_landed.connect(_on_player_hit_landed)

	print("[AdaptiveAI] Connected to player signals")


# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_player_parry_success() -> void:
	"""Called when player successfully parries"""

	player_parry_success_count += 1

	# Player focuses on parrying
	if player_parry_success_count >= 3:
		player_parry_focused = true
		telegraph_duration_modifier = 0.7  # Faster telegraphs

		print("[AdaptiveAI] Parry focus detected - Telegraphs shortened")

	# Phase 2+: Introduce feint attacks
	if player_parry_success_count >= 5 and boss.has_node("Components/PhaseManager"):
		var phase_mgr = boss.get_node("Components/PhaseManager")
		if phase_mgr.current_phase >= 2:
			feint_attack_chance = 0.25  # 25% chance
			print("[AdaptiveAI] Feint attacks activated (25%)")

	# Phase 3+: Increased feint rate
	if player_parry_success_count >= 8 and boss.has_node("Components/PhaseManager"):
		var phase_mgr = boss.get_node("Components/PhaseManager")
		if phase_mgr.current_phase >= 3:
			feint_attack_chance = 0.40  # 40% chance
			print("[AdaptiveAI] Feint attacks increased (40%)")


func _on_player_parry_failed() -> void:
	"""Called when player fails a parry"""

	player_parry_fail_count += 1

	# Player is bad at parrying → Keep normal telegraphs
	if player_parry_fail_count >= 5:
		player_parry_focused = false
		telegraph_duration_modifier = 1.0


func _on_player_dodge() -> void:
	"""Called when player dodges"""

	player_dodge_count += 1


func _on_player_dash() -> void:
	"""Called when player dashes"""

	player_dash_count += 1

	# Many dashes → Player is mobile
	if player_dash_count >= 8:
		player_defensive_playstyle = false
		aoe_radius_modifier = 1.3  # Larger AoE attacks

		print("[AdaptiveAI] High mobility detected - AoE enlarged")


func _on_player_staff_throw() -> void:
	"""Called when player throws staff"""

	player_staff_throw_count += 1

	# Aggressive player
	if player_staff_throw_count >= 5:
		player_aggressive_playstyle = true
		attack_speed_modifier = 1.15  # Boss attacks faster

		print("[AdaptiveAI] Aggressive playstyle - Attack speed increased")


func _on_player_urgathon() -> void:
	"""Called when player activates Urgathon"""

	player_urgathon_usage_count += 1

	# Player relies on Urgathon frequently
	if player_urgathon_usage_count >= 2:
		player_urgathon_reliant = true
		defensive_mode_active = true

		print("[AdaptiveAI] Urgathon reliance detected - Defensive mode activated")


func _on_player_hit_landed(_damage: float) -> void:
	"""Called when player hits boss"""

	player_hit_count += 1


# ============================================================================
# ADAPTIVE GETTERS
# ============================================================================

func get_telegraph_duration(base_duration: float) -> float:
	"""Returns modified telegraph duration based on player skill"""
	return base_duration * telegraph_duration_modifier


func should_use_feint_attack() -> bool:
	"""Returns if boss should use feint attack"""

	# Only if player is parry-focused
	if not player_parry_focused:
		return false

	return randf() < feint_attack_chance


func get_aoe_radius(base_radius: float) -> float:
	"""Returns modified AoE radius"""
	return base_radius * aoe_radius_modifier


func is_defensive_mode_active() -> bool:
	"""Returns if defensive mode is active (anti-Urgathon)"""
	return defensive_mode_active


func should_counter_staff_throw() -> bool:
	"""Returns if boss should counter staff throws (catches mid-air)"""

	# Phase 3+: Lythrun can catch staff
	if not boss or not boss.has_node("Components/PhaseManager"):
		return false

	var phase_mgr = boss.get_node("Components/PhaseManager")
	if phase_mgr.current_phase < 3:
		return false

	return player_staff_throw_count >= 8 and randf() < 0.25


func should_shuffle_pattern() -> bool:
	"""Returns if attack pattern should be shuffled"""
	return pattern_shuffle_enabled


# ============================================================================
# PHASE-SPECIFIC ADAPTATIONS
# ============================================================================

func on_phase_changed(new_phase: int) -> void:
	"""Called when boss changes phase"""

	match new_phase:
		2:
			activate_phase_2_adaptations()
		3:
			activate_phase_3_adaptations()
		4:
			activate_phase_4_adaptations()


func activate_phase_2_adaptations() -> void:
	"""Activates Phase 2 adaptive mechanics"""

	print("[AdaptiveAI] Phase 2 - Counter mechanics activated")

	# Counters become active
	if player_parry_focused:
		feint_attack_chance = max(feint_attack_chance, 0.25)


func activate_phase_3_adaptations() -> void:
	"""Activates Phase 3 adaptive mechanics"""

	print("[AdaptiveAI] Phase 3 - Maximum adaptation")

	# Pattern shuffle
	pattern_shuffle_enabled = true

	# All modifiers strengthened
	if player_parry_focused:
		feint_attack_chance = 0.40

	if player_dash_count >= 8:
		aoe_radius_modifier = 1.5


func activate_phase_4_adaptations() -> void:
	"""Activates Phase 4 adaptive mechanics (Desperate Mode)"""

	print("[AdaptiveAI] Phase 4 - DESPERATE MODE")

	max_adaptation_active = true

	# Extreme modifiers
	attack_speed_modifier = 1.3

	if player_parry_focused:
		feint_attack_chance = 0.50  # 50% feints


# ============================================================================
# ANALYTICS
# ============================================================================

func get_player_behavior_stats() -> Dictionary:
	"""Returns player behavior statistics"""

	return {
		"parry_success_count": player_parry_success_count,
		"parry_fail_count": player_parry_fail_count,
		"dodge_count": player_dodge_count,
		"dash_count": player_dash_count,
		"staff_throw_count": player_staff_throw_count,
		"urgathon_usage_count": player_urgathon_usage_count,
		"hit_count": player_hit_count,
		"is_aggressive": player_aggressive_playstyle,
		"is_defensive": player_defensive_playstyle,
		"is_parry_focused": player_parry_focused,
		"is_urgathon_reliant": player_urgathon_reliant,
		"telegraph_modifier": telegraph_duration_modifier,
		"attack_speed_modifier": attack_speed_modifier,
		"feint_chance": feint_attack_chance,
		"aoe_modifier": aoe_radius_modifier,
		"defensive_mode": defensive_mode_active
	}
