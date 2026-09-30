extends DraggableCard


func _update_special_fields(_data: Dictionary) -> void:
	$EffectArt.visible = not artwork.visible
	if not artwork.visible:
		$EffectArt.position.y = 86
		$EffectArt.size.y = 30
