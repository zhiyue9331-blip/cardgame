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
		var lethal := false
		match kind:
			"end_turn": value = 0
			"swap_equipment":
				value = 10 if _rules_card_value(player.sub) > _rules_card_value(player.main) else -1000
			"attack":
				var target_value := _rules_target_value(rules, slot, action, player.main)
				value = 24 + int(target_value.score)
				lethal = bool(target_value.lethal)
			"prepare":
				spent = rules.prepare_cost(slot)
				value = 14 if spent == 0 else 10
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
				if int(action.get("target_slot", slot)) != slot:
					var target_value := _rules_target_value(rules, slot, action, c)
					value += int(target_value.score)
					lethal = bool(target_value.lethal)
				if c.base_id in ["forge_temper", "forge_wedge", "forge_finale", "forge_reforge"] and player.attack_used: value -= 35
				if c.base_id == "blood_heal" and int(player.hp) == 12: value = -2
				if bool(action.get("options", {}).get("enhanced", false)):
					value += 5 if int(player.hp) > 4 or str(c.faction) == "归骸" else -20
		if has_counter and not player.counter_used and not player.main.is_empty() and spent > 0 and int(player.cost) - spent < 1 and int(player.hp) > 4:
			if not lethal: value -= 12
		var break_tie := false
		if value == score and action.get("type") == best.get("type") and action.get("card_id", "") == best.get("card_id", ""):
			var target := int(action.get("target_slot", slot))
			var previous := int(best.get("target_slot", slot))
			if target != slot and previous != slot:
				var pivot: int = (slot + int(rules.round_number)) % rules.players.size()
				break_tie = posmod(target - pivot, rules.players.size()) < posmod(previous - pivot, rules.players.size())
		if value > score or break_tie:
			score = value
			best = action.duplicate(true)
	return best


func _choose_rules_pending(rules: RefCounted, slot: int) -> Dictionary:
	var p: Dictionary = rules.pending
	if int(p.slot) != slot: return {}
	var cards: Array = p.cards.duplicate()
	var title := str(p.title)
	var discarding: bool = p.kind == "buffer" or "弃" in title or "清除" in title or title.begins_with("错位预言：可先将1张检视牌置底")
	var faction := str(rules.players[slot].main.get("faction", ""))
	var intercept_star_priority: bool = title.begins_with("截取未来：先选择1张牌") and rules.resonance(slot, "星序") > 0
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var va := _rules_card_value(a) + (6 if a.get("faction") == faction and not faction.is_empty() else 0)
		var vb := _rules_card_value(b) + (6 if b.get("faction") == faction and not faction.is_empty() else 0)
		return va < vb if discarding else va > vb)
	if intercept_star_priority:
		for card in cards:
			if str(card.get("faction", "")) == "星序":
				cards.erase(card)
				cards.push_front(card)
				break
	var choose_many: bool = p.kind in ["buffer", "order"] or title.begins_with("展示最多2张不同名星序牌") or title.begins_with("改写命轨：选牌入手")
	var count: int = int(p.max) if choose_many else mini(1, int(p.max))
	count = maxi(count, int(p.min))
	var options: Array = p.options
	var option := str(options[0].id) if not options.is_empty() else ""
	if "反击分支" in str(p.title) and options.size() == 2:
		if "归葬" in str(options[1].label) or int(rules.players[slot].hp) > 3:
			option = "enhanced"
	var ids: Array = cards.slice(0, count).map(func(c: Dictionary): return c.id)
	var action := {"type":"choose", "card_ids":ids, "option":option}
	if rules.validate_action(slot, action).is_empty(): return action
	# 星序多选先尝试合法的两牌组合，避免首两张同名时直接退成单选。
	var pairs_first: bool = title.begins_with("展示最多2张不同名星序牌") or title.begins_with("改写命轨：选牌入手")
	if pairs_first and int(p.max) >= 2:
		for first in cards:
			for second in cards:
				if first.id == second.id: continue
				action.card_ids = [first.id, second.id]
				if rules.validate_action(slot, action).is_empty(): return action
	for first in cards:
		if int(p.min) <= 1 and int(p.max) >= 1:
			action.card_ids = [first.id]
			if rules.validate_action(slot, action).is_empty(): return action
		if not pairs_first and int(p.max) >= 2:
			for second in cards:
				if first.id == second.id: continue
				action.card_ids = [first.id, second.id]
				if rules.validate_action(slot, action).is_empty(): return action
	return {}



# 只使用公开场面、目标手牌数量和自己的牌；不读取对手手牌内容或牌堆顺序。
func _rules_target_value(rules: RefCounted, slot: int, action: Dictionary, card: Dictionary) -> Dictionary:
	var target := int(action.target_slot)
	var enemy: Dictionary = rules.players[target]
	var faction := str(enemy.main.get("faction", ""))
	var resonance: int = rules.resonance(target, faction)
	var threat: int = int(enemy.hp) / 4 + enemy.hand.size() / 2
	threat += 2 * int(enemy.main.get("attack", 0)) + int(enemy.main.get("defense", 0)) + 3 * resonance
	var estimate := _rules_damage_estimate(rules, slot, action, card)
	var amount := int(estimate.amount)
	var bufferable := bool(estimate.bufferable)
	var exposed := maxi(0, amount - enemy.hand.size()) if bufferable else amount
	# 不偷看反击牌；对尚能反击的目标，斩杀按最多减伤3保守判断。
	var counter := 3 if int(enemy.cost) > 0 and not enemy.counter_used else 0
	var lethal := amount > 0 and maxi(0, exposed - counter) >= int(enemy.hp)
	var value: int = threat + 4 * amount + 5 * exposed
	if lethal: value += 80
	match str(card.get("base_id", "")):
		"neutral_disarm": value += 5 * resonance + 2 * int(enemy.main.get("attack", 0))
		"neutral_dismantle": value += 5 * resonance
		"hunt_blockade": value += 2 * maxi(0, 5 - enemy.hand.size())
	return {"score":value, "lethal":lethal}

# 一步伤害估计供选目标使用；未知检视结果不预支，真实结算仍由 CardRules 执行。
func _rules_damage_estimate(rules: RefCounted, slot: int, action: Dictionary, card: Dictionary) -> Dictionary:
	var player: Dictionary = rules.players[slot]
	var enemy: Dictionary = rules.players[int(action.target_slot)]
	var r: int = rules.resonance(slot, str(card.get("faction", "")))
	var enhanced := bool(action.get("options", {}).get("enhanced", false))
	var amount := 0
	var bufferable := true
	var resistance := int(enemy.res_once)
	if action.type == "attack":
		var atk := int(player.main.get("attack", 0))
		var defense := int(enemy.main.get("defense", 0))
		var ignore_res := 0
		for mod in player.attack_mods.values():
			atk += int(mod.get("atk", 0))
			if mod.has("target") and int(mod.target) != int(action.target_slot): continue
			if bool(mod.get("ignore_def", false)): defense = 0
			if mod.has("def_cap"): defense = mini(defense, int(mod.def_cap))
			ignore_res += int(mod.get("res_ignore", 0))
		if r > 0:
			match str(player.main.base_id):
				"forge_blade":
					if player.equipped_forge: atk += 2
				"blood_blade":
					if player.blood_paid: atk += 2
				"hunt_crossbow":
					if enemy.hand.size() <= player.hand.size(): atk += 2
		resistance = maxi(0, resistance - ignore_res)
		amount = maxi(1 if resistance == 0 else 0, atk - defense - resistance)
	else:
		match str(card.base_id):
			"forge_wedge", "hunt_probe": amount = 1
			"echo_aftershock", "star_fall": amount = 2
			"echo_finale":
				if r > 0: amount = 2 * mini(2, rules._filtered(player.buffer, "回响").size())
			"blood_pact": amount = (3 if r > 0 else 2) if enhanced else 1
			"blood_sever":
				amount = 3 if r == 2 and enhanced else 2
				bufferable = not enhanced
			"blood_finale", "grave_finale": amount = 5 if enhanced else 2
			"star_finale": amount = 3 if r == 2 else 0
			"grave_spike": amount = 3 if enhanced else 2
			"hunt_retreat":
				if enemy.hand.is_empty(): amount = 2 if r > 0 else 1
			"hunt_finale": amount = 4 if r > 0 and enemy.hand.size() <= player.hand.size() - 1 else 2
		amount = maxi(0, amount - resistance)
	# 跟随当前规则的来源计数；AI 不改变集火衰减规则。
	var sources: Array = enemy.damaged_by
	var source_index: int = sources.find(slot)
	var source_count: int = source_index + 1 if source_index >= 0 else sources.size() + 1
	if source_count >= 2 and amount > 0:
		amount = maxi(1, amount - mini(2, source_count - 1))
	return {"amount":amount, "bufferable":bufferable}

func _rules_card_value(card: Dictionary) -> int:
	if card.is_empty(): return 0
	var id := str(card.get("base_id", card.get("id", "")))
	if id.ends_with("_finale"): return 8
	if id.ends_with("_counter"): return 7
	if str(card.get("type", "")) == "装备牌": return int(card.get("attack", 0)) * 3 + int(card.get("defense", 0)) * 2
	if id in ["neutral_meditate", "star_gaze", "blood_search"]: return 5
	if id in ["neutral_aid", "echo_barrier", "blood_heal"]: return 4
	return 2
