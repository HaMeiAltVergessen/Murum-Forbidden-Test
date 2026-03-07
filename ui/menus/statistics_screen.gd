extends PanelContainer
## Statistics Screen - Displays all tracked gameplay statistics

# ============================================================================
# SIGNALS
# ============================================================================

signal back_pressed()

# ============================================================================
# REFERENCES
# ============================================================================

@onready var deaths_label: Label = %DeathsLabel
@onready var playtime_label: Label = %PlaytimeLabel
@onready var kills_label: Label = %KillsLabel
@onready var parries_label: Label = %ParriesLabel
@onready var damage_dealt_label: Label = %DamageDealtLabel
@onready var damage_taken_label: Label = %DamageTakenLabel
@onready var max_combo_label: Label = %MaxComboLabel
@onready var bosses_label: Label = %BossesLabel
@onready var urgathon_label: Label = %UrgathonLabel
@onready var resonance_label: Label = %ResonanceLabel
@onready var secrets_label: Label = %SecretsLabel
@onready var relics_label: Label = %RelicsLabel
@onready var rooms_label: Label = %RoomsLabel
@onready var coins_label: Label = %CoinsLabel
@onready var back_button: Button = %StatisticsBackButton

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	update_statistics()
	print("[StatisticsScreen] Initialized")

# ============================================================================
# PUBLIC API
# ============================================================================

func update_statistics() -> void:
	"""Updates all stat labels from StatisticsManager"""
	if not StatisticsManager:
		return

	var stats = StatisticsManager.get_all_statistics()

	deaths_label.text = str(stats.get("total_deaths", 0))
	playtime_label.text = StatisticsManager.get_formatted_playtime()
	kills_label.text = str(stats.get("enemies_killed", 0))
	parries_label.text = str(stats.get("perfect_parries", 0))
	damage_dealt_label.text = _format_number(stats.get("total_damage_dealt", 0))
	damage_taken_label.text = _format_number(stats.get("total_damage_taken", 0))
	max_combo_label.text = str(stats.get("max_combo", 0))
	bosses_label.text = str(stats.get("bosses_defeated_count", 0))
	urgathon_label.text = str(stats.get("urgathon_uses", 0))
	resonance_label.text = str(stats.get("resonance_modes_activated", 0))
	secrets_label.text = str(stats.get("secrets_found_count", 0))
	relics_label.text = str(stats.get("relics_collected", 0))
	rooms_label.text = str(stats.get("rooms_visited", 0))
	coins_label.text = _format_number(stats.get("coins_total_earned", 0))

# ============================================================================
# UTILITY
# ============================================================================

func _format_number(value: int) -> String:
	"""Formats large numbers with K/M suffix"""
	if value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	elif value >= 1000:
		return "%.1fK" % (value / 1000.0)
	return str(value)

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_back_pressed() -> void:
	back_pressed.emit()
