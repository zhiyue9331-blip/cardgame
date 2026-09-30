class_name CardEffects
extends RefCounted

# Every step which can open a choice is queued separately from its continuation.
static func resolve(g, ctx: Dictionary) -> void:
	var a := int(ctx.actor)
	var t := int(ctx.target)
	var r := int(ctx.r)
	if not g.alive(a): return
	match str(ctx.id):
		"forge_temper": g.attack_buff(a, ctx.id, {"atk":2 if r > 0 else 1, "def_cap":1 if r > 0 else 999})
		"forge_reclaim":
			var cards: Array = g._filtered(g.players[a].buffer, "", 99, true)
			g.choose(a, "取回1张缓冲装备", cards, 1, 1, func(selected: Array, _o: String):
				g.move_buffer(ctx, a, selected, "hand")
				if r > 0 and selected[0].faction == "铸锋": g.draw(a, 1))
		"forge_wedge":
			g.add_steps([func(): g.damage(ctx, t, 1), func():
				if r > 0: g.attack_buff(a, ctx.id, {"target":t, "ignore_def":true})])
		"forge_reforge":
			g.add_steps([func():
				if not g.players[a].sub.is_empty():
					g.choose(a, "可将副装备回手（不选则保留）", [g.players[a].sub], 0, 1, func(selected: Array, _o: String):
						if not selected.is_empty():
							g.players[a].hand.append(g.players[a].sub)
							g.players[a].sub = {})
			, func():
				g.players[a].discount = maxi(int(g.players[a].discount), 2 if r > 0 else 1)
				if r > 0: g.attack_buff(a, ctx.id, {"atk":1})])
		"forge_finale": g.attack_buff(a, ctx.id, {"atk":3 if r > 0 else 1, "res_ignore":1 if r == 2 else 0, "draw_buffer2":r == 2})
		"echo_record":
			g.add_steps([func():
				var cards: Array = g._filtered(g.players[a].hand, "回响")
				g.choose(a, "可将1张回响手牌放入缓冲", cards, 0, mini(1, cards.size()), func(selected: Array, _o: String):
					if not selected.is_empty(): g.buffer_add(a, [g.take(g.players[a].hand, str(selected[0].id))]))
			, func(): g.draw(a, 2 if r > 0 else 1)])
		"echo_return":
			g.choose(a, "取回1张缓冲牌；共鸣可取2张且至少1张回响", g.players[a].buffer, 1, mini(2 if r > 0 else 1, g.players[a].buffer.size()), func(selected: Array, _o: String): g.move_buffer(ctx, a, selected, "hand"), [], func(selected: Array, _o: String) -> String:
				return "取2张时必须包含回响牌" if selected.size() > 1 and g._filtered(selected, "回响").is_empty() else "")
		"echo_aftershock":
			g.add_steps([func(): g.damage(ctx, t, 2), func():
				if r > 0 and g.alive(t):
					var cards: Array = g._filtered(g.players[a].buffer, "回响")
					g.choose(a, "可清除1张回响缓冲牌，追加2点伤害", cards, 0, mini(1, cards.size()), func(selected: Array, _o: String):
						if not selected.is_empty():
							g.move_buffer(ctx, a, selected, "discard")
							g.damage(ctx, t, 2))])
		"echo_barrier":
			var res_bonus: bool = r > 0 and g._filtered(g.players[a].buffer, "回响").size() >= 2
			g.choose(a, "清除1张缓冲牌", g.players[a].buffer, 1, 1, func(selected: Array, _o: String):
				g.move_buffer(ctx, a, selected, "discard")
				if res_bonus: g.players[a].res_once = 1)
		"echo_finale":
			g.choose(a, "取回最多2张缓冲牌（点击顺序）", g.players[a].buffer, 0, mini(2, g.players[a].buffer.size()), func(selected: Array, _o: String):
				var damage_value: int = 2 * g._filtered(selected, "回响").size()
				g.move_buffer(ctx, a, selected, "hand")
				g.add_steps([func():
					if r > 0 and damage_value > 0: g.damage(ctx, t, damage_value)
				, func():
					if r == 2: g.heal(a, 1)]))
		"blood_pact": g.damage(ctx, t, (3 if r > 0 else 2) if int(ctx.paid) > 0 else 1)
		"blood_heal": g.heal(a, 2 if r > 0 and g.players[a].blood_paid else 1)
		"blood_search": _search(g, ctx, 5 if int(ctx.paid) > 0 else 3, "血契")
		"blood_sever": g.damage(ctx, t, 3 if r == 2 and int(ctx.paid) > 0 else 2, int(ctx.paid) == 0)
		"blood_finale":
			g.add_steps([func(): g.damage(ctx, t, 5 if int(ctx.paid) > 0 else 2), func():
				if r == 2 and int(ctx.paid) > 0 and g.alive(a):
					g.heal(a, 1)
					g.draw(a, 1)])
		"star_gaze": _search(g, ctx, 4 if r > 0 else 3, "" if r > 0 else "星序")
		"star_prophecy": _prophecy(g, ctx)
		"star_intercept": _intercept(g, ctx)
		"star_fall":
			if r == 0: g.damage(ctx, t, 2)
			else:
				var cards := _reveal(g, ctx, 3)
				var stars: Array = g._filtered(cards, "星序")
				g.choose(a, "展示最多2张不同名星序牌", stars, 0, mini(2, stars.size()), func(selected: Array, _o: String):
					var amount := 2 + selected.size()
					g.add_steps([func(): _finish_inspect(g, ctx, cards, []), func(): g.damage(ctx, t, amount)])
				, [], _different_names)
		"star_finale":
			var cards := _reveal(g, ctx, 5)
			var has_star: bool = r > 0 and not g._filtered(cards, "星序").is_empty()
			g.choose(a, "改写命轨：选牌入手，共鸣最多2张且至少1张星序", cards, mini(1, cards.size()), mini(2 if has_star else 1, cards.size()), func(selected: Array, _o: String):
				g.add_steps([func(): _finish_inspect(g, ctx, cards, selected), func():
					if r == 2: g.damage(ctx, t, 3)])
			, [], func(selected: Array, _o: String) -> String:
				return "必须包含1张星序牌" if has_star and g._filtered(selected, "星序").is_empty() else "")
		"grave_pick": _recover(g, ctx, g._filtered(g.discard, "归骸", 2 if r > 0 else 1))
		"grave_rite":
			g.choose(a, "葬仪：弃1张手牌", g.players[a].hand, 1, 1, func(selected: Array, _o: String):
				g.discard.append(g.take(g.players[a].hand, str(selected[0].id)))
				g.draw(a, 2 if r > 0 and selected[0].faction == "归骸" else 1))
		"grave_spike": g.damage(ctx, t, 3 if not ctx.bury.is_empty() else 2)
		"grave_summon": _recover(g, ctx, g._summon_candidates(r), true)
		"grave_finale":
			g.add_steps([func(): g.damage(ctx, t, 5 if not ctx.bury.is_empty() else 2), func():
				if r == 2 and not ctx.bury.is_empty() and g.alive(a): _recover(g, ctx, g._filtered(g.discard, "归骸", 2))])
		"hunt_probe":
			g.add_steps([func(): g.damage(ctx, t, 1), func():
				if r > 0 and g.players[t].hand.size() < g.players[a].hand.size(): g.draw(a, 1)])
		"hunt_retreat":
			if not g.alive(t): return
			if g.players[t].hand.is_empty(): g.damage(ctx, t, 2 if r > 0 else 1)
			else:
				g.choose(t, "逼退：弃1张手牌，或承受伤害", [], 0, 0, func(_s: Array, option: String):
					if option == "discard": g.request_discard(ctx, t, 1)
					else: g.damage(ctx, t, 2 if r > 0 else 1)
				, [{"id":"discard", "label":"弃1张手牌"}, {"id":"damage", "label":"受到%d点伤害" % (2 if r > 0 else 1)}], Callable(), "choice")
		"hunt_cutoff":
			g.choose(a, "断援：将1张公共弃牌置底", g.discard, 1, 1, func(selected: Array, _o: String):
				var tag := str(selected[0].faction)
				g.deck.push_front(g.take(g.discard, str(selected[0].id)))
				if r > 0 and not tag.is_empty() and tag == str(g.players[t].main.get("faction", "")): g.request_discard(ctx, t, 1))
		"hunt_blockade":
			if g.alive(t):
				g.players[t].draw_penalty = true
				if r > 0 and bool(ctx.get("blockade_discard", false)): g.request_discard(ctx, t, 1)
		"hunt_finale":
			g.add_steps([func(): g.damage(ctx, t, 4 if r > 0 and g.players[t].hand.size() <= g.players[a].hand.size() else 2), func():
				if r == 2 and int(ctx.damage_result.get("buffered", 0)) >= 2: g.request_discard(ctx, t, 1)])
		"neutral_meditate": g.add_steps([func(): g.draw(a, 1), func(): g._optional_cycle(a)])
		"neutral_aid":
			g.choose(a, "急救：清除1张缓冲牌", g.players[a].buffer, 1, 1, func(selected: Array, _o: String): g.move_buffer(ctx, a, selected, "discard"))
		"neutral_disarm":
			if g.alive(t) and not g.players[t].main.is_empty() and not g.cancel_movement(ctx):
				g.players[t].hand.append(g.players[t].main)
				g.players[t].main = {}
		"neutral_dismantle":
			if not g.alive(t) or g.players[t].buffer.is_empty(): return
			g.choose(a, "拆解阵式：选择对方1张缓冲牌", g.players[t].buffer, 1, 1, func(selected: Array, _o: String):
				if g.cancel_movement(ctx): return
				g.choose(t, "拆解阵式：选择“%s”的去向" % selected[0].name, [], 0, 0, func(_unused: Array, option: String): g.move_buffer(ctx, t, selected, option), [{"id":"hand", "label":"移入手牌"}, {"id":"discard", "label":"移入公共弃牌"}], Callable(), "choice"))

static func _different_names(selected: Array, _option: String) -> String:
	var names: Dictionary = {}
	for card in selected:
		if names.has(card.name): return "请选择不同名的牌"
		names[card.name] = true
	return ""

static func _reveal(g, ctx: Dictionary, n: int) -> Array:
	var a := int(ctx.actor)
	if str(ctx.card.get("faction", "")) == "星序" and str(g.players[a].main.get("base_id", "")) == "star_instrument" and g.resonance(a, "星序") > 0:
		n += 1
	var cards: Array = []
	for i in range(mini(n, g.deck.size())): cards.append(g.deck.pop_back())
	g.inspected.assign(cards)
	return cards

# Taken cards leave the public inspection area immediately. The remainder stays
# there until its owner explicitly orders it; a later draw can never see it early.
static func _finish_inspect(g, ctx: Dictionary, cards: Array, selected: Array, top: bool = false) -> void:
	var a := int(ctx.actor)
	for card in selected:
		g.take(g.inspected, str(card.id))
		g.players[a].hand.append(card)
	if not selected.is_empty(): g.event(ctx, a, "inspect_take", selected)
	var remaining: Array = []
	for card in cards:
		if not g.find(g.inspected, str(card.id)).is_empty(): remaining.append(card)
	var commit := func(ordered: Array, _o: String):
		if top:
			for i in range(ordered.size() - 1, -1, -1): g.deck.append(g.take(g.inspected, str(ordered[i].id)))
		else:
			for card in ordered: g.deck.push_front(g.take(g.inspected, str(card.id)))
	if remaining.size() <= 1: commit.call(remaining, "")
	else: g.choose(a, "排列剩余牌%s：第一张最先被抽到" % ("顶" if top else "底"), remaining, remaining.size(), remaining.size(), commit, [], Callable(), "order")

static func _search(g, ctx: Dictionary, n: int, faction: String, optional: bool = false) -> void:
	var cards := _reveal(g, ctx, n)
	var legal: Array = g._filtered(cards, faction)
	if legal.is_empty(): _finish_inspect(g, ctx, cards, []); return
	g.choose(int(ctx.actor), "检视：选择1张%s牌入手" % (faction if not faction.is_empty() else "任意"), legal, 0 if optional else 1, 1, func(selected: Array, _o: String): _finish_inspect(g, ctx, cards, selected))

static func inspect_counter(g, ctx: Dictionary) -> void:
	_search(g, ctx, 2, "星序", true)

static func prepare_inspect(g, slot: int) -> void:
	var ctx: Dictionary = g._context(slot, slot, {})
	_search(g, ctx, g.prepare_count(), "")

static func _prophecy(g, ctx: Dictionary) -> void:
	var cards := _reveal(g, ctx, 2)
	var a := int(ctx.actor)
	var r := int(ctx.r)
	g.add_steps([func():
		if r > 0:
			g.choose(a, "错位预言：可先将1张检视牌置底", cards, 0, mini(1, cards.size()), func(selected: Array, _o: String):
				if not selected.is_empty(): g.deck.push_front(g.take(g.inspected, str(selected[0].id))))
	, func(): _finish_inspect(g, ctx, cards, [], true), func():
		if r > 0: g.draw(a, 1)])

static func _intercept(g, ctx: Dictionary) -> void:
	var cards := _reveal(g, ctx, 4)
	var a := int(ctx.actor)
	if cards.is_empty(): return
	g.choose(a, "截取未来：先选择1张牌", cards, 1, 1, func(first: Array, _o: String):
		if int(ctx.r) > 0 and first[0].faction == "星序":
			var others: Array = cards.filter(func(c: Dictionary) -> bool: return c.faction != "星序")
			g.choose(a, "可再选择1张异系牌或中立牌", others, 0, mini(1, others.size()), func(extra: Array, _option: String): _finish_inspect(g, ctx, cards, first + extra))
		else: _finish_inspect(g, ctx, cards, first))

static func _recover(g, ctx: Dictionary, cards: Array, block_finale: bool = false) -> void:
	if cards.is_empty() or not g.alive(int(ctx.actor)): return
	var a := int(ctx.actor)
	g.choose(a, "从公共弃牌回收1张牌", cards, 1, 1, func(selected: Array, _o: String):
		var actual: Dictionary = g.take(g.discard, str(selected[0].id))
		g.players[a].hand.append(actual)
		if block_finale and int(actual.cost) == 3: g.players[a].blocked.append(str(actual.id))
		g.event(ctx, a, "recover_discard", selected))
