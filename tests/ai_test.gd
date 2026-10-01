extends SceneTree

## AI 装备、攻击、效果、弃牌与多人轮转；行动由真实 GameSession 提交。
func _init() -> void: call_deferred("_run")

func _star_game(main_id: String) -> CardRules:
	var g := CardRules.new()
	g.start(2, 82)
	g.dispose()
	g.current = 0
	g.round_number = 2
	for p in g.players:
		p.hand.clear()
		p.buffer.clear()
		p.main = {}
		p.sub = {}
		p.cost = 3
	g.players[0].main = CardDatabase.find_card(main_id)
	g.players[0].sub = CardDatabase.find_card("star_chart" if main_id == "star_instrument" else "star_instrument")
	return g

func _finish_choices(g: CardRules, ai: AiController) -> void:
	for step in range(20):
		if g.pending.is_empty(): return
		var slot := int(g.pending.slot)
		assert(g.submit(slot, ai.choose_rules_action(g, slot)).is_empty())
	assert(g.pending.is_empty())

func _star_choices(ai: AiController) -> void:
	var g := _star_game("star_instrument")
	var finale_a := CardDatabase.find_card("star_finale")
	finale_a.id = "finale-a"
	var finale_b: Dictionary = finale_a.duplicate(true)
	finale_b.id = "finale-b"
	var gaze := CardDatabase.find_card("star_gaze")
	g.deck.assign([gaze, finale_b, finale_a])
	g.players[0].hand.assign([CardDatabase.find_card("star_fall")])
	assert(g.submit(0, {"type":"effect", "card_id":"star_fall", "target_slot":1}).is_empty())
	var choice := ai.choose_rules_action(g, 0)
	assert(choice.card_ids.size() == 2)
	assert(g.find(g.pending.cards, choice.card_ids[0]).name != g.find(g.pending.cards, choice.card_ids[1]).name)
	assert(g.submit(0, choice).is_empty())
	_finish_choices(g, ai)
	assert(g.players[1].hp == 8)
	g.dispose()
	g = _star_game("star_instrument")
	g.deck.assign([CardDatabase.find_card("forge_finale"), CardDatabase.find_card("blood_finale"), CardDatabase.find_card("star_prophecy")])
	g.players[0].hand.assign([CardDatabase.find_card("star_finale")])
	assert(g.submit(0, {"type":"effect", "card_id":"star_finale", "target_slot":0}).is_empty())
	choice = ai.choose_rules_action(g, 0)
	assert(choice.card_ids.size() == 2)
	assert(choice.card_ids.has("star_prophecy"))
	assert(g.submit(0, choice).is_empty())
	_finish_choices(g, ai)
	assert(g.players[0].hand.size() == 2)
	g.dispose()
	for weapon in ["star_chart", "star_instrument"]:
		g = _star_game(weapon)
		# 异系终结与星序低费牌同评分，异系牌先出现时也应先拿星序。
		g.deck.assign([CardDatabase.find_card("star_prophecy"), CardDatabase.find_card("forge_finale")])
		g.players[0].hand.assign([CardDatabase.find_card("star_intercept")])
		assert(g.submit(0, {"type":"effect", "card_id":"star_intercept", "target_slot":0}).is_empty())
		choice = ai.choose_rules_action(g, 0)
		assert(choice.card_ids == ["star_prophecy"])
		assert(g.submit(0, choice).is_empty())
		_finish_choices(g, ai)
		assert(g.players[0].hand.size() == 2)
		assert(g.players[0].hand.any(func(c: Dictionary): return c.base_id == "star_prophecy"))
		assert(g.players[0].hand.any(func(c: Dictionary): return c.base_id == "forge_finale"))
		g.dispose()
	g = _star_game("star_instrument")
	g.deck.assign([CardDatabase.find_card("star_prophecy"), CardDatabase.find_card("forge_finale")])
	g.players[0].hand.assign([CardDatabase.find_card("star_prophecy")])
	assert(g.submit(0, {"type":"effect", "card_id":"star_prophecy", "target_slot":0}).is_empty())
	choice = ai.choose_rules_action(g, 0)
	assert(choice.card_ids == ["forge_finale"])
	_finish_choices(g, ai)
	g.dispose()
	# AI 对已经出现的来源使用固定档位，而非来源总人数。
	g = _star_game("star_chart")
	g.players[1].damaged_by = [0, 2, 3]
	var action := {"type":"effect", "target_slot":1}
	var prediction := ai._rules_damage_estimate(g, 0, action, CardDatabase.find_card("grave_spike"))
	assert(int(prediction.amount) == 2)
	g.dispose()

func _run() -> void:
	var rules := CardRules.new()
	var session := GameSession.new()
	session.setup(rules, null)
	session.start(2, 42, false, 0)
	var ai := AiController.new()
	rules.current = 0
	for player in rules.players: player.hand.clear()
	assert(session.submit_for_slot(0, {"type":"end_turn"}).is_empty())
	assert(rules.current == 1)
	var player: Dictionary = rules.players[1]
	player.hand.assign([CardDatabase.find_card("neutral_sword")])
	var action := ai.choose_rules_action(rules, 1)
	assert(action.type == "equip" and action.equipment_slot == "main")
	assert(session.submit_for_slot(1, action).is_empty())
	assert(player.main.base_id == "neutral_sword" and player.hand.is_empty())
	# A main slot is required before ordinary effects or a sub equipment.
	rules.current = 0
	rules.players[0].main = {}
	rules.players[0].sub = {}
	rules.players[0].cost = 3
	rules.players[0].hand.assign([CardDatabase.find_card("neutral_sword"), CardDatabase.find_card("blood_pact")])
	var main_priority := ai.choose_rules_action(rules, 0)
	assert(main_priority.type == "equip" and main_priority.equipment_slot == "main")
	rules.players[0].hand.clear()
	rules.current = 1
	action = ai.choose_rules_action(rules, 1)
	assert(action.type == "attack" and int(action.target_slot) == 0)
	assert(session.submit_for_slot(1, action).is_empty())
	assert(rules.players[0].hp == 11 and player.attack_used)
	# 攻击已用、费用为零且没有手牌，应结束回合。
	player.cost = 0
	action = ai.choose_rules_action(rules, 1)
	assert(action.type == "end_turn")
	assert(session.submit_for_slot(1, action).is_empty())
	assert(rules.current == 0 and rules.round_number == 2 and rules.players[0].cost == 3)
	# 足够费用时会打效果牌，分支与实际扣血交给规则引擎。
	rules.current = 1
	rules.players[0].hand.clear()
	player.cost = 3
	player.hand.assign([CardDatabase.find_card("blood_pact")])
	action = ai.choose_rules_action(rules, 1)
	assert(action.type == "effect")
	assert(session.submit_for_slot(1, action).is_empty())
	assert(rules.players[0].hp < 11 and player.cost < 3)
	# 洗回待选丢弃低价值牌，保留终结组件。
	player.hand.assign([CardDatabase.find_card("forge_finale"), CardDatabase.find_card("blood_pact")])
	rules.choose(1, "公共洗牌：弃1张手牌", player.hand, 1, 1, func(cards: Array, _option: String): rules.discard.append(rules.take(player.hand, str(cards[0].id))))
	action = ai.choose_rules_action(rules, 1)
	assert(action.card_ids == ["blood_pact"])
	assert(session.submit_for_slot(1, action).is_empty())
	assert(player.hand.size() == 1 and player.hand[0].base_id == "forge_finale")
	# 三人座位轮转，以及 AI 选择已成型的另一名 AI。
	session.start(3, 42, false, 0)
	rules.current = 0
	for p in rules.players: p.hand.clear()
	for slot in range(3):
		assert(session.submit_for_slot(slot, {"type":"end_turn"}).is_empty())
		assert(rules.current == (slot + 1) % 3)
	assert(rules.round_number == 2)
	rules.current = 1
	for p in rules.players: p.hand.clear()
	rules.players[1].main = CardDatabase.find_card("neutral_sword")
	rules.players[2].hp = 5
	rules.players[2].main = CardDatabase.find_card("forge_blade")
	rules.players[2].sub = CardDatabase.find_card("forge_hammer")
	action = ai.choose_rules_action(rules, 1)
	assert(action.type == "attack" and int(action.target_slot) == 2)
	assert(session.submit_for_slot(1, action).is_empty())
	assert(rules.players[2].hp == 4)

	# 确定能击杀时优先补刀，不盲目追打高威胁目标。
	rules.players[1].attack_used = false
	rules.players[0].hp = 1
	rules.players[0].cost = 0
	action = ai.choose_rules_action(rules, 1)
	assert(action.type == "attack" and int(action.target_slot) == 0)
	# 效果牌使用相同目标评分，不再默认较小座位。
	rules.players[0].hp = 12
	rules.players[1].main = {}
	rules.players[1].sub = {}
	rules.players[1].hand.assign([CardDatabase.find_card("grave_spike")])
	action = ai.choose_rules_action(rules, 1)
	assert(action.type == "effect" and int(action.target_slot) == 2)
	assert(session.submit_for_slot(1, action).is_empty())
	assert(rules.players[2].hp == 2)
	# 目标同样强时按回合轮换，避免长期偏向固定座位。
	for p in rules.players:
		p.hp = 12
		p.main = {}
		p.sub = {}
		p.hand.clear()
		p.damaged_by.clear()
	rules.players[1].main = CardDatabase.find_card("neutral_sword")
	rules.players[1].attack_used = false
	rules.round_number = 2
	var first_target: int = ai.choose_rules_action(rules, 1).target_slot
	rules.round_number = 3
	var next_target: int = ai.choose_rules_action(rules, 1).target_slot
	assert(first_target != next_target)
	# 有反击牌也能花最后费用斩杀，不因硬性留费错过终结。
	rules.players[1].main = CardDatabase.find_card("grave_lamp")
	rules.players[1].hand.assign([CardDatabase.find_card("grave_spike"), CardDatabase.find_card("grave_counter")])
	rules.players[1].cost = 2
	rules.players[1].attack_used = true
	rules.players[0].hp = 2
	rules.players[0].cost = 0
	rules.players[2].cost = 0
	action = ai.choose_rules_action(rules, 1)
	assert(action.type == "effect" and int(action.target_slot) == 0)
	assert(session.submit_for_slot(1, action).is_empty())
	assert(not rules.alive(0) and rules.players[1].cost == 0)
	rules.dispose()
	_tactical_priority_choices(ai)
	_scheme_choices(ai)
	_star_choices(ai)
	_hunt_choices(ai)
	print("AI_TEST_OK equip=true attack=true effect=true recycle=true rotation=true")
	quit(0)


func _tactical_priority_choices(ai: AiController) -> void:
	# When the formal estimator shows that Temper changes the next attack's
	# actual damage, the free attack must wait for the buff.
	var g := CardRules.new()
	g.start(2, 82)
	g.dispose()


	g.current = 0
	g.round_number = 2
	for p in g.players:
		p.hand.clear()
		p.buffer.clear()
		p.main = {}
		p.sub = {}
		p.cost = 3
	g.players[0].main = CardDatabase.find_card("forge_blade")
	g.players[0].sub = CardDatabase.find_card("forge_hammer")
	g.players[0].equipped_forge = true
	g.players[0].hand.assign([CardDatabase.find_card("forge_temper")])
	g.players[1].main = CardDatabase.find_card("neutral_shield")
	var player_before: Dictionary = g.players[0].duplicate(true)
	var action := ai.choose_rules_action(g, 0)
	assert(action.type == "effect" and action.card_id == "forge_temper")
	assert(g.players[0] == player_before)
	g.dispose()

	# Reforge has no useful immediate target when no铸锋 equipment can follow it.
	g = CardRules.new()
	g.start(2, 83)
	g.dispose()
	g.current = 0
	g.round_number = 2
	for p in g.players:
		p.hand.clear()
		p.buffer.clear()
		p.main = {}
		p.sub = {}
		p.cost = 3
	g.players[0].main = CardDatabase.find_card("forge_hammer")
	g.players[0].hand.assign([CardDatabase.find_card("forge_reforge")])
	g.players[1].main = {}
	action = ai.choose_rules_action(g, 0)
	assert(action.type != "effect" or action.card_id != "forge_reforge")
	g.dispose()

	# A non-resonant 3-fee search should yield to the 1-fee draw-two action.
	g = CardRules.new()
	g.start(2, 84)
	g.dispose()
	g.current = 0
	g.round_number = 2
	for p in g.players:
		p.hand.clear()
		p.buffer.clear()
		p.main = {}
		p.sub = {}
		p.cost = 3
	g.players[0].main = CardDatabase.find_card("star_chart")
	g.players[0].attack_used = true
	g.players[0].hand.assign([CardDatabase.find_card("star_finale")])
	g.players[1].main = CardDatabase.find_card("neutral_sword")
	action = ai.choose_rules_action(g, 0)
	assert(action.type == "draw_two")
	g.dispose()


func _scheme_game(count: int = 2) -> CardRules:
	var g := CardRules.new()
	g.start(count, 90 + count)
	g.dispose()
	g.current = 0
	g.round_number = 2
	for p in g.players:
		p.hand.clear()
		p.buffer.clear()
		p.main = {}
		p.sub = {}
		p.plan = {}
		p.plan_used = false
		p.turn_count = 1
		p.plan_due = 0
		p.cost = 3
		p.attack_used = true
	g.players[0].main = CardDatabase.find_card("scheme_hourglass")
	g.players[0].sub = CardDatabase.find_card("scheme_lamp")
	for slot in range(1, count):
		g.players[slot].main = CardDatabase.find_card("neutral_shield")
	return g


func _scheme_choices(ai: AiController) -> void:
	# Delayed damage beats an ordinary cast when there is no immediate lethal,
	# and the public target is selected again from the living opponents.
	var g := _scheme_game(3)
	g.players[0].hand.assign([CardDatabase.find_card("scheme_detonate")])
	g.players[1].hp = 10
	g.players[2].hp = 1
	var action := ai.choose_rules_action(g, 0)
	assert(action.type == "plan" and action.card_id == "scheme_detonate")
	assert(g.submit(0, action).is_empty())
	assert(g.players[0].plan.base_id == "scheme_detonate" and g.players[1].hp == 10)
	g.players[0].turn_count = 2
	g.players[0].plan_due = 2
	g._execute_plan(0)
	assert(g.pending.kind == "plan_target" and g.pending.plan_damage_bonus == 1)
	action = ai.choose_rules_action(g, 0)
	assert(action.type == "choose" and action.card_ids.is_empty() and action.option == "2")
	assert(g.submit(0, action).is_empty())
	assert(g.players[2].hp == 0 and g.players[0].plan.is_empty())
	g.dispose()

	# An immediate kill takes priority over setting up a plan.
	g = _scheme_game()
	g.players[0].main = CardDatabase.find_card("scheme_hourglass")
	g.players[0].sub = CardDatabase.find_card("scheme_lamp")
	g.players[0].attack_used = false
	g.players[0].hand.assign([CardDatabase.find_card("scheme_detonate")])
	g.players[1].main = {}
	g.players[1].hp = 1
	g.players[1].cost = 0
	action = ai.choose_rules_action(g, 0)
	assert(action.type == "effect" and action.card_id == "scheme_detonate" and int(action.target_slot) == 1)
	g.dispose()

	# A lethal immediate effect also beats a stronger delayed plan when no attack is available.
	g = _scheme_game()
	g.players[0].main = CardDatabase.find_card("scheme_lamp")
	g.players[0].sub = CardDatabase.find_card("scheme_hourglass")
	g.players[0].hand.assign([CardDatabase.find_card("scheme_detonate"), CardDatabase.find_card("scheme_counter")])
	g.players[1].main = {}
	g.players[1].hp = 3
	g.players[1].cost = 0
	action = ai.choose_rules_action(g, 0)
	assert(action.type == "effect" and action.card_id == "scheme_detonate" and int(action.target_slot) == 1)
	g.dispose()

	# Scheme counter returns a plan when the actor is in immediate danger.
	g = _scheme_game()
	g.players[0].hp = 3
	g.players[0].plan = CardDatabase.find_card("scheme_detonate")
	g.players[0].plan_due = 2
	g.players[0].hand.assign([CardDatabase.find_card("scheme_counter")])
	g.choose(0, "反击分支：支付额外代价强化，或使用基础减伤", [], 0, 0, func(_cards: Array, option: String):
		if option == "enhanced":
			g.players[0].hand.append(g.players[0].plan)
			g.players[0].plan = {}
	, [{"id":"base", "label":"基础减伤1"}, {"id":"enhanced", "label":"取回计划，减伤3"}], Callable(), "choice")
	action = ai.choose_rules_action(g, 0)
	assert(action.type == "choose" and action.option == "enhanced")
	assert(g.submit(0, action).is_empty())
	assert(g.players[0].plan.is_empty() and g.players[0].hand.any(func(c: Dictionary): return c.base_id == "scheme_detonate"))
	g.dispose()


func _hunt_choices(ai: AiController) -> void:
	var g := CardRules.new()
	g.start(3, 42)
	g.current = 0
	for p in g.players:
		p.main = {}
		p.sub = {}
		p.buffer.clear()
		p.hand.clear()
		p.hp = 12
		p.cost = 3
	g.players[0].main = CardDatabase.find_card("hunt_flag")
	g.players[0].sub = CardDatabase.find_card("hunt_crossbow")
	g.players[0].attack_used = true
	g.players[0].hand.assign([CardDatabase.find_card("hunt_blockade"), CardDatabase.find_card("blood_search")])
	g.players[1].hand.assign([CardDatabase.find_card("neutral_sword"), CardDatabase.find_card("blood_heal")])
	g.players[2].hand.assign([CardDatabase.find_card("neutral_sword")])
	# 同手牌数量时，打出封锁补给后己方少1张，已满足共鸣弃牌条件。
	var action := ai.choose_rules_action(g, 0)
	assert(action.type == "effect" and action.card_id == "hunt_blockade" and int(action.target_slot) == 1)
	assert(g.submit(0, action).is_empty())
	_finish_choices(g, ai)
	assert(g.players[1].draw_penalty and g.players[1].hand.size() == 1)
	g.dispose()
