class_name AiController
extends RefCounted

## 只读取 CardRules 并选择合法行动；AiTurnRunner 控制节奏，GameSession 提交结算。

func choose_rules_action(rules: RefCounted, slot: int) -> Dictionary:
	var pending: Dictionary = rules.pending
	if not pending.is_empty(): return _choose_rules_pending(rules, slot)
	var actions: Array = rules.legal_actions(slot)
	var player: Dictionary = rules.players[slot]
	var has_counter: bool = player.hand.any(func(c: Dictionary): return c.get("subtype") == "counter")
	var best: Dictionary = {}
	var score := -100000
	for action in actions:
		var kind := str(action.type)
		var value := 0
		var spent := 0
		match kind:
			"end_turn": value = 0
			"swap_equipment":
				value = 10 if _rules_card_value(player.sub) > _rules_card_value(player.main) else -1000
			"attack": value = 24 + (12 - int(rules.players[int(action.target_slot)].hp))
			"prepare":
				value = 10
				spent = 1
			"draw_two":
				value = 13 if player.hand.size() < 5 else 9
				spent = 1
			"equip":
				var c: Dictionary = rules.find(player.hand, str(action.card_id))
				var field := str(action.equipment_slot)
				var old: Dictionary = player[field]
				value = 18 + _rules_card_value(c) - _rules_card_value(old)
				if not old.is_empty(): value -= 16
				if field == "sub":
					value -= 9
					if not str(c.faction).is_empty() and c.faction == player.main.get("faction") and c.name != player.main.get("name"): value += 20
				spent = rules.equip_cost(slot, c)
			"effect":
				var c: Dictionary = rules.find(player.hand, str(action.card_id))
				value = 17 + _rules_card_value(c) + 5 * rules.resonance(slot, str(c.faction))
				spent = int(c.cost)
				if c.base_id in ["forge_temper", "forge_wedge", "forge_finale", "forge_reforge"] and player.attack_used: value -= 35
				if c.base_id == "blood_heal" and int(player.hp) == 12: value = -2
				if bool(action.get("options", {}).get("enhanced", false)):
					value += 5 if int(player.hp) > 4 or str(c.faction) == "归骸" else -20
		if has_counter and not player.counter_used and not player.main.is_empty() and spent > 0 and int(player.cost) - spent < 1 and int(player.hp) > 4:
			value -= 50
		if value > score:
			score = value
			best = action.duplicate(true)
	return best


func _choose_rules_pending(rules: RefCounted, slot: int) -> Dictionary:
	var p: Dictionary = rules.pending
	if int(p.slot) != slot: return {}
	var cards: Array = p.cards.duplicate()
	var discarding: bool = p.kind == "buffer" or "弃" in str(p.title) or "清除" in str(p.title)
	var faction := str(rules.players[slot].main.get("faction", ""))
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var va := _rules_card_value(a) + (6 if a.get("faction") == faction and not faction.is_empty() else 0)
		var vb := _rules_card_value(b) + (6 if b.get("faction") == faction and not faction.is_empty() else 0)
		return va < vb if discarding else va > vb)
	var count := int(p.max) if p.kind in ["buffer", "order"] else mini(1, int(p.max))
	count = maxi(count, int(p.min))
	var options: Array = p.options
	var option := str(options[0].id) if not options.is_empty() else ""
	var ids: Array = cards.slice(0, count).map(func(c: Dictionary): return c.id)
	var action := {"type":"choose", "card_ids":ids, "option":option}
	if rules.validate_action(slot, action).is_empty(): return action
	# Only one- and two-card choices have composition constraints (resonance or burial).
	for first in cards:
		if int(p.min) <= 1 and int(p.max) >= 1:
			action.card_ids = [first.id]
			if rules.validate_action(slot, action).is_empty(): return action
		if int(p.max) >= 2:
			for second in cards:
				if first.id == second.id: continue
				action.card_ids = [first.id, second.id]
				if rules.validate_action(slot, action).is_empty(): return action
	return {}


func _rules_card_value(card: Dictionary) -> int:
	if card.is_empty(): return 0
	var id := str(card.get("base_id", card.get("id", "")))
	if id.ends_with("_finale"): return 8
	if id.ends_with("_counter"): return 7
	if str(card.get("type", "")) == "装备牌": return int(card.get("attack", 0)) * 3 + int(card.get("defense", 0)) * 2
	if id in ["neutral_meditate", "star_gaze", "blood_search"]: return 5
	if id in ["neutral_aid", "echo_barrier", "blood_heal"]: return 4
	return 2
