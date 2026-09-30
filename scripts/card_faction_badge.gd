class_name CardFactionBadge
extends PanelContainer

@onready var badge_label: Label = $BadgeLabel


func setup(faction: String) -> void:
	if not is_node_ready():
		await ready
	badge_label.text = faction if not faction.is_empty() else "中立"
	var color := Color("#50606b")
	match faction:
		"铸锋": color = Color("#9b531e")
		"回响": color = Color("#17657b")
		"血契": color = Color("#913e4d")
		"星序": color = Color("#62508e")
		"归骸": color = Color("#4b6670")
		"围猎": color = Color("#4b713e")
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	add_theme_stylebox_override("panel", style)
