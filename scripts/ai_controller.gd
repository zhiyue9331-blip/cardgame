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
	var best_attack_score := -100000
	var immediate_lethal := false
	for candidate in actions:
		var candidate_type := str(candidate.type)
		if candidate_type == "attack":
			var candidate_target := _rules_target_value(rules, slot, candidate, player.main)
			best_attack_score = maxi(best_attack_score, 24 + int(candidate_target.score))
			immediate_lethal = immediate_lethal or bool(candidate_target.lethal)
		elif candidate_type == "effect" and int(candidate.get("target_slot", slot)) != slot:
			var candidate_card: Dictionary = rules.find(player.hand, str(candidate.get("card_id", "")))
			if not candidate_card.is_empty():
				var effect_target_value := _rules_target_value(rules, slot, candidate, candidate_card)
				immediate_lethal = immediate_lethal or bool(effect_target_value.lethal)
	for action in actions:
		var kind := str(action.type)
		var value := 0
		var spent := 0
		var lethal := false
		var forge_temper_gain := 0
		match kind:
			"end_turn": value = 0
			"plan":
				var plan_card: Dictionary = rules.find(player.hand, str(action.card_id))
				value = _plan_action_score(rules, slot, plan_card, actions, immediate_lethal)
				spent = int(plan_card.get("cost", 0))
			"cancel_plan": value = -80
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
				if field == "main":
					# A player without a main equipment cannot attack or resonate. Give
					# the first main slot a clear tempo priority over ordinary effects.
					if old.is_empty(): value += 35
				else:
					value -= 9
					if not str(c.faction).is_empty() and c.faction == player.main.get("faction") and c.name != player.main.get("name"): value += 20
				spent = rules.equip_cost(slot, c)
			"effect":
				var c: Dictionary = rules.find(player.hand, str(action.card_id))
				var card_resonance: int = int(rules.resonance(slot, str(c.faction)))
				value = 17 + _rules_card_value(c) + 5 * card_resonance
				spent = int(c.cost)
				if int(action.get("target_slot", slot)) != slot:
					var target_value := _rules_target_value(rules, slot, action, c)
					value += int(target_value.score)
					lethal = bool(target_value.lethal)
				if c.base_id == "forge_temper":
					forge_temper_gain = _forge_temper_attack_gain(rules, slot, actions)
					if forge_temper_gain > 0 and best_attack_score > -100000:
						# A real damage increase makes buff-then-attack strictly better
						# than spending the free attack immediately.
						value = maxi(value, best_attack_score + forge_temper_gain + 1)
				if c.base_id == "forge_reforge" and not _has_reforge_followup(rules, slot): value = -100
				if c.base_id == "star_finale" and card_resonance == 0:
					# Searching one card for 3 fee without resonance should not beat
					# the normal 1-fee draw-two action on raw card-value scoring.
					var draw_two_value: int = 13 if player.hand.size() < 5 else 9
					var draw_two_available: bool = actions.any(func(candidate: Dictionary): return str(candidate.type) == "draw_two")
					value = mini(value, draw_two_value - 1 if draw_two_available else draw_two_value)
				if c.base_id in ["forge_temper", "forge_wedge", "forge_finale", "forge_reforge", "scheme_blade"] and player.attack_used: value -= 35
				if c.base_id == "blood_heal" and int(player.hp) == 12: value = -2
				if bool(action.get("options", {}).get("enhanced", false)):
					value += 5 if int(player.hp) > 4 or str(c.faction) == "归骸" else -20
		if has_counter and not player.counter_used and not player.main.is_empty() and spent > 0 and int(player.cost) - spent < 1 and int(player.hp) > 4:
			if not lethal: value -= 12
		if forge_temper_gain > 0 and best_attack_score > -100000:
			value = maxi(value, best_attack_score + forge_temper_gain + 1)
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


# Uses the same public damage estimator as target selection. The temporary
# modifier is passed as a copy and never changes game state.
func _forge_temper_attack_gain(rules: RefCounted, slot: int, actions: Array) -> int:
	var player: Dictionary = rules.players[slot]
	if player.attack_used or player.main.is_empty(): return 0
	var attack_actions: Array = actions.filter(func(action: Dictionary): return str(action.type) == "attack")
	if attack_actions.is_empty(): return 0
	var original_mods: Dictionary = player.attack_mods
	var after_mods: Dictionary = original_mods.duplicate(true)
	var r: int = int(rules.resonance(slot, "铸锋"))
	var temper_mod := {"atk":2 if r > 0 else 1, "def_cap":1 if r > 0 else 999}
	var existing: Dictionary = after_mods.get("forge_temper", {})
	if int(temper_mod.atk) >= int(existing.get("atk", 0)): after_mods["forge_temper"] = temper_mod
	var gain := 0
	for attack in attack_actions:
		var before := _rules_damage_estimate(rules, slot, attack, player.main)
		var after := _rules_damage_estimate(rules, slot, attack, player.main, after_mods, true)
		gain = maxi(gain, int(after.amount) - int(before.amount))
	return gain


func _has_reforge_followup(rules: RefCounted, slot: int) -> bool:
	var player: Dictionary = rules.players[slot]
	var remaining_cost := int(player.cost) - 2
	if remaining_cost < 0: return false
	var resonance_level: int = int(rules.resonance(slot, "铸锋"))
	var reforge_discount := 2 if resonance_level > 0 else 1
	var effective_discount := maxi(int(player.discount), reforge_discount)
	for card in player.hand:
		if str(card.get("type", "")) != "装备牌" or str(card.get("faction", "")) != "铸锋": continue
		var followup_cost := maxi(0, int(card.cost) - effective_discount)
		if followup_cost <= remaining_cost: return true
	return false


func _plan_action_score(rules: RefCounted, slot: int, card: Dictionary, _actions: Array, immediate_lethal: bool) -> int:
	if card.is_empty() or not bool(card.get("planable", false)): return -100000
	var player: Dictionary = rules.players[slot]
	if str(player.main.get("faction", "")) != "伏谋": return -100000
	var r := int(rules.resonance(slot, "伏谋"))
	var id := str(card.get("base_id", ""))
	var value := 18 + _rules_card_value(card) + 4 * r
	match id:
		"scheme_supply": value = 23 + 4 * r
		"scheme_insight": value = 21 + 5 * r
		"scheme_detonate": value = 17 + _best_plan_target_score(rules, slot, card, 0)
		"scheme_finale": value = 24 + _best_plan_target_score(rules, slot, card, 0) + (5 if r == 2 else 0)
		"scheme_blade":
			var gain := _scheme_blade_attack_gain(rules, slot)
			value = 17 + 5 * r + gain * 5
			if gain <= 0: value -= 18
	if immediate_lethal: value -= 80
	# A plan is public and cannot buffer this turn; preserve survival and hand
	# capacity rather than treating delayed damage as free value.
	if int(player.hp) <= 4: value -= 24
	elif int(player.hp) <= 6: value -= 10
	if player.hand.size() <= 1: value -= 10
	return value


func _best_plan_target_score(rules: RefCounted, slot: int, card: Dictionary, plan_bonus: int) -> int:
	var best := -100000
	for target in range(rules.players.size()):
		if target == slot or not rules.alive(target): continue
		var action := {"type":"effect", "target_slot":target}
		var target_value := _rules_target_value(rules, slot, action, card, plan_bonus, true)
		best = maxi(best, int(target_value.score))
	return 0 if best == -100000 else best


func _scheme_blade_attack_gain(rules: RefCounted, slot: int) -> int:
	var player: Dictionary = rules.players[slot]
	if player.main.is_empty(): return 0
	var mods: Dictionary = player.attack_mods.duplicate(true)
	var r := int(rules.resonance(slot, "伏谋"))
	var blade_mod := {"atk":3 if r > 0 else 1, "def_cap":1 if r > 0 else 999}
	var existing: Dictionary = mods.get("scheme_blade", {})
	if int(blade_mod.atk) >= int(existing.get("atk", 0)): mods["scheme_blade"] = blade_mod
	var gain := 0
	for target in range(rules.players.size()):
		if target == slot or not rules.alive(target): continue
		var action := {"type":"attack", "target_slot":target}
		var before := _rules_damage_estimate(rules, slot, action, player.main)
		var after := _rules_damage_estimate(rules, slot, action, player.main, mods, true)
		gain = maxi(gain, int(after.amount) - int(before.amount))
	return gain


func _choose_rules_pending(rules: RefCounted, slot: int) -> Dictionary:
	var p: Dictionary = rules.pending
	if int(p.slot) != slot: return {}
	if str(p.get("kind", "")) == "plan_target": return _choose_plan_target(rules, slot, p)
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
		option = _choose_counter_option(rules, slot, p)
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


func _choose_plan_target(rules: RefCounted, slot: int, p: Dictionary) -> Dictionary:
	var card: Dictionary = p.get("plan_card", rules.players[slot].get("plan", {}))
	var bonus := int(p.get("plan_damage_bonus", 0))
	var best_option := ""
	var best_score := -100000
	for entry in p.get("options", []):
		var target := int(entry.get("id", -1))
		if target == slot or not rules.alive(target): continue
		var action := {"type":"effect", "target_slot":target}
		var target_value := _rules_target_value(rules, slot, action, card, bonus, true)
		var value := int(target_value.score)
		if value > best_score:
			best_score = value
			best_option = str(entry.get("id", ""))
	if best_option.is_empty() and not p.get("options", []).is_empty():
		best_option = str(p.options[0].get("id", ""))
	if best_option.is_empty(): return {}
	return {"type":"choose", "card_ids":[], "option":best_option}


func _choose_counter_option(rules: RefCounted, slot: int, p: Dictionary) -> String:
	var options: Array = p.get("options", [])
	var enhanced := ""
	var base := ""
	var scheme_branch := false
	for entry in options:
		var id := str(entry.get("id", ""))
		var label := str(entry.get("label", ""))
		if id == "enhanced" or "取回计划" in label: enhanced = id
		elif id == "base" or base.is_empty(): base = id
		if "取回计划" in label: scheme_branch = true
	if enhanced.is_empty(): return base
	var player: Dictionary = rules.players[slot]
	if not scheme_branch:
		return enhanced if "归葬" in str(options[1].get("label", "")) or int(player.hp) > 3 else base
	if player.plan.is_empty(): return base
	# Newer pending records may expose the incoming amount. Older records omit
	# it, so HP and plan value provide the conservative fallback.
	var incoming := int(p.get("damage", p.get("amount", 0)))
	if incoming > 0 and incoming <= 1: return base
	if incoming >= 3 or int(player.hp) <= 4: return enhanced
	var plan_score := _plan_action_score(rules, slot, player.plan, [], false)
	return enhanced if plan_score < 16 else base



# 只使用公开场面、目标手牌数量和自己的牌；不读取对手手牌内容或牌堆顺序。
func _rules_target_value(rules: RefCounted, slot: int, action: Dictionary, card: Dictionary, plan_bonus: int = 0, planned: bool = false) -> Dictionary:
	var target := int(action.target_slot)
	var enemy: Dictionary = rules.players[target]
	var faction := str(enemy.main.get("faction", ""))
	var target_resonance: int = rules.resonance(target, faction)
	var actor_resonance: int = rules.resonance(slot, str(card.get("faction", "")))
	var threat: int = int(enemy.hp) / 4 + enemy.hand.size() / 2
	threat += 2 * int(enemy.main.get("attack", 0)) + int(enemy.main.get("defense", 0)) + 3 * target_resonance
	var estimate := _rules_damage_estimate(rules, slot, action, card, {}, false, plan_bonus, planned)
	var amount := int(estimate.amount)
	var bufferable := bool(estimate.bufferable)
	var exposed := maxi(0, amount - enemy.hand.size()) if bufferable else amount
	# 不偷看反击牌；对尚能反击的目标，斩杀按最多减伤3保守判断。
	var counter := 3 if int(enemy.cost) > 0 and not enemy.counter_used else 0
	var lethal := amount > 0 and maxi(0, exposed - counter) >= int(enemy.hp)
	var value: int = threat + 4 * amount + 5 * exposed
	if lethal: value += 80
	match str(card.get("base_id", "")):
		"neutral_disarm": value += 5 * target_resonance + 2 * int(enemy.main.get("attack", 0))
		"neutral_dismantle": value += 5 * target_resonance
		"hunt_retreat":
			# The card still forces a choice when the target has cards. The
			# damage-only estimate above otherwise rates this as zero damage.
			if not enemy.hand.is_empty(): value += 5 + 2 * actor_resonance
		"hunt_cutoff":
			# Moving a public card out of the discard pile is useful on its own;
			# resonance also forces a discard when the chosen card matches the
			# target's faction (the exact card is selected later).
			value += 3 + 4 * actor_resonance
		"hunt_blockade":
			# Blockade is strongest against a target with more cards than us;
			# the previous low-hand bonus pointed the AI in the opposite direction.
			value += 3
			if actor_resonance > 0 and enemy.hand.size() > rules.players[slot].hand.size() - 1: value += 7
	return {"score":value, "lethal":lethal}

# 一步伤害估计供选目标使用；未知检视结果不预支，真实结算仍由 CardRules 执行。
func _rules_damage_estimate(rules: RefCounted, slot: int, action: Dictionary, card: Dictionary, attack_mods_override: Dictionary = {}, use_attack_mods_override: bool = false, plan_bonus: int = 0, planned: bool = false) -> Dictionary:
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
		var attack_mods: Dictionary = attack_mods_override if use_attack_mods_override else player.attack_mods
		for mod in attack_mods.values():
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
		# 保底伤害仅适用于含加成后 ATK > 0、有效 RES 为 0 的攻击。
		amount = 0 if atk <= 0 else maxi(1 if resistance == 0 else 0, atk - defense - resistance)
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
			"scheme_detonate": amount = 4 if planned and r > 0 else (3 if r > 0 else 2)
			"scheme_finale": amount = 4 if planned and r > 0 else (3 if r > 0 else 2)
		if planned and str(card.base_id) in ["scheme_detonate", "scheme_finale"]:
			amount = mini(5, amount + plan_bonus)
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
