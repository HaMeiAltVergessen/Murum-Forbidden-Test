extends CanvasLayer
## P2 Abilities - Displays Lythrun's ability cooldowns on the right side
## Shows: Shadow Dash, Void Parry, Phase-Shift

# ============ ABILITY TIMER LABELS ============
@onready var shadow_dash_timer_label: Label = $MarginContainer/VBoxContainer/ShadowDashAbility/AbilityContent/VBox/TimerLabel
@onready var void_parry_timer_label: Label = $MarginContainer/VBoxContainer/VoidParryAbility/AbilityContent/VBox/TimerLabel
@onready var phase_shift_timer_label: Label = $MarginContainer/VBoxContainer/PhaseShiftAbility/AbilityContent/VBox/TimerLabel

# ============ ABILITY PANELS ============
@onready var shadow_dash_panel: PanelContainer = $MarginContainer/VBoxContainer/ShadowDashAbility
@onready var void_parry_panel: PanelContainer = $MarginContainer/VBoxContainer/VoidParryAbility
@onready var phase_shift_panel: PanelContainer = $MarginContainer/VBoxContainer/PhaseShiftAbility

# ============ PLAYER REFERENCE ============
var player: CharacterBody2D = null

# ============ COOLDOWN TRACKING ============
var shadow_dash_cooldown: float = 0.0
var void_parry_cooldown: float = 0.0
var phase_shift_cooldown: float = 0.0

func _ready() -> void:
	# Initially hide all cooldown timers
	_reset_all_timers()

	# Hide by default (only show when P2 joins)
	visible = false

	# Connect to CoopManager signals
	if CoopManager:
		CoopManager.p2_joined.connect(_on_p2_joined)
		CoopManager.p2_left.connect(_on_p2_left)

	print("[P2 Abilities] Initialized")

func set_player(p: CharacterBody2D) -> void:
	"""Set player reference"""
	player = p

	if not player:
		return

	print("[P2 Abilities] Player reference set")

func _on_p2_joined() -> void:
	"""Show P2 ability display when P2 joins"""
	visible = true
	print("[P2 Abilities] Display shown")

func _on_p2_left() -> void:
	"""Hide P2 ability display when P2 leaves"""
	visible = false
	print("[P2 Abilities] Display hidden")

func _process(delta: float) -> void:
	"""Update all cooldown displays every frame"""
	if not player or not visible:
		return

	# Update cooldown timers
	if shadow_dash_cooldown > 0.0:
		shadow_dash_cooldown -= delta
	if void_parry_cooldown > 0.0:
		void_parry_cooldown -= delta
	if phase_shift_cooldown > 0.0:
		phase_shift_cooldown -= delta

	# Poll player for cooldown states
	_poll_player_cooldowns()

	# Update displays
	_update_shadow_dash_display()
	_update_void_parry_display()
	_update_phase_shift_display()

func _poll_player_cooldowns() -> void:
	"""Poll player script for cooldown active flags and update local timers"""
	if not player:
		return

	# Shadow Dash - check if cooldown just started
	if "shadow_dash_cooldown_active" in player:
		if player.shadow_dash_cooldown_active and shadow_dash_cooldown <= 0.0:
			# Cooldown just started
			if "SHADOW_DASH_COOLDOWN" in player:
				shadow_dash_cooldown = player.SHADOW_DASH_COOLDOWN

	# Void Parry - check if cooldown just started
	if "void_parry_cooldown_active" in player:
		if player.void_parry_cooldown_active and void_parry_cooldown <= 0.0:
			# Cooldown just started
			if "VOID_PARRY_COOLDOWN" in player:
				void_parry_cooldown = player.VOID_PARRY_COOLDOWN

	# Phase-Shift - check if cooldown just started
	if "phase_shift_cooldown_active" in player:
		if player.phase_shift_cooldown_active and phase_shift_cooldown <= 0.0:
			# Cooldown just started
			if "PHASE_SHIFT_COOLDOWN" in player:
				phase_shift_cooldown = player.PHASE_SHIFT_COOLDOWN

# ============ SHADOW DASH COOLDOWN ============

func _update_shadow_dash_display() -> void:
	"""Update Shadow Dash cooldown display"""
	if shadow_dash_cooldown > 0.0:
		shadow_dash_timer_label.text = "%.1f" % shadow_dash_cooldown
		_set_panel_on_cooldown(shadow_dash_panel)
	else:
		shadow_dash_timer_label.text = ""
		_set_panel_ready(shadow_dash_panel)

# ============ VOID PARRY COOLDOWN ============

func _update_void_parry_display() -> void:
	"""Update Void Parry cooldown display"""
	if void_parry_cooldown > 0.0:
		void_parry_timer_label.text = "%.1f" % void_parry_cooldown
		_set_panel_on_cooldown(void_parry_panel)
	else:
		void_parry_timer_label.text = ""
		_set_panel_ready(void_parry_panel)

# ============ PHASE-SHIFT COOLDOWN ============

func _update_phase_shift_display() -> void:
	"""Update Phase-Shift cooldown display"""
	if phase_shift_cooldown > 0.0:
		phase_shift_timer_label.text = "%.1f" % phase_shift_cooldown
		_set_panel_on_cooldown(phase_shift_panel)
	else:
		phase_shift_timer_label.text = ""
		_set_panel_ready(phase_shift_panel)

# ============ VISUAL HELPERS ============

func _set_panel_on_cooldown(panel: PanelContainer) -> void:
	"""Set panel to cooldown visual state (dimmed, purple tint for shadow)"""
	if panel:
		panel.modulate = Color(0.6, 0.4, 0.8, 0.7)  # Purple-ish shadow tint

func _set_panel_ready(panel: PanelContainer) -> void:
	"""Set panel to ready visual state (bright, purple accent)"""
	if panel:
		panel.modulate = Color(0.9, 0.8, 1.0, 1.0)  # Light purple for shadow theme

func _reset_all_timers() -> void:
	"""Reset all timer labels to empty"""
	if shadow_dash_timer_label:
		shadow_dash_timer_label.text = ""
	if void_parry_timer_label:
		void_parry_timer_label.text = ""
	if phase_shift_timer_label:
		phase_shift_timer_label.text = ""
