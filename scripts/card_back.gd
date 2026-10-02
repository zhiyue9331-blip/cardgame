class_name CardBack
extends PanelContainer

## 统一的隐藏牌外观，不接收卡牌内容。
const TEXTURE := preload("res://assets/ui/astral-card-back.png")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func _draw() -> void:
	draw_texture_rect(TEXTURE, Rect2(Vector2.ZERO, size), false)
