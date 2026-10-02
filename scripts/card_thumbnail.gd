class_name CardThumbnail
extends PanelContainer

@onready var name_label: Label = %CardName
@onready var type_label: Label = %CardType
@onready var cost_label: Label = %CardCost
@onready var detail_label: Label = %CardDetail
@onready var artwork: TextureRect = %Artwork
@onready var faction_badge: CardFactionBadge = %FactionBadge
@onready var divider: HSeparator = $Margin/Content/Divider


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup(data: Dictionary) -> void:
	if not is_node_ready():
		await ready
	name_label.text = str(data.get("name", "卡牌"))
	var faction := str(data.get("faction", ""))
	faction_badge.setup(faction)
	type_label.text = "反击" if data.get("subtype") == "counter" else str(data.get("type", ""))
	if data.get("type") == "装备牌":
		type_label.text += "\nATK %d  DEF %d" % [int(data.get("attack", 0)), int(data.get("defense", 0))]
	cost_label.text = str(data.get("cost", 0))
	detail_label.text = str(data.get("description", ""))
	var art_path := "res://cards/art/%s.png" % str(data.get("base_id", data.get("id", "")))
	artwork.texture = load(art_path) if ResourceLoader.exists(art_path) else null
	artwork.visible = artwork.texture != null
	divider.visible = not artwork.visible
	detail_label.visible = not artwork.visible
	tooltip_text = "%s · %s · %s · %s费\n%s" % [name_label.text, faction_badge.badge_label.text, type_label.text, cost_label.text, detail_label.text]
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#100e0c")
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 6
	add_theme_stylebox_override("panel", style)
