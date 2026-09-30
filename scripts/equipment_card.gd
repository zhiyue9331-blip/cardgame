extends DraggableCard

@onready var stats_label: Label = %StatsLabel
@onready var stats_panel: Panel = $StatsPanel
@onready var attack_icon: TextureRect = $StatsPanel/AttackIcon
@onready var defense_icon: TextureRect = $StatsPanel/DefenseIcon
@onready var attack_value: Label = $StatsPanel/AttackValue
@onready var defense_value: Label = $StatsPanel/DefenseValue


func _update_special_fields(data: Dictionary) -> void:
	if artwork.visible:
		attack_icon.texture = preload("res://cards/art/sword_icon.svg")
		defense_icon.texture = preload("res://cards/art/shield_icon.svg")
		stats_panel.position.y = 150
		stats_label.visible = false
		attack_icon.visible = true
		defense_icon.visible = true
		attack_value.visible = true
		defense_value.visible = true
		attack_value.text = str(data.get("attack", 0))
		defense_value.text = str(data.get("defense", 0))
	else:
		stats_panel.position.y = 87
		stats_label.visible = true
		stats_label.text = "ATK %d    DEF %d" % [int(data.get("attack", 0)), int(data.get("defense", 0))]
