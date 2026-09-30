extends SceneTree

## 淘汰清场与跳过座位，统一通过 CardRules 结算并刷新界面。
func _init() -> void: call_deferred("_run")

func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._begin_game(4, 123456, false, 0)
	game._combat_presenter.reset()
	var rules := game.rules_engine
	rules.current = 0
	var eliminated: Dictionary = rules.players[1]
	eliminated.buffer.append(eliminated.hand.pop_back())
	eliminated.main = CardDatabase.find_card("neutral_sword")
	var expected: int = eliminated.hand.size() + eliminated.buffer.size() + 1
	var before := rules.discard.size()
	eliminated.hp = 0
	rules.refresh_winner()
	assert(eliminated.hand.is_empty() and eliminated.buffer.is_empty() and eliminated.main.is_empty())
	assert(rules.discard.size() == before + expected)
	assert(game._game_session.submit_for_slot(0, {"type":"end_turn"}).is_empty())
	assert(rules.current == 2 and not game.game_over and game.opponents[0].eliminated)
	rules.players[2].hp = 0
	rules.refresh_winner()
	rules._drain()
	game._sync_from_rules_engine()
	assert(rules.current == 3 and not game.game_over and game.opponents[1].eliminated)
	game.queue_free()
	await process_frame
	print("ELIMINATION_TURN_TEST_OK skipped_slots=1,2 next_slot=3")
	quit(0)
