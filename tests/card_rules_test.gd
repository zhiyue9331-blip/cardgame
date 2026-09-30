extends SceneTree

var checks := 0
var failures := 0
var serial := 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func card(id: String) -> Dictionary:
	serial += 1
	var result := CardDatabase.find_card(id)
	result.id = "%s#%d" % [id, serial]
	return result

func game() -> CardRules:
	var g := CardRules.new()
	g.start(2, 82)
	g.current = 0
	g.pending = {}
	g._queue.clear()
	g.discard.clear()
	for p in g.players:
		p.hand.clear()
		p.buffer.clear()
		p.main = {}
		p.sub = {}
		p.cost = 3
	return g

func play(g: CardRules, id: String, target: int = 1, enhanced: bool = false) -> void:
	var data := card(id)
	g.players[0].hand.append(data)
	check(g.submit(0, {"type":"effect", "card_id":data.id, "target_slot":target, "options":{"enhanced":enhanced}}).is_empty(), "play " + id)

func select(g: CardRules, cards: Array = [], option: String = "") -> void:
	var ids: Array = []
	for c in cards: ids.append(c.id)
	check(not g.pending.is_empty(), "choice exists")
	if not g.pending.is_empty(): check(g.submit(int(g.pending.slot), {"type":"choose", "card_ids":ids, "option":option}).is_empty(), "choice accepted " + str(g.pending.get("title", "")))

func drain(g: CardRules) -> void:
	var n := 0
	while not g.pending.is_empty() and n < 40:
		n += 1
		var p: Dictionary = g.pending
		var selected: Array = p.cards.slice(0, int(p.min))
		var option := str(p.options[0].id) if not p.options.is_empty() else ""
		select(g, selected, option)
	check(g.pending.is_empty(), "resolution terminates")

# 付费共鸣和自动共鸣要能从合法行动里区分开。
func resonance_costs() -> void:
	var g := game()
	g.players[0].main = card("blood_blade")
	g.players[0].sub = card("blood_chalice")
	g.players[1].hand.append(card("neutral_sword"))
	var sever := card("blood_sever")
	g.players[0].hand.append(sever)
	var labels: PackedStringArray = []
	for action in g.legal_actions(0):
		if str(action.get("card_id", "")) == sever.id:
			labels.append(str(action.get("label", "")))
	check(labels.size() == 2, "sever offers base and paid branch")
	check(labels[0].contains("基础") and not labels[0].contains("支付"), "unpaid sever is labeled base")
	check(labels[1].contains("共鸣") and labels[1].contains("支付1真血"), "paid sever names the resonance cost")
	check(g.submit(0, {"type":"effect", "card_id":sever.id, "target_slot":1}).is_empty(), "base sever plays")
	check(g.pending.get("kind") == "buffer", "unpaid sever stays bufferable")
	select(g, [])
	check(g.players[1].hp == 10 and g.players[0].hp == 12, "base sever deals 2")
	g = game()
	g.players[0].main = card("blood_blade")
	g.players[0].sub = card("blood_chalice")
	g.players[0].buffer.append(card("blood_pact"))
	g.players[1].hand.append(card("neutral_sword"))
	sever = card("blood_sever")
	g.players[0].hand.append(sever)
	check(g.resonance(0, "血契") == 2, "three blood names are deep")
	check(g.submit(0, {"type":"effect", "card_id":sever.id, "target_slot":1, "options":{"enhanced":true}}).is_empty(), "deep sever pays")
	check(g.pending.is_empty() and g.players[1].hp == 9 and g.players[0].hp == 11, "deep paid sever is 3 unbufferable")
	g = game()
	g.players[0].main = card("grave_lamp")
	g.players[0].sub = card("grave_casket")
	g.discard.append(card("grave_rite"))
	var spike := card("grave_spike")
	g.players[0].hand.append(spike)
	g.players[1].hand.append(card("neutral_sword"))
	check(g.submit(0, {"type":"effect", "card_id":spike.id, "target_slot":1, "options":{"enhanced":true}}).is_empty(), "spike burial starts")
	select(g, g.pending.cards.slice(0, 1))
	check(g.pending.get("kind") == "buffer", "buried spike damage can be buffered")
	select(g, [])
	check(g.players[1].hp == 9, "buried spike deals 3")
	g = game()
	var pact := card("blood_pact")
	g.players[0].hand.append(pact)
	var paid := false
	for action in g.legal_actions(0):
		if str(action.get("card_id", "")) == pact.id and bool(action.get("options", {}).get("enhanced", false)):
			paid = str(action.get("label", "")).contains("支付1真血")
	check(paid and g.resonance(0, "血契") == 0, "pact can pay without resonance")
	g = game()
	g.players[0].main = card("forge_hammer")
	g.players[0].sub = card("forge_blade")
	var temper := card("forge_temper")
	g.players[0].hand.append(temper)
	var offered := 0
	for action in g.legal_actions(0):
		if str(action.get("card_id", "")) == temper.id:
			offered += 1
			check(str(action.get("label", "")).contains("共鸣") and not bool(action.get("options", {}).get("enhanced", false)), "temper resonance is automatic")
	check(offered == 1, "temper has no extra-cost button")
	check(g.submit(0, {"type":"effect", "card_id":temper.id, "target_slot":0}).is_empty(), "temper plays")
	var temper_mod: Dictionary = g.players[0].attack_mods["forge_temper"]
	check(int(temper_mod.get("atk", 0)) == 2, "resonating temper is +2")

func free_star_prepare() -> void:
	var g := game()
	var p: Dictionary = g.players[0]
	p.main = card("star_instrument")
	p.hand.append(card("star_finale"))
	p.cost = 0
	check(g.prepare_cost(0) == 1, "instrument without resonance keeps prepare cost 1")
	check(not g.validate_action(0, {"type":"prepare"}).is_empty(), "unresonant prepare requires cost")
	p.buffer.append(card("star_gaze"))
	check(g.prepare_cost(0) == 0, "resonant instrument makes prepare free")
	check(not g.validate_action(0, {"type":"prepare"}).is_empty(), "free prepare still banned in round 1")
	g.round_number = 2
	p.attack_used = true
	check(g.validate_action(0, {"type":"prepare"}).is_empty(), "free prepare allowed with no cost")
	check(AiController.new().choose_rules_action(g, 0).type == "prepare", "AI uses free prepare with no cost")
	check(g.submit(0, {"type":"prepare", "card_id":p.hand[0].id}).is_empty(), "free prepare submitted")
	check(p.cost == 0, "free prepare does not deduct cost")
	check(g.pending.cards.size() == 3, "duel free prepare inspects 3, no instrument bonus")
	select(g, g.pending.cards.slice(0, 1))
	drain(g)
	check(p.hand.size() == 1, "free prepare still replaces one hand card")
	check(not g.validate_action(0, {"type":"prepare"}).is_empty(), "free prepare still once per turn")
	p.cost = 3
	check(not g.validate_action(0, {"type":"draw_two"}).is_empty(), "free prepare excludes draw two")
	p.prepared = false
	p.buffer.clear()
	check(g.prepare_cost(0) == 1, "lost resonance restores prepare cost")
	p.main = card("star_chart")
	p.sub = card("star_instrument")
	check(g.prepare_cost(0) == 1, "instrument in sub slot does not make prepare free")
	p.main = card("star_instrument")
	p.sub = card("star_chart")
	check(g.prepare_cost(0) == 0, "different named star sub equipment grants free prepare")
	check(g.submit(0, {"type":"draw_two"}).is_empty(), "draw two remains available instead of free prepare")
	drain(g)
	check(p.cost == 2, "public draw two still costs 1")
	check(not g.validate_action(0, {"type":"prepare"}).is_empty(), "draw two excludes free prepare")
	p.prepared = false
	p.hand.clear()
	check(not g.validate_action(0, {"type":"prepare"}).is_empty(), "free prepare still needs discard")
	p.hand.append(card("star_finale"))
	g.deck.clear()
	check(not g.validate_action(0, {"type":"prepare"}).is_empty(), "free prepare still needs deck")
	g.dispose()

func prepare_sizes() -> void:
	for count in [2, 3, 4]:
		for free in [false, true]:
			var g := CardRules.new()
			g.start(count, 82)
			g.dispose()
			g.current = 0
			g.round_number = 2
			var p: Dictionary = g.players[0]
			p.hand.assign([card("neutral_sword")])
			p.main = card("star_instrument") if free else {}
			p.sub = card("star_chart") if free else {}
			p.buffer.clear()
			p.prepared = false
			p.cost = 0 if free else 1
			var expected := 3 if count == 2 else 4
			var before := g.deck.size()
			check(g.prepare_count() == expected, "prepare count for %d players" % count)
			check(g.submit(0, {"type":"prepare", "card_id":p.hand[0].id}).is_empty(), "prepare with %d players free=%s" % [count, free])
			check(g.pending.cards.size() == expected, "inspection size for %d players free=%s" % [count, free])
			check(p.cost == 0, "prepare costs correctly for %d players free=%s" % [count, free])
			select(g, g.pending.cards.slice(0, 1))
			drain(g)
			check(p.hand.size() == 1 and g.deck.size() == before - 1, "prepare takes one and returns remainder")
			g.dispose()

func dogpile_sources() -> void:
	var g := CardRules.new()
	g.start(4, 82)
	g.dispose()
	for p in g.players:
		p.hand.clear()
		p.buffer.clear()
		p.main = {}
		p.sub = {}
	g.damage(g._context(0, 1, {}), 1, 0)
	check(g.players[1].damaged_by.is_empty(), "zero base damage does not record source")
	g.players[1].res_once = 2
	g.damage(g._context(2, 1, {}), 1, 2)
	check(g.players[1].damaged_by.is_empty(), "RES blocked damage does not record source")
	var blocked := g._context(3, 1, {})
	blocked.reduction = 3
	g.damage(blocked, 1, 3)
	check(g.players[1].damaged_by.is_empty(), "counter blocked damage does not record source")
	check(g.players[1].hp == 12, "fully blocked sources deal no damage")
	g.damage(g._context(0, 1, {}), 1, 3)
	check(g.players[1].hp == 9, "first effective source deals full damage after blocked hits")
	g.damage(g._context(2, 1, {}), 1, 3)
	check(g.players[1].hp == 7, "second effective source reduced by 1")
	g.damage(g._context(3, 1, {}), 1, 3)
	check(g.players[1].hp == 6, "third effective source reduced by 2")
	g.damage(g._context(0, 1, {}), 1, 2)
	check(g.players[1].hp == 4, "first source keeps full damage after other sources join")
	g.damage(g._context(2, 1, {}), 1, 3)
	check(g.players[1].hp == 2, "second source keeps reduction 1 after third source joins")
	g.damage(g._context(3, 1, {}), 1, 3)
	check(g.players[1].hp == 1, "third source keeps reduction 2")
	check(g.players[1].damaged_by == [0, 2, 3], "sources retain first effective hit order")
	g._begin_turn(1)
	check(g.players[1].damaged_by.is_empty(), "own turn resets source ranks")
	g.dispose()
	g = game()
	var buffer_card := card("neutral_sword")
	g.players[1].hand.append(buffer_card)
	g.damage(g._context(0, 1, {}), 1, 1)
	select(g, [buffer_card])
	check(g.players[1].hp == 12 and g.players[1].damaged_by == [0], "buffered effective damage still records source")
	g.dispose()

func run() -> void:
	check(CardDatabase.CARDS.size() == 54, "54 card types")
	for count in [2, 3, 4]:
		var built := CardDatabase.build_shared_deck(count, 29)
		check(built.size() == {2:54, 3:70, 4:102}[count], "pool count %d" % count)
		check(CardDatabase.choose_factions(count, 29).size() == {2:3, 3:4, 4:6}[count], "faction count %d" % count)
		var ids: Dictionary = {}
		var copies: Dictionary = {}
		for c in built:
			ids[c.id] = true
			var base_key := str(c.base_id)
			copies[base_key] = int(copies.get(base_key, 0)) + 1
		var seen_names: Dictionary = {}
		for card in built:
			var seen_key := str(card.base_id)
			if seen_names.has(seen_key):
				continue
			seen_names[seen_key] = true
			var amount := int(copies[seen_key])
			if str(card.get("faction", "")).is_empty():
				check(amount == 1, "neutral stays one " + seen_key)
			else:
				check(amount == 2, "faction card duplicated " + seen_key)
		check(ids.size() == built.size(), "unique instances")
		check(built == CardDatabase.build_shared_deck(count, 29), "deterministic pool")
	var g := game()
	g.players[0].main = card("forge_hammer")
	g.players[0].sub = card("forge_hammer")
	check(g.resonance(0, "铸锋") == 0, "main same name excluded")
	g.players[0].buffer.append(card("forge_temper"))
	check(g.resonance(0, "铸锋") == 1, "normal resonance")
	g.players[0].buffer.append(card("forge_temper"))
	check(g.resonance(0, "铸锋") == 1, "duplicates do not deepen")
	g.players[0].buffer.append(card("forge_wedge"))
	check(g.resonance(0, "铸锋") == 2, "deep resonance")
	var forged := card("forge_blade")
	g.players[0].hand.append(forged)
	check(g.submit(0, {"type":"equip", "card_id":forged.id, "equipment_slot":"main"}).is_empty(), "equip")
	check(g.discard.size() == 1 and g.players[0].hand.is_empty(), "replaced equipment discarded")
	play(g, "forge_temper", 0)
	check(g.submit(0, {"type":"attack", "target_slot":1}).is_empty(), "forged combo attacks")
	check(g.players[1].hp == 7, "blade1 + equip resonance2 + temper2 deals5")
	g = game()
	g.players[0].main = card("forge_blade")
	check(g.submit(0, {"type":"attack", "target_slot":1}).is_empty(), "base blade attacks")
	check(g.players[1].hp == 11, "base blade deals1 without resonance")
	g = game()
	var focus := card("echo_focus")
	g.players[0].hand.append(focus)
	g.players[0].cost = 1
	check(g.submit(0, {"type":"equip", "card_id":focus.id, "equipment_slot":"main"}).is_empty(), "focus equips with1 cost")
	check(g.players[0].cost == 0 and g.players[0].main.id == focus.id, "focus spends1 and enters main")
	g = game()
	var invalid := card("blood_finale")
	g.players[0].hand.append(invalid)
	var before := g.players.duplicate(true)
	check(not g.submit(0, {"type":"effect", "card_id":invalid.id, "target_slot":1, "options":{"enhanced":true}}).is_empty(), "reject no resonance enhanced")
	check(g.players == before, "invalid request does not mutate")
	g = game()
	g.players[0].main = card("echo_focus")
	g.players[0].buffer.append(card("echo_return"))
	g.players[0].buffer.append(card("echo_record"))
	g.players[0].hp = 8
	g.players[1].hand.append(card("neutral_sword"))
	play(g, "echo_finale")
	select(g, g.pending.cards.duplicate())
	check(g.pending.get("kind") == "buffer" and g.players[0].hp == 8, "echo finale waits for damage before healing")
	check(g.resolving.size() == 1 and g.resonance(0, "回响") == 0, "source stays resolving; components gone")
	select(g)
	check(g.players[1].hp == 8 and g.players[0].hp == 9, "locked deep echo 4 damage plus1; no lost resonance equip trigger")
	check(g.resolving.is_empty(), "source finalized")
	g = game()
	for i in range(4): g.players[1].buffer.append(card("neutral_sword"))
	var buffer_card := card("neutral_shield")
	g.players[1].hand.append(buffer_card)
	play(g, "forge_wedge")
	select(g, [buffer_card])
	check(g.players[1].buffer.size() == 1 and g.players[1].hp == 11, "4 to5 overflow removes earliest4 loses1")
	g = game()
	g.players[0].main = card("neutral_sword")
	g.players[1].main = card("neutral_shield")
	var counter := card("forge_counter")
	g.players[1].hand.append(counter)
	check(g.submit(0, {"type":"attack", "target_slot":1}).is_empty(), "attack starts")
	check(g.pending.get("kind") == "counter", "attack counter window")
	select(g, [counter])
	check(g.players[1].hp == 12 and g.players[1].cost == 2 and g.players[1].counter_used, "counter removes minimum1 and consumes fee/count")
	check(g.resolving.is_empty(), "counter finalized")
	g.players[1].hand.append(card("echo_counter"))
	play(g, "forge_wedge")
	check(g.pending.get("kind") == "buffer", "no second counter before own turn")
	select(g)
	g.players[0].cost = 1
	check(g.submit(0, {"type":"end_turn"}).is_empty(), "end")
	check(g.players[0].cost == 1 and g.players[1].cost == 3 and not g.players[1].counter_used, "retained fee and own reset to3")
	g = game()
	g.players[1].cost = 0
	g.players[1].hand.append(card("echo_counter"))
	play(g, "forge_wedge")
	check(g.pending.get("kind") == "buffer", "zero fee cannot counter")
	select(g)
	g = game()
	g.players[1].main = card("star_chart")
	g.players[1].sub = card("star_instrument")
	counter = card("star_counter")
	g.players[1].hand.append(counter)
	play(g, "neutral_disarm")
	select(g, [counter])
	drain(g)
	check(not g.players[1].main.is_empty() and g.players[0].cost == 1, "star counter cancels disarm without refund")
	g = game()
	g.players[0].main = card("echo_focus")
	g.players[0].sub = card("echo_amulet")
	g.players[0].buffer.append(card("echo_record"))
	counter = card("echo_counter")
	g.players[1].hand.append(counter)
	g.players[1].hand.append(card("neutral_sword"))
	play(g, "echo_aftershock")
	select(g, [counter])
	check(g.pending.get("slot") == 1 and g.pending.get("kind") == "buffer", "first segment follows counter")
	select(g)
	check(g.pending.get("slot") == 0, "second segment requires component after first damage")
	select(g, g.pending.cards.slice(0, 1))
	check(g.pending.get("kind") == "buffer", "second segment no counter window")
	select(g)
	check(g.players[1].hp == 9, "counter only reduced first of two segments")
	g = game()
	g.players[0].hand.append(card("neutral_sword"))
	var initial: int = g.players[0].hand.size()
	check(not g.submit(0, {"type":"prepare"}).is_empty(), "prepare rejected in round 1")
	g.round_number = 2
	check(g.submit(0, {"type":"prepare"}).is_empty(), "prepare allowed in round 2")
	select(g, g.pending.cards.slice(0, 1))
	select(g, g.pending.cards.slice(0, 1))
	drain(g)
	check(g.players[0].hand.size() == initial and g.players[0].cost == 2, "prepare replaces one card for1")
	check(not g.submit(0, {"type":"prepare"}).is_empty(), "prepare once")
	check(not g.submit(0, {"type":"draw_two"}).is_empty(), "draw_two rejected after prepare")
	g = game()
	var d_initial: int = g.players[0].hand.size()
	check(g.validate_action(0, {"type":"draw_two"}).is_empty(), "draw_two available initially")
	check(g.submit(0, {"type":"draw_two"}).is_empty(), "draw_two success")
	drain(g)
	check(g.players[0].hand.size() == d_initial + 2 and g.players[0].cost == 2, "draw_two draws 2 cards for 1 cost")
	check(not g.submit(0, {"type":"draw_two"}).is_empty(), "draw_two once per turn")
	g.players[0].hand.append(card("neutral_sword"))
	check(not g.submit(0, {"type":"prepare"}).is_empty(), "prepare rejected after draw_two")
	g.submit(0, {"type":"end_turn"})
	drain(g)
	g.submit(1, {"type":"end_turn"})
	drain(g)
	check(g.current == 0, "back to player 0")
	check(g.round_number == 2, "round 2 reached after round 1 end turns")
	check(g.validate_action(0, {"type":"draw_two"}).is_empty(), "draw_two available next turn")
	check(g.validate_action(0, {"type":"prepare"}).is_empty(), "prepare available next turn")
	# Anti-dogpiling damage reduction test in 3-player & 4-player games
	var g3 := CardRules.new()
	g3.start(3, 82)
	for p in g3.players:
		p.hand.clear()
		p.buffer.clear()
		p.main = {}
		p.sub = {}
		p.cost = 3
	var ctx0 := g3._context(0, 1, {})
	g3.damage(ctx0, 1, 2)
	check(g3.players[1].hp == 10, "1st attacker deals full damage")
	check(g3.players[1].damaged_by == [0], "p1 recorded attacker 0")
	var ctx0_again := g3._context(0, 1, {})
	g3.damage(ctx0_again, 1, 2)
	check(g3.players[1].hp == 8, "same attacker deals full damage again")
	check(g3.players[1].damaged_by == [0], "p1 still recorded only attacker 0")
	var ctx2 := g3._context(2, 1, {})
	g3.damage(ctx2, 1, 2)
	check(g3.players[1].hp == 7, "2nd attacker deals damage reduced by 1")
	check(g3.players[1].damaged_by == [0, 2], "p1 recorded attacker 0 and 2")
	g3._begin_turn(1)
	check(g3.players[1].damaged_by.is_empty(), "damaged_by cleared on own turn start")

	var g4 := CardRules.new()
	g4.start(4, 82)
	for p in g4.players:
		p.hand.clear()
		p.buffer.clear()
		p.main = {}
		p.sub = {}
		p.cost = 3
	g4.damage(g4._context(0, 1, {}), 1, 3)
	check(g4.players[1].hp == 9, "g4 1st attacker deals full 3")
	g4.damage(g4._context(2, 1, {}), 1, 3)
	check(g4.players[1].hp == 7, "g4 2nd attacker deals 2 (reduced by 1)")
	g4.damage(g4._context(3, 1, {}), 1, 3)
	check(g4.players[1].hp == 6, "g4 3rd attacker deals 1 (reduced by 2)")

	# 底线机制测试：第 2/3 位对手即使打 1 点伤害，受衰减后也保底保留 1 点伤害，不归零
	var g_floor := CardRules.new()
	g_floor.start(4, 99)
	for p in g_floor.players:
		p.hand.clear()
		p.buffer.clear()
		p.hp = 12
	g_floor.damage(g_floor._context(0, 1, {}), 1, 1)
	check(g_floor.players[1].hp == 11, "g_floor 1st attacker deals 1")
	g_floor.damage(g_floor._context(2, 1, {}), 1, 1)
	check(g_floor.players[1].hp == 10, "g_floor 2nd attacker deals 1 (floor preserved, not 0)")
	g_floor.damage(g_floor._context(3, 1, {}), 1, 1)
	check(g_floor.players[1].hp == 9, "g_floor 3rd attacker deals 1 (floor preserved, not 0)")

	resonance_costs()
	free_star_prepare()
	prepare_sizes()
	dogpile_sources()
	print("CARD_RULES_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

