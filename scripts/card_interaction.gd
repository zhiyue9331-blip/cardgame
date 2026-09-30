extends RefCounted

## Pure drag/drop hit testing and intent classification for cards.
## The host performs all mutations and rule submission after inspecting the result.

var prepare_zone: DropZone
var main_zone: DropZone
var sub_zone: DropZone
var self_head: Control
var opponents: Array = []


func setup(prepare_zone_value: DropZone, main_zone_value: DropZone, sub_zone_value: DropZone, self_head_value: Control) -> void:
	prepare_zone = prepare_zone_value
	main_zone = main_zone_value
	sub_zone = sub_zone_value
	self_head = self_head_value


func set_opponents(panels: Array) -> void:
	opponents = panels


func classify_hand_drop(card: DraggableCard, position: Vector2, current_cost: int, target_type: String = "", required_cost: int = -1) -> Dictionary:
	var data := card.card_data
	if not card.has_dragged:
		return {"kind": "return"}
	if prepare_zone.visible and prepare_zone.contains_global_point(position):
		return {"kind": "prepare"}
	var needed_cost := required_cost if required_cost >= 0 else int(data.get("cost", 0))
	if current_cost < needed_cost:
		return {"kind": "reject", "reason": "费用不足。", "show_cost_message": true}
	if data.get("type") == "装备牌":
		if main_zone.contains_global_point(position):
			return {"kind": "equip", "is_main": true}
		if sub_zone.contains_global_point(position):
			return {"kind": "equip", "is_main": false}
	if data.get("type") == "效果牌":
		if is_self_effect(data, target_type):
			if self_head.get_global_rect().has_point(position):
				return {"kind": "effect", "target_id": 0, "destination": self_head.get_global_rect().get_center(), "panel": null}
			return {"kind": "reject", "reason": "请把效果牌拖到自己的头像上。", "show_cost_message": false}
		var target_panel := panel_at(position)
		if target_panel != null:
			return {"kind": "effect", "target_id": int(target_panel.target_id), "destination": target_panel.head_center(), "panel": target_panel}
		return {"kind": "reject", "reason": "请把效果牌拖到目标玩家的头像上。", "show_cost_message": false}
	return {"kind": "reject", "reason": "没有放到可用区域。", "show_cost_message": false}


func classify_equipment_drop(card: DraggableCard, position: Vector2) -> Dictionary:
	var source := String(card.get_meta("equipment_slot", ""))
	if main_zone.contains_global_point(position):
		return {"kind": "move", "source": source, "target": "main"}
	if sub_zone.contains_global_point(position):
		return {"kind": "move", "source": source, "target": "sub"}
	var target_panel := panel_at(position)
	if target_panel == null:
		target_panel = panel_at(card.get_global_rect().get_center())
	if target_panel != null:
		return {"kind": "target", "source": source, "panel": target_panel, "dragged": card.has_dragged}
	if card.has_dragged:
		return {"kind": "reject", "source": source, "reason": "请将装备拖到装备槽或对手区域。"}
	return {"kind": "return", "source": source, "dragged": false}


func panel_at(point: Vector2) -> Node:
	for panel in opponents:
		if panel.get_global_rect().has_point(point):
			return panel
	return null


func is_self_effect(data: Dictionary, target_type: String = "") -> bool:
	return (target_type if not target_type.is_empty() else str(data.get("effect_target", "self"))) == "self"
