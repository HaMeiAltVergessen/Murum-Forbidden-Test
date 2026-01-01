extends CanvasLayer
## Gold Display - Shows shared gold count for P1 and P2
## Positioned top-center

@onready var p1_gold_label: Label = $MarginContainer/HBoxContainer/P1GoldLabel if has_node("MarginContainer/HBoxContainer/P1GoldLabel") else null
@onready var p2_gold_label: Label = $MarginContainer/HBoxContainer/P2GoldLabel if has_node("MarginContainer/HBoxContainer/P2GoldLabel") else null
@onready var separator: Label = $MarginContainer/HBoxContainer/Separator if has_node("MarginContainer/HBoxContainer/Separator") else null

func _ready() -> void:
	# Initially show only P1 gold
	if p2_gold_label:
		p2_gold_label.visible = false
	if separator:
		separator.visible = false

	# Update initial display
	update_gold_display()

	# Connect signals
	if GameManager and GameManager.has_signal("gold_changed"):
		GameManager.gold_changed.connect(_on_gold_changed)

	if CoopManager:
		CoopManager.p2_joined.connect(_on_p2_joined)
		CoopManager.p2_left.connect(_on_p2_left)

	print("[Gold Display] Initialized")

func _on_gold_changed(_new_gold: int) -> void:
	"""Handle gold changes"""
	update_gold_display()

func update_gold_display() -> void:
	"""Update gold labels"""
	if not GameManager:
		return

	# P1 Gold
	var p1_gold = GameManager.player_gold if "player_gold" in GameManager else 0
	if p1_gold_label:
		p1_gold_label.text = "Murum: %d 💰" % p1_gold

	# P2 Gold (if active)
	if CoopManager and CoopManager.is_p2_active:
		var p2_gold = GameManager.p2_gold if "p2_gold" in GameManager else 0
		if p2_gold_label:
			p2_gold_label.text = "Lythrun: %d 💰" % p2_gold

func _on_p2_joined() -> void:
	"""Handle P2 joining - show P2 gold"""
	if p2_gold_label:
		p2_gold_label.visible = true
	if separator:
		separator.visible = true

	update_gold_display()

func _on_p2_left() -> void:
	"""Handle P2 leaving - hide P2 gold"""
	if p2_gold_label:
		p2_gold_label.visible = false
	if separator:
		separator.visible = false
