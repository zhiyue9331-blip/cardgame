class_name CardRules
extends RefCounted

const MAX_HP := 12
const MAX_HAND := 8
const COUNTERS := ["forge_counter", "echo_counter", "blood_counter", "star_counter", "grave_counter", "hunt_counter"]
var players: Array[Dictionary] = []
var deck: Array[Dictionary] = []
var discard: Array[Dictionary] = []
var resolving: Array[Dictionary] = []
var inspected: Array[Dictionary] = []
var current := 0
var winner := -1
var round_number := 1
var logs: Array[String] = []
var visual_events: Array[Dictionary] = []
var pending: Dictionary = {}
var enabled_factions: Array[String] = []
var _queue: Array[Callable] = []
var _choice_callback := Callable()
var _choice_validator := Callable()
var _rng := RandomNumberGenerator.new()
var _draining := false

func dispose() -> void:
	_queue.clear()
	_choice_callback = Callable()
	_choice_validator = Callable()
	pending.clear()

func start(count: int, seed_value: int) -> void:
	dispose()
	players.clear()
	deck = CardDatabase.build_shared_deck(count, seed_value)
	enabled_factions = CardDatabase.choose_factions(count, seed_value)
	discard.clear()
	resolving.clear()
	inspected.clear()
	logs.clear()
	visual_events.clear()
	pending.clear()
	_queue.clear()
	winner = -1
	round_number = 1
	_rng.seed = seed_value
	for slot in range(count):
		var player_hand: Array[Dictionary] = []
		var player_buffer: Array[Dictionary] = []
		players.append({"hp":12, "cost":3, "hand":player_hand, "buffer":player_buffer, "main":{}, "sub":{}, "used":{}, "attack_used":false, "counter_used":false, "prepared":false, "attack_mods":{}, "discount":0, "equipped_forge":false, "blood_paid":false, "res_once":0, "draw_penalty":false, "blocked":[], "damaged_by":[]})
	for n in range(5):
		for p in players:
			p.hand.append(deck.pop_back())
	current = _rng.randi_range(0, count - 1)
	self.log("本局体系：%s。玩家%d先手。" % ["、".join(enabled_factions), current + 1])
	_begin_turn(current)
	_drain()

func alive(slot: int) -> bool:
	return slot >= 0 and slot < players.size() and int(players[slot].hp) > 0

func resonance(slot: int, faction: String) -> int:
	if not alive(slot) or faction.is_empty(): return 0
	var p: Dictionary = players[slot]
	if str(p.main.get("faction", "")) != faction: return 0
	var names: Dictionary = {str(p.main.get("name", "")):true}
	var count := 0
	for card in [p.sub] + p.buffer:
		if str(card.get("faction", "")) == faction and not names.has(str(card.get("name", ""))):
			names[str(card.name)] = true
			count += 1
	return mini(2, count)

func effect_target_for(slot: int, card: Dictionary) -> String:
	match str(card.get("base_id", "")):
		"star_finale":
			return "opponent" if resonance(slot, "星序") >= 2 else "self"
		"echo_finale":
			return "opponent" if resonance(slot, "回响") > 0 and not _filtered(players[slot].buffer, "回响").is_empty() else "self"
	return str(card.get("effect_target", "self"))

func log(message: String) -> void:
	logs.append(message)

func add_steps(steps: Array) -> void:
	for i in range(steps.size() - 1, -1, -1):
		_queue.push_front(steps[i])

func _drain() -> void:
	if _draining: return
	_draining = true
	while pending.is_empty() and not _queue.is_empty():
		var next: Callable = _queue.pop_front()
		next.call()
	if pending.is_empty() and _queue.is_empty(): _settle_victory()
	# A delayed counter can eliminate the acting player after their source action.
	# Advance only after every queued resolution/trigger is finished.
	if pending.is_empty() and _queue.is_empty() and winner < 0 and not alive(current):
		_advance_turn(current)
	_draining = false
	if pending.is_empty() and not _queue.is_empty(): _drain()

func choose(slot: int, title: String, cards: Array, minimum: int, maximum: int, callback: Callable, options: Array = [], validator: Callable = Callable(), kind: String = "selection") -> void:
	if cards.is_empty() and options.is_empty() and minimum == 0:
		var empty_selection: Array[Dictionary] = []
		callback.call(empty_selection, "")
		return
	pending = {"slot":slot, "kind":kind, "title":title, "cards":cards.duplicate(true), "min":minimum, "max":maximum, "options":options.duplicate(true)}
	_choice_callback = callback
	_choice_validator = validator

func _validate_choice(slot: int, action: Dictionary) -> String:
	if int(pending.slot) != slot or action.get("type") != "choose": return "请等待指定玩家完成选择"
	var ids: Array = action.get("card_ids", [])
	if ids.size() < int(pending.min) or ids.size() > int(pending.max): return "选择数量不符合要求"
	var seen: Dictionary = {}
	var selected: Array[Dictionary] = []
	for id_value in ids:
		var id := str(id_value)
		var card := find(pending.cards, id)
		if card.is_empty() or seen.has(id): return "卡牌选择无效或重复"
		seen[id] = true
		selected.append(card)
	var option := str(action.get("option", ""))
	if not pending.options.is_empty():
		var found := false
		for entry in pending.options:
			if str(entry.id) == option: found = true
		if not found: return "请选择一个有效选项"
	elif not option.is_empty(): return "当前选择没有此选项"
	if _choice_validator.is_valid(): return str(_choice_validator.call(selected, option))
	return ""

func validate_action(slot: int, action: Dictionary) -> String:
	if not alive(slot): return "玩家已出局或不存在"
	if not pending.is_empty(): return _validate_choice(slot, action)
	if winner >= 0: return "本局已结束"
	if slot != current: return "还未轮到你行动"
	var p: Dictionary = players[slot]
	var kind := str(action.get("type", ""))
	match kind:
		"equip", "effect":
			var card := find(p.hand, str(action.get("card_id", "")))
			if card.is_empty(): return "手牌中没有该牌"
			if str(card.id) in p.blocked: return "引魂取回的这张牌本回合不能使用"
			if kind == "equip":
				if card.type != "装备牌": return "该牌不是装备"
				if action.get("equipment_slot", "main") not in ["main", "sub"]: return "装备槽无效"
				if int(p.cost) < equip_cost(slot, card): return "费用不足"
			else:
				if card.type != "效果牌" or card.get("subtype") == "counter": return "此牌不能在行动阶段使用"
				if int(p.cost) < int(card.cost): return "费用不足"
				var target := int(action.get("target_slot", slot))
				if not alive(target): return "目标已经出局或不存在"
				var target_type := effect_target_for(slot, card)
				if target_type == "opponent" and target == slot: return "请选择其他玩家"
				if target_type == "self" and target != slot: return "此牌只能对自己使用"
				var id := str(card.base_id)
				var r := resonance(slot, str(card.faction))
				if id in ["echo_return", "echo_barrier", "neutral_aid"] and p.buffer.is_empty(): return "没有可操作的缓冲牌"
				if id == "forge_reclaim" and _filtered(p.buffer, "", 99, true).is_empty(): return "没有缓冲中的装备"
				if id == "grave_rite" and p.hand.size() < 2: return "没有其他可弃手牌"
				if id == "grave_pick" and _filtered(discard, "归骸", 2 if r > 0 else 1).is_empty(): return "没有符合条件的弃牌"
				if id == "grave_summon" and _summon_candidates(r).is_empty(): return "没有符合条件的弃牌"
				if id == "hunt_cutoff" and discard.is_empty(): return "公共弃牌区为空"
				if id == "neutral_disarm" and players[target].main.is_empty(): return "目标没有主装备"
				if id == "neutral_dismantle" and players[target].buffer.is_empty(): return "目标没有缓冲牌"
				if bool(action.get("options", {}).get("enhanced", false)):
					if id not in ["blood_pact", "blood_search", "blood_sever", "blood_finale", "grave_spike", "grave_finale"]: return "此牌没有额外代价分支"
					if id != "blood_pact" and r == 0: return "强化分支需要共鸣"
					if id.begins_with("blood_") and int(p.hp) <= (2 if id == "blood_finale" else 1): return "支付真血后必须至少保留1点"
					if id.begins_with("grave_") and _burial_names() < (2 if id == "grave_finale" else 1): return "不同名归骸素材不足"
		"attack":
			if p.main.is_empty(): return "主装备为空"
			if p.attack_used: return "本回合已经攻击"
			var target := int(action.get("target_slot", -1))
			if not alive(target) or target == slot: return "攻击目标无效"
		"prepare":
			if round_number <= 1: return "第一轮禁止执行整备"
			if p.prepared: return "本回合已执行过整备或抽牌"
			if int(p.cost) < prepare_cost(slot) or p.hand.is_empty() or deck.is_empty(): return "本回合不能整备"
			var discard_id := str(action.get("card_id", ""))
			if not discard_id.is_empty() and find(p.hand, discard_id).is_empty(): return "整备弃牌不在手牌中"
		"draw_two":
			if p.prepared: return "本回合已执行过整备或抽牌"
			if int(p.cost) < 1 or (deck.is_empty() and discard.is_empty()): return "本回合不能抽牌"
		"swap_equipment":
			if p.main.is_empty() and p.sub.is_empty(): return "没有可交换的装备"
		"end_turn": pass
		_: return "未知行动"
	return ""

func submit(slot: int, action: Dictionary) -> String:
	var error := validate_action(slot, action)
	if not error.is_empty(): return error
	if not pending.is_empty():
		var selected: Array[Dictionary] = []
		for id in action.get("card_ids", []): selected.append(find(pending.cards, str(id)))
		var callback := _choice_callback
		pending = {}
		_choice_callback = Callable()
		_choice_validator = Callable()
		callback.call(selected, str(action.get("option", "")))
	else:
		match str(action.type):
			"equip": _equip(slot, action)
			"effect": _declare_effect(slot, action)
			"attack": _declare_attack(slot, int(action.target_slot))
			"prepare": _prepare(slot, str(action.get("card_id", "")))
			"draw_two": _draw_two(slot)
			"swap_equipment":
				var old: Dictionary = players[slot].main
				players[slot].main = players[slot].sub
				players[slot].sub = old
				self.log("玩家%d交换了主副装备。" % (slot + 1))
			"end_turn": _end_turn(slot)
	_drain()
	return ""

func legal_actions(slot: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not alive(slot) or winner >= 0 or not pending.is_empty() or slot != current: return result
	for card in players[slot].hand:
		if card.type == "装备牌":
			for where in ["main", "sub"]:
				_offer(result, slot, {"type":"equip", "card_id":card.id, "equipment_slot":where, "label":"%s → %s装备" % [card.name, "主" if where == "main" else "副"]})
		elif card.get("subtype") != "counter":
			for target in range(players.size()):
				var r := resonance(slot, str(card.faction))
				var base_id := str(card.base_id)
				# 未选择额外代价时，这些牌按基础效果结算。
				var optional_cost: bool = base_id in ["blood_pact", "blood_search", "blood_sever", "blood_finale", "grave_spike", "grave_finale"]
				var tiers: PackedStringArray = ["基础", "共鸣", "深度共鸣"]
				var tier := tiers[r]
				var branch := tier
				if optional_cost:
					branch = "基础"
				var label: String = str(card.name) + " · " + branch
				if effect_target_for(slot, card) == "opponent":
					label += " → 玩家" + str(target + 1)
				_offer(result, slot, {"type":"effect", "card_id":card.id, "target_slot":target, "label":label})
				var upgrade := tier
				if base_id in ["blood_pact", "blood_search", "grave_spike"]:
					upgrade = "强化"
					if r > 0:
						upgrade = "共鸣"
				var costs: PackedStringArray = ["支付1真血", "支付2真血", "归葬1张", "归葬2张"]
				var cost := costs[2]
				if base_id == "blood_finale":
					cost = costs[1]
				elif base_id.begins_with("blood_"):
					cost = costs[0]
				elif base_id == "grave_finale":
					cost = costs[3]
				var enhanced_label: String = str(card.name) + " · " + upgrade + "（" + cost + "）"
				if card.effect_target == "opponent":
					enhanced_label += " → 玩家" + str(target + 1)
				_offer(result, slot, {"type":"effect", "card_id":card.id, "target_slot":target, "options":{"enhanced":true}, "label":enhanced_label})
	for target in range(players.size()):
		_offer(result, slot, {"type":"attack", "target_slot":target, "label":"攻击玩家%d" % (target + 1)})
	_offer(result, slot, {"type":"prepare", "label":"整备 · %d费并弃1张" % prepare_cost(slot)})
	_offer(result, slot, {"type":"draw_two", "label":"抽牌 · 1费抽2张"})
	_offer(result, slot, {"type":"swap_equipment", "label":"交换主副装备"})
	_offer(result, slot, {"type":"end_turn", "label":"结束回合（保留余费）"})
	return result

func _offer(out: Array[Dictionary], slot: int, action: Dictionary) -> void:
	if validate_action(slot, action).is_empty(): out.append(action)

func find(cards: Array, id: String) -> Dictionary:
	for card in cards:
		if str(card.id) == id: return card
	return {}

func take(cards: Array, id: String) -> Dictionary:
	for i in range(cards.size()):
		if str(cards[i].id) == id: return cards.pop_at(i)
	return {}

func _filtered(cards: Array, faction: String = "", max_cost: int = 99, equipment: bool = false) -> Array:
	return cards.filter(func(c: Dictionary) -> bool: return (faction.is_empty() or c.get("faction") == faction) and int(c.cost) <= max_cost and (not equipment or c.type == "装备牌"))

func _summon_candidates(r: int) -> Array:
	return discard.filter(func(c: Dictionary) -> bool: return int(c.cost) <= 1 or (r > 0 and c.get("faction") == "归骸"))

func _burial_names() -> int:
	var names: Dictionary = {}
	for card in discard:
		if card.get("faction") == "归骸": names[card.name] = true
	return names.size()

func _choose_burial(slot: int, n: int, callback: Callable) -> void:
	choose(slot, "归葬：选择%d张不同名归骸牌，点击顺序即置底顺序" % n, _filtered(discard, "归骸"), n, n, callback, [], func(cards: Array, _option: String) -> String:
		var names: Dictionary = {}
		for card in cards:
			if names.has(card.name): return "归葬必须选择不同名牌"
			names[card.name] = true
		return "", "order")

func prepare_count() -> int:
	return 3 if players.size() == 2 else 4

func prepare_cost(slot: int) -> int:
	return 0 if players[slot].main.get("base_id", "") == "star_instrument" and resonance(slot, "星序") > 0 else 1

func equip_cost(slot: int, card: Dictionary) -> int:
	return maxi(0, int(card.cost) - (int(players[slot].discount) if card.get("faction") == "铸锋" else 0))

func _equip(slot: int, action: Dictionary) -> void:
	var p: Dictionary = players[slot]
	var card := take(p.hand, str(action.card_id))
	p.cost -= equip_cost(slot, card)
	if card.faction == "铸锋":
		p.discount = 0
		p.equipped_forge = true
	var field := str(action.get("equipment_slot", "main"))
	if not p[field].is_empty(): discard.append(p[field])
	p[field] = card
	self.log("玩家%d装备%s到%s槽。" % [slot + 1, card.name, "主" if field == "main" else "副"])
	var ctx := _context(slot, slot, card)
	if card.faction == "铸锋" and str(p.main.get("base_id", "")) == "forge_hammer" and str(p.main.id) != str(card.id):
		_schedule_trigger(ctx, slot, "forge_hammer", func(): _optional_buffer_return(ctx, slot, "铸锋", "forge_hammer"))
	_enqueue_triggers(ctx)

func _context(slot: int, target: int, card: Dictionary) -> Dictionary:
	return {"actor":slot, "target":target, "card":card, "id":str(card.get("base_id", "attack")), "r":resonance(slot, str(card.get("faction", ""))), "paid":0, "bury":[], "damage_result":{}, "triggers":[], "kind":"effect", "has_damage":false, "reduction":0, "cancel_move":false, "delayed":[], "lost_hp":0}

func _declare_effect(slot: int, action: Dictionary) -> void:
	var card := find(players[slot].hand, str(action.card_id))
	var enhanced := bool(action.get("options", {}).get("enhanced", false))
	if enhanced and str(card.base_id).begins_with("grave_"):
		_choose_burial(slot, 2 if card.base_id == "grave_finale" else 1, func(cards: Array, _option: String): _pay_effect(slot, action, cards))
	else: _pay_effect(slot, action, [])

func _pay_effect(slot: int, action: Dictionary, burial: Array) -> void:
	var p: Dictionary = players[slot]
	var card := take(p.hand, str(action.card_id))
	p.cost -= int(card.cost)
	resolving.append(card)
	var ctx := _context(slot, int(action.get("target_slot", slot)), card)
	if bool(action.get("options", {}).get("enhanced", false)) and str(card.base_id).begins_with("blood_"):
		ctx.paid = 2 if card.base_id == "blood_finale" else 1
		p.hp -= int(ctx.paid)
		p.blood_paid = true
	_pay_burial(ctx, burial)
	ctx.r = resonance(slot, str(card.faction))
	ctx.has_damage = _has_damage(ctx)
	ctx.blockade_discard = players[int(ctx.target)].hand.size() > p.hand.size()
	self.log("玩家%d使用%s（%s%s）。" % [slot + 1, card.name, ["基础", "共鸣", "深度共鸣"][int(ctx.r)], "，支付%d真血" % int(ctx.paid) if int(ctx.paid) > 0 else ""])
	add_steps([func(): _open_counter(ctx), func(): CardEffects.resolve(self, ctx), func(): _finish_effect(ctx)])

func _pay_burial(ctx: Dictionary, cards: Array) -> void:
	for card in cards:
		var moved := take(discard, str(card.id))
		if not moved.is_empty():
			ctx.bury.append(moved)
	for i in range(ctx.bury.size() - 1, -1, -1): deck.push_front(ctx.bury[i])
	if not ctx.bury.is_empty(): event(ctx, int(ctx.actor), "burial", ctx.bury)

func _has_damage(ctx: Dictionary) -> bool:
	var id := str(ctx.id)
	if id in ["forge_wedge", "echo_aftershock", "blood_pact", "blood_sever", "blood_finale", "star_fall", "grave_spike", "grave_finale", "hunt_probe", "hunt_retreat", "hunt_finale"]: return true
	return (id == "echo_finale" and int(ctx.r) > 0 and not _filtered(players[int(ctx.actor)].buffer, "回响").is_empty()) or (id == "star_finale" and int(ctx.r) >= 2)

func attack_buff(slot: int, id: String, data: Dictionary) -> void:
	var previous: Dictionary = players[slot].attack_mods.get(id, {})
	if int(data.get("atk", 0)) >= int(previous.get("atk", 0)): players[slot].attack_mods[id] = data

func _declare_attack(slot: int, target: int) -> void:
	var p: Dictionary = players[slot]
	p.attack_used = true
	var ctx := _context(slot, target, p.main)
	ctx.kind = "attack"
	ctx.has_damage = true
	ctx.attack_value = int(p.main.get("attack", 0))
	ctx.defense = int(players[target].main.get("defense", 0))
	ctx.res_ignore = 0
	ctx.draw_buffer2 = false
	for mod in p.attack_mods.values():
		ctx.attack_value += int(mod.get("atk", 0))
		if mod.has("target") and int(mod.target) != target: continue
		if bool(mod.get("ignore_def", false)): ctx.defense = 0
		if mod.has("def_cap"): ctx.defense = mini(int(ctx.defense), int(mod.def_cap))
		ctx.res_ignore += int(mod.get("res_ignore", 0))
		ctx.draw_buffer2 = bool(ctx.draw_buffer2) or bool(mod.get("draw_buffer2", false))
	p.attack_mods.clear()
	if int(ctx.r) > 0:
		if ctx.id == "forge_blade" and p.equipped_forge: ctx.attack_value += 2
		if ctx.id == "blood_blade" and p.blood_paid: ctx.attack_value += 2
		if ctx.id == "hunt_crossbow" and players[target].hand.size() <= p.hand.size(): ctx.attack_value += 2
	self.log("玩家%d向玩家%d宣言攻击（ATK %d）。" % [slot + 1, target + 1, int(ctx.attack_value)])
	visual_events.append({"kind":"attack", "actor":slot, "target":target, "amount":int(ctx.attack_value)})
	add_steps([func(): _open_counter(ctx), func(): damage(ctx, target, int(ctx.attack_value)), func():
		if bool(ctx.draw_buffer2) and int(ctx.damage_result.get("buffered", 0)) >= 2 and alive(slot): draw(slot, 1), func(): _finish_source(ctx)])

func _legal_counters(ctx: Dictionary) -> Array:
	var target := int(ctx.target)
	if not alive(target) or target == int(ctx.actor) or target == current: return []
	var p: Dictionary = players[target]
	if p.counter_used or int(p.cost) < 1: return []
	return p.hand.filter(func(card: Dictionary) -> bool:
		var id := str(card.base_id)
		return (id == "forge_counter" and ctx.kind == "attack") or (id == "star_counter" and ctx.kind == "effect") or (id in ["echo_counter", "blood_counter", "grave_counter", "hunt_counter"] and bool(ctx.has_damage)))

func _open_counter(ctx: Dictionary) -> void:
	var cards := _legal_counters(ctx)
	if cards.is_empty(): return
	var slot := int(ctx.target)
	choose(slot, "反击窗口：选择1张反击牌，或不选并确认放弃", cards, 0, 1, func(selected: Array, _option: String):
		if not selected.is_empty(): _counter_branch(ctx, slot, selected[0]), [], Callable(), "counter")

func _counter_branch(source: Dictionary, slot: int, card: Dictionary) -> void:
	var r := resonance(slot, str(card.faction))
	var extra: bool = (card.base_id == "blood_counter" and int(players[slot].hp) > 1) or (card.base_id == "grave_counter" and _burial_names() >= 1)
	if r > 0 and extra:
		choose(slot, "反击分支：支付额外代价强化，或使用基础减伤", [], 0, 0, func(_cards: Array, option: String):
			if option == "enhanced" and card.base_id == "grave_counter":
				_choose_burial(slot, 1, func(cards: Array, _o: String): _resolve_counter(source, slot, card, true, cards))
			else: _resolve_counter(source, slot, card, option == "enhanced", []), [{"id":"base", "label":"基础减伤1"}, {"id":"enhanced", "label":"归葬1张" if card.base_id == "grave_counter" else "支付1真血"}], Callable(), "choice")
	else: _resolve_counter(source, slot, card, false, [])

func _resolve_counter(source: Dictionary, slot: int, card: Dictionary, enhanced: bool, burial: Array) -> void:
	var p: Dictionary = players[slot]
	card = take(p.hand, str(card.id))
	p.cost -= 1
	p.counter_used = true
	resolving.append(card)
	var ctx := _context(slot, int(source.actor), card)
	ctx.kind = "counter"
	if enhanced and card.base_id == "blood_counter":
		p.hp -= 1
		p.blood_paid = true
		ctx.paid = 1
	_pay_burial(ctx, burial)
	ctx.r = resonance(slot, str(card.faction))
	self.log("玩家%d反击：%s。" % [slot + 1, card.name])
	add_steps([func(): _counter_body(source, ctx, slot, card, enhanced), func(): _finish_effect(ctx)])

func _counter_body(source: Dictionary, ctx: Dictionary, slot: int, card: Dictionary, enhanced: bool) -> void:
	var r := int(ctx.r)
	match str(card.base_id):
		"forge_counter":
			source.reduction = 3 if r > 0 else 1
			if r > 0: source.delayed.append({"kind":"forge", "owner":slot})
		"echo_counter":
			source.reduction = 2 if r > 0 else 1
			if r > 0: _optional_buffer_return(ctx, slot, "回响")
		"blood_counter":
			source.reduction = 2 if enhanced else 1
			if enhanced: source.delayed.append({"kind":"blood", "owner":slot})
		"star_counter":
			if r > 0:
				if source.has_damage: source.reduction = 2
				else: source.cancel_move = true
			CardEffects.inspect_counter(self, ctx)
		"grave_counter": source.reduction = 2 if enhanced else 1
		"hunt_counter":
			source.reduction = 1
			if r > 0:
				if players[int(source.actor)].hand.is_empty(): source.reduction = 3
				else:
					choose(int(source.actor), "反向包围：弃1张手牌，或让对方减伤3", [], 0, 0, func(_cards: Array, option: String):
						if option == "discard": request_discard(ctx, int(source.actor), 1)
						else: source.reduction = 3
					, [{"id":"discard", "label":"弃1张手牌"}, {"id":"reduce", "label":"对方减伤3"}], Callable(), "choice")

func cancel_movement(ctx: Dictionary) -> bool:
	if bool(ctx.get("cancel_move", false)):
		ctx.cancel_move = false
		self.log("命轨偏折取消了本次区域移动。")
		return true
	return false

func _enqueue_triggers(ctx: Dictionary) -> void:
	var triggers: Array = ctx.triggers.duplicate()
	ctx.triggers.clear()
	add_steps(triggers)


func _finish_effect(ctx: Dictionary) -> void:
	var slot := int(ctx.actor)
	if int(ctx.paid) > 0 and alive(slot) and str(ctx.card.get("faction", "")) == "血契":
		_schedule_trigger(ctx, slot, "blood_chalice", func(): heal(slot, 1))
	var card := take(resolving, str(ctx.card.id))
	if not card.is_empty(): discard.append(card)
	add_steps([func(): _enqueue_triggers(ctx), func(): _finish_source(ctx)])

func _finish_source(ctx: Dictionary) -> void:
	if ctx.kind == "attack":
		var triggers: Array = ctx.triggers.duplicate()
		ctx.triggers.clear()
		add_steps(triggers + [func(): _retaliate(ctx)])
	else: _retaliate(ctx)

func _retaliate(ctx: Dictionary) -> void:
	var steps: Array = []
	for retaliation in ctx.delayed:
		var owner := int(retaliation.owner)
		var source := int(ctx.actor)
		if not alive(owner) or not alive(source): continue
		if retaliation.kind == "forge" and int(ctx.lost_hp) > 0: continue
		var amount := 1 if retaliation.kind == "forge" else 2
		var reaction := _context(owner, source, {})
		reaction.kind = "retaliation"
		steps.append(func():
			if alive(owner) and alive(source): damage(reaction, source, amount))
		steps.append(func(): _enqueue_triggers(reaction))
	ctx.delayed.clear()
	add_steps(steps)

func damage(ctx: Dictionary, target: int, base: int, bufferable: bool = true) -> void:
	ctx.damage_result = {"buffered":0, "lost_hp":0}
	if not alive(target): return
	var p: Dictionary = players[target]
	var resistance := int(p.res_once)
	p.res_once = 0
	var amount := 0
	if ctx.kind == "attack":
		resistance = maxi(0, resistance - int(ctx.get("res_ignore", 0)))
		amount = maxi(1 if resistance == 0 else 0, base - int(ctx.get("defense", 0)) - resistance)
	else: amount = maxi(0, base - resistance)
	if target == int(ctx.target):
		amount = maxi(0, amount - int(ctx.reduction))
		ctx.reduction = 0
	var actor_slot := int(ctx.actor)
	if amount > 0 and actor_slot != target and actor_slot >= 0:
		var damaged_by: Array = p.get("damaged_by", [])
		if not damaged_by.has(actor_slot):
			damaged_by.append(actor_slot)
		var attacker_index: int = damaged_by.find(actor_slot) + 1
		var dogpile_reduction := 0
		if attacker_index == 2:
			dogpile_reduction = 1
		elif attacker_index >= 3:
			dogpile_reduction = 2
		if dogpile_reduction > 0 and amount > 0:
			var prev_amount: int = amount
			amount = maxi(1, amount - dogpile_reduction)
			self.log("玩家%d受到第%d位对手的伤害，触发集火衰减 -%d，保底保留1点（原%d -> 现%d）。" % [target + 1, attacker_index, dogpile_reduction, prev_amount, amount])
	visual_events.append({"kind":"hit", "actor":int(ctx.actor), "target":target, "amount":amount})
	if amount == 0:
		self.log("玩家%d本段伤害为0。" % (target + 1))
		return
	if bufferable and not p.hand.is_empty():
		choose(target, "缓冲%d" % amount, p.hand, 0, mini(amount, p.hand.size()), func(cards: Array, _option: String): _resolve_damage(ctx, target, amount, cards), [], Callable(), "buffer")
	else: _resolve_damage(ctx, target, amount, [])

func _resolve_damage(ctx: Dictionary, target: int, amount: int, selected: Array) -> void:
	var p: Dictionary = players[target]
	var before := int(p.hp)
	var moved: Array = []
	for card in selected: moved.append(take(p.hand, str(card.id)))
	buffer_add(target, moved)
	p.hp = maxi(0, int(p.hp) - maxi(0, amount - moved.size()))
	var lost := before - int(p.hp)
	ctx.damage_result = {"buffered":moved.size(), "lost_hp":lost}
	visual_events.append({"kind":"result", "target":target, "buffered":moved.size(), "lost_hp":lost})
	if target == int(ctx.target): ctx.lost_hp += lost
	self.log("玩家%d缓冲%d张，损失%d真血，剩余%d。" % [target + 1, moved.size(), lost, int(p.hp)])
	refresh_winner()
	if alive(target) and not _filtered(moved, "回响").is_empty():
		_schedule_trigger(ctx, target, "echo_amulet", func(): draw(target, 1))

func buffer_add(slot: int, cards: Array) -> void:
	var p: Dictionary = players[slot]
	for card in cards:
		p.buffer.append(card)
		if p.buffer.size() > 4:
			for n in range(4): discard.append(p.buffer.pop_front())
			p.hp = maxi(0, int(p.hp) - 1)
			self.log("玩家%d缓冲溢出：弃最早4张，失去1真血。" % (slot + 1))
	refresh_winner()

func heal(slot: int, amount: int) -> void:
	if not alive(slot): return
	var before := int(players[slot].hp)
	players[slot].hp = mini(MAX_HP, int(players[slot].hp) + amount)
	var restored := int(players[slot].hp) - before
	if restored > 0:
		visual_events.append({"kind":"heal", "target":slot, "amount":restored})

func move_buffer(ctx: Dictionary, slot: int, cards: Array, destination: String) -> void:
	if not alive(slot): return
	var moved: Array = []
	for card in cards:
		var actual := take(players[slot].buffer, str(card.id))
		if actual.is_empty(): continue
		moved.append(actual)
		if destination == "hand": players[slot].hand.append(actual)
		else: discard.append(actual)
	if destination == "hand": event(ctx, slot, "recover_buffer", moved)

func request_discard(ctx: Dictionary, slot: int, n: int, after: Callable = Callable()) -> void:
	if not alive(slot) or players[slot].hand.is_empty():
		if after.is_valid(): after.call()
		return
	var count := mini(n, players[slot].hand.size())
	choose(slot, "选择弃置%d张手牌" % count, players[slot].hand, count, count, func(cards: Array, _option: String):
		var moved: Array = []
		for card in cards:
			var actual := take(players[slot].hand, str(card.id))
			discard.append(actual)
			moved.append(actual)
		if slot != int(ctx.actor): event(ctx, int(ctx.actor), "discard_opponent", moved)
		if after.is_valid(): after.call())

func event(ctx: Dictionary, slot: int, event_name: String, cards: Array = []) -> void:
	if not alive(slot): return
	var faction := str(ctx.card.get("faction", ""))
	match event_name:
		"burial": _schedule_trigger(ctx, slot, "grave_lamp", func(): _optional_buffer_return(ctx, slot, "归骸", "grave_lamp"))
		"recover_buffer":
			if faction == "回响" and not _filtered(cards, "回响").is_empty(): _schedule_trigger(ctx, slot, "echo_focus", func(): heal(slot, 1))
		"inspect_take":
			if faction == "星序" and not _filtered(cards, "星序").is_empty(): _schedule_trigger(ctx, slot, "star_chart", func(): _optional_cycle(slot, "star_chart"))
		"recover_discard":
			if faction == "归骸" and not _filtered(cards, "归骸").is_empty(): _schedule_trigger(ctx, slot, "grave_casket", func(): heal(slot, 1))
		"discard_opponent":
			if faction == "围猎" and not cards.is_empty(): _schedule_trigger(ctx, slot, "hunt_flag", func(): _optional_cycle(slot, "hunt_flag"))

func _schedule_trigger(ctx: Dictionary, slot: int, ability: String, callback: Callable) -> void:
	if not alive(slot): return
	var p: Dictionary = players[slot]
	if str(p.main.get("base_id", "")) != ability or p.used.has(ability) or resonance(slot, str(p.main.get("faction", ""))) == 0: return
	p.used[ability] = true
	ctx.triggers.append(func():
		if alive(slot):
			self.log("玩家%d触发%s的限次能力。" % [slot + 1, CardDatabase.find_card(ability).name])
			callback.call())

func _optional_buffer_return(ctx: Dictionary, slot: int, faction: String, ability: String = "") -> void:
	var cards := _filtered(players[slot].buffer, faction)
	if cards.is_empty():
		if not ability.is_empty(): players[slot].used.erase(ability)
		return
	choose(slot, "可取回1张%s缓冲牌（不选可跳过）" % faction, cards, 0, 1, func(selected: Array, _option: String):
		if selected.is_empty() and not ability.is_empty(): players[slot].used.erase(ability)
		else: move_buffer(ctx, slot, selected, "hand"))

func _optional_cycle(slot: int, ability: String = "") -> void:
	if players[slot].hand.is_empty():
		if not ability.is_empty(): players[slot].used.erase(ability)
		return
	choose(slot, "可将1张手牌置底，再抽1张", players[slot].hand, 0, 1, func(cards: Array, _option: String):
		if cards.is_empty():
			if not ability.is_empty(): players[slot].used.erase(ability)
		else:
			deck.push_front(take(players[slot].hand, str(cards[0].id)))
			draw(slot, 1))

func draw(slot: int, n: int) -> void:
	if not alive(slot) or n <= 0: return
	if not deck.is_empty():
		players[slot].hand.append(deck.pop_back())
		if n > 1: add_steps([func(): draw(slot, n - 1)])
		return
	var steps: Array = []
	for offset in range(1, players.size() + 1):
		var other := (slot + offset) % players.size()
		if alive(other) and not players[other].hand.is_empty():
			steps.append(func():
				if alive(other) and not players[other].hand.is_empty():
					choose(other, "牌堆耗尽：为公共洗牌弃1张手牌", players[other].hand, 1, 1, func(cards: Array, _o: String): discard.append(take(players[other].hand, str(cards[0].id)))))
	steps.append(func():
		deck.append_array(discard)
		discard.clear()
		for i in range(deck.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var card: Dictionary = deck[i]
			deck[i] = deck[j]
			deck[j] = card
		self.log("公共弃牌已洗回，继续抽牌。")
		if not deck.is_empty(): draw(slot, n))
	add_steps(steps)

func _draw_two(slot: int) -> void:
	var p: Dictionary = players[slot]
	p.cost -= 1
	p.prepared = true
	self.log("玩家%d消耗1费执行公共抽牌，抽取2张牌。" % (slot + 1))
	draw(slot, 2)

func _prepare(slot: int, discard_id: String = "") -> void:
	var p: Dictionary = players[slot]
	p.cost -= prepare_cost(slot)
	p.prepared = true
	if not discard_id.is_empty():
		discard.append(take(p.hand, discard_id))
		CardEffects.prepare_inspect(self, slot)
		return
	choose(slot, "整备：弃置1张手牌", p.hand, 1, 1, func(cards: Array, _o: String):
		discard.append(take(p.hand, str(cards[0].id)))
		CardEffects.prepare_inspect(self, slot))

func _end_turn(slot: int) -> void:
	if players[slot].hand.size() > MAX_HAND:
		var n: int = players[slot].hand.size() - MAX_HAND
		choose(slot, "结束阶段：弃牌至8张", players[slot].hand, n, n, func(cards: Array, _o: String):
			for card in cards: discard.append(take(players[slot].hand, str(card.id)))
			_advance_turn(slot))
	else: _advance_turn(slot)

func _advance_turn(slot: int) -> void:
	players[slot].attack_mods.clear()
	players[slot].discount = 0
	players[slot].blocked.clear()
	# 本回合 refers to the active player's turn, including off-turn blood payments.
	for p in players:
		p.blood_paid = false
		p.equipped_forge = false
	if winner >= 0: return
	var next := (slot + 1) % players.size()
	while not alive(next): next = (next + 1) % players.size()
	if next <= slot: round_number += 1
	current = next
	_begin_turn(next)

func _begin_turn(slot: int) -> void:
	var p: Dictionary = players[slot]
	p.used.clear()
	p.counter_used = false
	p.res_once = 0
	p.attack_used = false
	p.prepared = false
	p.damaged_by.clear()
	p.cost = 3
	var n := 1 if p.draw_penalty else 2
	p.draw_penalty = false
	self.log("玩家%d的准备阶段：费用重置3，抽%d张。" % [slot + 1, n])
	add_steps([func(): draw(slot, n)])

func refresh_winner() -> void:
	var living: Array[int] = []
	for slot in range(players.size()):
		var p: Dictionary = players[slot]
		if int(p.hp) > 0:
			living.append(slot)
			continue
		p.hp = 0
		discard.append_array(p.hand)
		discard.append_array(p.buffer)
		p.hand.clear()
		p.buffer.clear()
		if not p.main.is_empty(): discard.append(p.main)
		if not p.sub.is_empty(): discard.append(p.sub)
		p.main = {}
		p.sub = {}

func _settle_victory() -> void:
	var living: Array[int] = []
	for slot in range(players.size()):
		if alive(slot): living.append(slot)
	if living.size() == 1 and winner < 0:
		winner = living[0]
		self.log("玩家%d获胜。" % (winner + 1))
