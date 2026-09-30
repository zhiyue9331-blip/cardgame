extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	var game := scene.instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player_count_selector.select(0)
	game._start_game()
	await process_frame
	assert(game.rules_engine != null)
	assert(game.rules_engine.players.size() == 2)
	assert(game.rules_engine.deck.size() > 0)
	assert(game.current_turn_slot == int(game.rules_engine.get("current")))
	assert(game.hand_zone.cards.size() == game.rules_engine.players[game.local_player_slot].hand.size())
	var actor := int(game.rules_engine.get("current"))
	var actions: Array = game.rules_engine.legal_actions(actor)
	assert(not actions.is_empty())
	var effect: Dictionary = {}
	for action in actions:
		if str(action.get("type", "")) == "effect":
			effect = action
			break
	if not effect.is_empty():
		var submitted := effect.duplicate(true)
		submitted.erase("label")
		var result: String = game.rules_engine.submit(actor, submitted)
		assert(result.is_empty())
		if not game.rules_engine.pending.is_empty():
			assert(game.rules_engine.pending.has("cards") or game.rules_engine.pending.has("options"))
	game._sync_from_rules_engine()
	assert(game.hand_zone.cards.size() == game.hand.size())
	assert(game.current_turn_slot == int(game.rules_engine.get("current")))
	var local := int(game.local_player_slot)
	var self_state: Dictionary = game.rules_engine.players[local]
	self_state.main = {}
	self_state.sub = {}
	self_state.buffer = []
	game._sync_from_rules_engine()
	assert(game.resonance_mark.visible and game.resonance_mark.text.contains("未共鸣"))
	self_state.main = {"id": "main-forge", "name": "锻工锤", "faction": "铸锋", "type": "装备牌"}
	self_state.sub = {"id": "sub-temper", "name": "回火战刃", "faction": "铸锋", "type": "装备牌"}
	game._sync_from_rules_engine()
	assert(game.resonance_mark.text == "●○  铸锋 · 共鸣")
	self_state.buffer = [{"id": "buffer-blade", "name": "淬刃", "faction": "铸锋", "type": "效果牌"}]
	game._sync_from_rules_engine()
	assert(game.resonance_mark.text == "●●  铸锋 · 深度共鸣")
	print("RULES_UI_TEST_OK actions=%d hand=%d pending=%s resonance=%s" % [actions.size(), game.hand.size(), str(not game.rules_engine.pending.is_empty()), game.resonance_mark.text])
	game.queue_free()
	await process_frame
	quit(0)
