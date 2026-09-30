extends SceneTree

## 洗回待选由 AiTurnRunner 驱动，即使当前行动者是本地玩家也不能卡住。
func _init() -> void: call_deferred("_run")

func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for drawer in [0, 1]:
		game._begin_game(2, 42, false, 0)
		var rules := game.rules_engine
		rules.current = drawer
		rules.deck.clear()
		rules.discard.assign([CardDatabase.find_card("neutral_aid")])
		var before: int = rules.players[drawer].hand.size()
		rules.add_steps([func(): rules.draw(drawer, 1)])
		rules._drain()
		game._sync_from_rules_engine()
		game._combat_presenter.reset()
		assert(int(rules.pending.slot) == 1 - drawer)
		for choice_index in range(2):
			assert(not rules.pending.is_empty())
			if int(rules.pending.slot) == 0:
				game._rules_submit({"type":"choose", "card_ids":[rules.pending.cards[0].id], "option":""})
			else:
				game._ai_turn_runner.reset()
				game._process(1.0)
		assert(rules.pending.is_empty() and rules.discard.is_empty())
		assert(rules.deck.size() == 2 and rules.players[drawer].hand.size() == before)
	game.queue_free()
	await process_frame
	print("AI_RECYCLE_TEST_OK local_and_ai_draw=true")
	quit(0)
