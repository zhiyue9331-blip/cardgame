extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player_count_selector.select(0)
	game._start_game()
	var rules := game.rules_engine as CardRules
	rules.current = 0
	rules.round_number = 2
	rules.pending.clear()
	rules._queue.clear()
	rules.discard.clear()
	rules.players[0].hand.clear()
	rules.players[0].cost = 1
	rules.players[0].prepared = false
	var effect := CardDatabase.find_card("blood_sever")
	effect.id = "prepare-effect"
	rules.players[0].hand.append(effect)
	var top := CardDatabase.find_card("star_gaze")
	top.id = "prepare-top"
	var middle := CardDatabase.find_card("forge_temper")
	middle.id = "prepare-middle"
	var bottom := CardDatabase.find_card("echo_record")
	bottom.id = "prepare-bottom"
	var fourth := CardDatabase.find_card("grave_rite")
	fourth.id = "prepare-fourth"
	rules.deck.assign([fourth, bottom, middle, top])
	game._sync_from_rules_engine()
	game._combat_presenter.reset()
	await process_frame
	var card_node: DraggableCard = game.hand_zone.cards[0]
	assert(card_node.card_data.id == effect.id and int(effect.cost) > int(rules.players[0].cost))
	card_node.has_dragged = true
	game._on_card_dropped(card_node, game.prepare_zone.get_global_rect().get_center())
	assert(rules.players[0].prepared and int(rules.players[0].cost) == 0)
	assert(rules.players[0].hand.is_empty() and rules.discard.back().id == effect.id)
	assert(rules.players[1].hp == 12 and rules.pending.title.contains("检视"))
	assert(game.rules_choice_panel.visible)
	assert(game._rules_submit({"type":"choose", "card_ids":[top.id], "option":""}).is_empty())
	assert(game._rules_submit({"type":"choose", "card_ids":[middle.id, bottom.id, fourth.id], "option":""}).is_empty())
	assert(rules.players[0].hand.size() == 1 and rules.players[0].hand[0].id == top.id)
	assert(rules.deck.size() == 3 and rules.deck.back().id == middle.id)
	assert(not rules.validate_action(0, {"type":"prepare", "card_id":top.id}).is_empty())
	print("PREPARE_DROP_TEST_OK effect_discarded=true cost=0 inspected=4")
	game.queue_free()
	await process_frame
	quit(0)
