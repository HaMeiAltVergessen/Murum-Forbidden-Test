extends CanvasLayer
## P1 Abilities - Displays Murum's ability cooldowns on the left side
## Shows: Dash, Staff, Parry, Machtstoß, Urteil, Echo

# ============ ABILITY TIMER LABELS ============
@onready var dash_timer_label: Label = $MarginContainer/VBoxContainer/DashAbility/AbilityContent/VBox/TimerLabel
@onready var staff_timer_label: Label = $MarginContainer/VBoxContainer/StaffAbility/AbilityContent/VBox/TimerLabel
@onready var parry_timer_label: Label = $MarginContainer/VBoxContainer/ParryAbility/AbilityContent/VBox/TimerLabel
@onready var machtstoss_timer_label: Label = $MarginContainer/VBoxContainer/MachtstossAbility/AbilityContent/VBox/TimerLabel
@onready var urteil_timer_label: Label = $MarginContainer/VBoxContainer/UrteilAbility/AbilityContent/VBox/TimerLabel
@onready var echo_timer_label: Label = $MarginContainer/VBoxContainer/EchoAbility/AbilityContent/VBox/TimerLabel

# ============ ABILITY PANELS ============
@onready var dash_panel: PanelContainer = $MarginContainer/VBoxContainer/DashAbility
@onready var staff_panel: PanelContainer = $MarginContainer/VBoxContainer/StaffAbility
@onready var parry_panel: PanelContainer = $MarginContainer/VBoxContainer/ParryAbility
@onready var machtstoss_panel: PanelContainer = $MarginContainer/VBoxContainer/MachtstossAbility
@onready var urteil_panel: PanelContainer = $MarginContainer/VBoxContainer/UrteilAbility
@onready var echo_panel: PanelContainer = $MarginContainer/VBoxContainer/EchoAbility

# ============ PLAYER REFERENCE ============
var player: CharacterBody2D = null

# ============ COMPONENT REFERENCES ============
var movement_controller = null
var combat_system = null
var staff_controller = null
var parry_system = null
var machtstoss_system = null
var urteil_system = null
var echo_system = null

func _ready() -> void:
	# Initially hide all cooldown timers
	_reset_all_timers()
	print("[P1 Abilities] Initialized")

func set_player(p: CharacterBody2D) -> void:
	"""Set player reference and connect to ability systems"""
	player = p

	if not player:
		return

	# Get component references
	movement_controller = player.get_node_or_null("MovementController")
	combat_system = player.get_node_or_null("CombatSystem")

	if combat_system:
		staff_controller = combat_system.get_node_or_null("StaffController")
		parry_system = combat_system.get_node_or_null("ParryBlockSystem")
		machtstoss_system = combat_system.get_node_or_null("Machtstoss")
		urteil_system = combat_system.get_node_or_null("Urteil")
		echo_system = combat_system.get_node_or_null("Echo")

	# Connect signals if available
	_connect_ability_signals()

	print("[P1 Abilities] Player reference set")

func _connect_ability_signals() -> void:
	"""Connect to ability system signals for cooldown tracking"""
	# Machtstoß signals
	if machtstoss_system:
		if machtstoss_system.has_signal("machtstoss_cooldown_started"):
			machtstoss_system.machtstoss_cooldown_started.connect(_on_machtstoss_cooldown_started)
		if machtstoss_system.has_signal("machtstoss_cooldown_finished"):
			machtstoss_system.machtstoss_cooldown_finished.connect(_on_machtstoss_cooldown_finished)

	# Urteil signals
	if urteil_system:
		if urteil_system.has_signal("urteil_cooldown_started"):
			urteil_system.urteil_cooldown_started.connect(_on_urteil_cooldown_started)
		if urteil_system.has_signal("urteil_cooldown_finished"):
			urteil_system.urteil_cooldown_finished.connect(_on_urteil_cooldown_finished)

	# Echo signals
	if echo_system:
		if echo_system.has_signal("echo_cooldown_started"):
			echo_system.echo_cooldown_started.connect(_on_echo_cooldown_started)
		if echo_system.has_signal("echo_cooldown_finished"):
			echo_system.echo_cooldown_finished.connect(_on_echo_cooldown_finished)

func _process(delta: float) -> void:
	"""Update all cooldown displays every frame"""
	if not player:
		return

	_update_dash_display()
	_update_staff_display()
	_update_parry_display()
	_update_machtstoss_display()
	_update_urteil_display()
	_update_echo_display()

# ============ DASH COOLDOWN ============

func _update_dash_display() -> void:
	"""Update dash cooldown display"""
	if not movement_controller:
		return

	var cooldown_remaining = movement_controller.dash_cooldown_timer if "dash_cooldown_timer" in movement_controller else 0.0

	if cooldown_remaining > 0.0:
		dash_timer_label.text = "%.1f" % cooldown_remaining
		_set_panel_on_cooldown(dash_panel)
	else:
		dash_timer_label.text = ""
		_set_panel_ready(dash_panel)

# ============ STAFF COOLDOWN ============

func _update_staff_display() -> void:
	"""Update staff throw cooldown display"""
	if not staff_controller:
		return

	var cooldown_remaining = staff_controller.cooldown_timer if "cooldown_timer" in staff_controller else 0.0

	if cooldown_remaining > 0.0:
		staff_timer_label.text = "%.1f" % cooldown_remaining
		_set_panel_on_cooldown(staff_panel)
	else:
		staff_timer_label.text = ""
		_set_panel_ready(staff_panel)

# ============ PARRY COOLDOWN ============

func _update_parry_display() -> void:
	"""Update parry cooldown display"""
	if not parry_system:
		return

	var cooldown_remaining = parry_system.cooldown_timer if "cooldown_timer" in parry_system else 0.0

	if cooldown_remaining > 0.0:
		parry_timer_label.text = "%.1f" % cooldown_remaining
		_set_panel_on_cooldown(parry_panel)
	else:
		parry_timer_label.text = ""
		_set_panel_ready(parry_panel)

# ============ MACHTSTOSS COOLDOWN ============

func _update_machtstoss_display() -> void:
	"""Update Machtstoß cooldown display"""
	if not machtstoss_system:
		return

	if machtstoss_system.has_method("get_cooldown_remaining"):
		var cooldown_remaining = machtstoss_system.get_cooldown_remaining()

		if cooldown_remaining > 0.0:
			machtstoss_timer_label.text = "%.1f" % cooldown_remaining
			_set_panel_on_cooldown(machtstoss_panel)
		else:
			machtstoss_timer_label.text = ""
			_set_panel_ready(machtstoss_panel)

func _on_machtstoss_cooldown_started(_duration: float) -> void:
	"""Handle Machtstoß cooldown start"""
	_set_panel_on_cooldown(machtstoss_panel)

func _on_machtstoss_cooldown_finished() -> void:
	"""Handle Machtstoß cooldown finish"""
	_set_panel_ready(machtstoss_panel)

# ============ URTEIL COOLDOWN ============

func _update_urteil_display() -> void:
	"""Update Urteil cooldown display"""
	if not urteil_system:
		return

	if urteil_system.has_method("get_cooldown_remaining"):
		var cooldown_remaining = urteil_system.get_cooldown_remaining()

		if cooldown_remaining > 0.0:
			urteil_timer_label.text = "%.1f" % cooldown_remaining
			_set_panel_on_cooldown(urteil_panel)
		else:
			urteil_timer_label.text = ""
			_set_panel_ready(urteil_panel)

func _on_urteil_cooldown_started(_duration: float) -> void:
	"""Handle Urteil cooldown start"""
	_set_panel_on_cooldown(urteil_panel)

func _on_urteil_cooldown_finished() -> void:
	"""Handle Urteil cooldown finish"""
	_set_panel_ready(urteil_panel)

# ============ ECHO COOLDOWN ============

func _update_echo_display() -> void:
	"""Update Echo cooldown display"""
	if not echo_system:
		return

	if echo_system.has_method("get_cooldown_remaining"):
		var cooldown_remaining = echo_system.get_cooldown_remaining()

		if cooldown_remaining > 0.0:
			echo_timer_label.text = "%.1f" % cooldown_remaining
			_set_panel_on_cooldown(echo_panel)
		else:
			echo_timer_label.text = ""
			_set_panel_ready(echo_panel)

func _on_echo_cooldown_started(_duration: float) -> void:
	"""Handle Echo cooldown start"""
	_set_panel_on_cooldown(echo_panel)

func _on_echo_cooldown_finished() -> void:
	"""Handle Echo cooldown finish"""
	_set_panel_ready(echo_panel)

# ============ VISUAL HELPERS ============

func _set_panel_on_cooldown(panel: PanelContainer) -> void:
	"""Set panel to cooldown visual state (dimmed)"""
	if panel:
		panel.modulate = Color(0.5, 0.5, 0.5, 0.7)

func _set_panel_ready(panel: PanelContainer) -> void:
	"""Set panel to ready visual state (bright)"""
	if panel:
		panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _reset_all_timers() -> void:
	"""Reset all timer labels to empty"""
	if dash_timer_label:
		dash_timer_label.text = ""
	if staff_timer_label:
		staff_timer_label.text = ""
	if parry_timer_label:
		parry_timer_label.text = ""
	if machtstoss_timer_label:
		machtstoss_timer_label.text = ""
	if urteil_timer_label:
		urteil_timer_label.text = ""
	if echo_timer_label:
		echo_timer_label.text = ""
