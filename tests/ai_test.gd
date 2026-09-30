extends SceneTree

## AI 装备、攻击、效果、弃牌与多人轮转；行动由真实 GameSession 提交。
func _init() -> void: call_deferred("_run")

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
	# 三人座位轮转，以及 AI 选择较弱的另一名 AI。
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
	action = ai.choose_rules_action(rules, 1)
	assert(action.type == "attack" and int(action.target_slot) == 2)
	assert(session.submit_for_slot(1, action).is_empty())
	assert(rules.players[2].hp == 4)
	rules.dispose()
	print("AI_TEST_OK equip=true attack=true effect=true recycle=true rotation=true")
	quit(0)
