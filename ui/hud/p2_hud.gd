extends CanvasLayer
## P2 HUD - Displays Lythrun's health, mana, and buffs
## Positioned top-right with shadow/violet theme

@onready var player_name_label: Label = $MarginContainer/VBoxContainer/PlayerNameLabel if has_node("MarginContainer/VBoxContainer/PlayerNameLabel") else null
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar/HPProgressBar if has_node("MarginContainer/VBoxContainer/HPBar/HPProgressBar") else null
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HPBar/HPLabel if has_node("MarginContainer/VBoxContainer/HPBar/HPLabel") else null
@onready var mana_bar: ProgressBar = $MarginContainer/VBoxContainer/ManaBar/ManaProgressBar if has_node("MarginContainer/VBoxContainer/ManaBar/ManaProgressBar") else null
@onready var mana_label: Label = $MarginContainer/VBoxContainer/ManaBar/ManaLabel if has_node("MarginContainer/VBoxContainer/ManaBar/ManaLabel") else null

# ============ PLAYER REFERENCE ============
var player: CharacterBody2D = null

# ============ LOW HP TWEEN ============
var low_hp_tween: Tween = null

func _ready() -> void:
	# Set player name
	if player_name_label:
		player_name_label.text = "Lythrun"
		player_name_label.modulate = Color(0.7, 0.5, 0.9)  # Violet tone

	# Initially hidden until P2 joins
	visible = false

	# Connect to CoopManager signals
	if CoopManager:
		CoopManager.p2_joined.connect(_on_p2_joined)
		CoopManager.p2_left.connect(_on_p2_left)

	print("[P2 HUD] Initialized")

func set_player(p: CharacterBody2D) -> void:
	"""Set player reference and connect signals"""
	player = p

	if not player:
		return

	# Connect to HealthComponent (check if not already connected)
	if player.has_node("HealthComponent"):
		var health_comp = player.get_node("HealthComponent")
		if health_comp.has_signal("health_changed") and not health_comp.health_changed.is_connected(_on_health_changed):
			health_comp.health_changed.connect(_on_health_changed)
		if health_comp.has_signal("damage_taken") and not health_comp.damage_taken.is_connected(_on_damage_taken):
			health_comp.damage_taken.connect(_on_damage_taken)

	# Connect to ManaComponent (check if not already connected)
	if player.has_node("ManaComponent"):
		var mana_comp = player.get_node("ManaComponent")
		if mana_comp.has_signal("mana_changed") and not mana_comp.mana_changed.is_connected(_on_mana_changed):
			mana_comp.mana_changed.connect(_on_mana_changed)

	# Initial update
	update_health_bar()
	update_mana_bar()

	print("[P2 HUD] Player reference set")

# ============ COOP SIGNALS ============

func _on_p2_joined() -> void:
	"""Handle P2 joining"""
	visible = true

	# Note: HUDManager will call set_player() via set_p2_reference()
	# So we don't need to call it here to avoid duplicate signal connections

func _on_p2_left() -> void:
	"""Handle P2 leaving"""
	visible = false
	player = null

# ============ SIGNAL HANDLERS ============

func _on_health_changed(new_health: int, max_health: int) -> void:
	"""Handle health changes"""
	update_health_bar()

func _on_mana_changed(new_mana: int, max_mana: int) -> void:
	"""Handle mana changes"""
	update_mana_bar()

func _on_damage_taken(damage: int) -> void:
	"""Handle damage taken (flash effect)"""
	if hp_bar:
		flash_hp_bar()

# ============ UPDATE FUNCTIONS ============

func update_health_bar() -> void:
	"""Update HP bar value and color (shadow theme)"""
	if not player or not hp_bar:
		return

	var health_comp = player.get_node("HealthComponent") if player.has_node("HealthComponent") else null
	if not health_comp:
		return

	var current_hp = health_comp.current_health if "current_health" in health_comp else 100
	var max_hp = health_comp.max_health if "max_health" in health_comp else 100

	# Update bar
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp

	# Update label
	if hp_label:
		hp_label.text = "%d / %d" % [int(current_hp), int(max_hp)]

	# Color coding based on HP percentage (shadow theme colors)
	var hp_percent = current_hp / max_hp if max_hp > 0 else 0

	if hp_percent > 0.6:
		set_hp_bar_color(Color(0.5, 0, 0.8))  # Violet (good)
		stop_low_hp_pulse()
	elif hp_percent > 0.3:
		set_hp_bar_color(Color(0.8, 0.2, 0.8))  # Pink (medium)
		stop_low_hp_pulse()
	else:
		set_hp_bar_color(Color(1.0, 0, 0.5))  # Red-Violet (low)
		pulse_low_hp()

func set_hp_bar_color(color: Color) -> void:
	"""Set HP bar color"""
	if hp_bar:
		hp_bar.modulate = color

func pulse_low_hp() -> void:
	"""Pulse HP bar when low"""
	if not hp_bar or low_hp_tween:
		return

	low_hp_tween = create_tween()
	low_hp_tween.set_loops()
	low_hp_tween.tween_property(hp_bar, "modulate:a", 0.5, 0.5)
	low_hp_tween.tween_property(hp_bar, "modulate:a", 1.0, 0.5)

func stop_low_hp_pulse() -> void:
	"""Stop pulsing HP bar"""
	if low_hp_tween:
		low_hp_tween.kill()
		low_hp_tween = null

	if hp_bar:
		hp_bar.modulate.a = 1.0

func flash_hp_bar() -> void:
	"""Flash HP bar on damage"""
	if not hp_bar:
		return

	var original_color = hp_bar.modulate

	# Flash violet-white
	hp_bar.modulate = Color(2, 1.5, 2.5, 1)

	# Tween back
	var tween = create_tween()
	tween.tween_property(hp_bar, "modulate", original_color, 0.1)

func update_mana_bar() -> void:
	"""Update mana bar value"""
	if not player or not mana_bar:
		return

	var mana_comp = player.get_node("ManaComponent") if player.has_node("ManaComponent") else null
	if not mana_comp:
		return

	var current_mana = mana_comp.current_mana if "current_mana" in mana_comp else 100
	var max_mana = mana_comp.max_mana if "max_mana" in mana_comp else 100

	# Update bar
	mana_bar.max_value = max_mana
	mana_bar.value = current_mana

	# Update label
	if mana_label:
		mana_label.text = "%d / %d" % [int(current_mana), int(max_mana)]
