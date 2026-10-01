extends SceneTree

## 双端真实 ENet：越权拒绝、装备/伤害/缓冲、共享洗回、淘汰和重复广播。
var games: Array[GameController] = []

func _init() -> void: call_deferred("_run")

func _wait_until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await process_frame
	return false

func _assert_synced() -> void:
	var a := games[0].rules_engine
	var b := games[1].rules_engine
	assert(a.players == b.players and a.deck == b.deck and a.discard == b.discard)
	assert(a.pending == b.pending and a.resolving == b.resolving)
	assert(a.current == b.current and a.winner == b.winner)
	assert(a.round_start_slot == b.round_start_slot and a.round_number == b.round_number)

func _send(slot: int, action: Dictionary) -> void:
	var sequence := games[0]._game_session.last_sequence + 1
	games[slot]._rules_submit(action)
	assert(await _wait_until(func(): return games[0]._game_session.last_sequence == sequence and games[1]._game_session.last_sequence == sequence))
	_assert_synced()
	for game in games: game._combat_presenter.reset()

func _run() -> void:
	var containers: Array[Node] = []
	for title in ["Server", "Client"]:
		var container := Node.new()
		container.name = title
		root.add_child(container)
		containers.append(container)
		set_multiplayer(SceneMultiplayer.new(), container.get_path())
		var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
		container.add_child(game)
		game.set_process(false)
		games.append(game)
	await process_frame
	var host := games[0]
	var client := games[1]
	assert(host.network_session.host_room(37463, "房主", 2) == OK)
	assert(client.network_session.join_room("127.0.0.1", 37463, "客人") == OK)
	assert(await _wait_until(func(): return host.network_session.players.size() == 2))
	assert(host.network_session.host_start_game())
	assert(await _wait_until(func(): return host.online_game and client.online_game))
	_assert_synced()
	assert(host.local_player_slot == 0 and client.local_player_slot == 1)
	assert(host.hand.size() == 5 and client.hand.size() == 5)
	assert(host.rules_engine.deck.size() == 44)
	assert(host.opponents[0].name == "客人" and client.opponents[0].name == "房主")
	# 给两端同一测试牌局；之后所有变化必须经过网络行动。
	for game in games:
		var rules := game.rules_engine
		rules.current = 1
		rules.players[0].hand.assign([CardDatabase.find_card("neutral_aid"), CardDatabase.find_card("neutral_meditate"), CardDatabase.find_card("blood_heal")])
		rules.players[0].main = CardDatabase.find_card("neutral_shield")
		rules.players[1].hand.assign([CardDatabase.find_card("neutral_sword"), CardDatabase.find_card("blood_sever"), CardDatabase.find_card("neutral_meditate")])
		game._sync_from_rules_engine()
		game._combat_presenter.reset()
	var rejected: Array[bool] = [false]
	host.network_session.status_changed.connect(func(_message: String, error: bool):
		if error: rejected[0] = true)
	host._rules_submit({"type":"end_turn"})
	assert(await _wait_until(func(): return rejected[0]))
	assert(host.current_turn_slot == 1 and host._game_session.last_sequence == 0)
	await _send(1, {"type":"equip", "card_id":"neutral_sword", "equipment_slot":"main"})
	assert(client.rules_engine.players[1].main.base_id == "neutral_sword")
	await _send(1, {"type":"attack", "target_slot":0})
	assert(host.rules_engine.pending.kind == "buffer" and host.rules_engine.pending.slot == 0)
	assert(host.rules_choice_panel.visible and host.rules_engine.players[1].attack_used)
	await _send(0, {"type":"choose", "card_ids":["neutral_aid"], "option":""})
	assert(host.rules_engine.players[0].buffer[0].id == "neutral_aid")
	assert(host.rules_engine.players[0].hp == 12)
	await _send(1, {"type":"effect", "card_id":"blood_sever", "target_slot":0})
	await _send(0, {"type":"choose", "card_ids":[], "option":""})
	assert(host.rules_engine.players[0].hp == 10)
	assert(host.rules_engine.discard.back().base_id == "blood_sever")
	await _send(1, {"type":"swap_equipment"})
	assert(client.rules_engine.players[1].main.is_empty() and client.rules_engine.players[1].sub.base_id == "neutral_sword")
	# 公共洗回：先问对手，最后问抽牌者，继续抽牌且只洗回一次。
	for game in games:
		game.rules_engine.deck.clear()
		game.rules_engine.discard.clear()
		for index in range(3):
			var card := CardDatabase.find_card("neutral_shield")
			card.id = "recycle-%d" % index
			game.rules_engine.discard.append(card)
	await _send(1, {"type":"end_turn"})
	assert(host.rules_engine.pending.slot == 1)
	rejected[0] = false
	var sequence := host._game_session.last_sequence
	host._rules_submit({"type":"choose", "card_ids":[host.hand[0].id], "option":""})
	assert(await _wait_until(func(): return rejected[0]))
	assert(host._game_session.last_sequence == sequence)
	await _send(1, {"type":"choose", "card_ids":[client.hand[0].id], "option":""})
	assert(host.rules_engine.pending.slot == 0)
	await _send(0, {"type":"choose", "card_ids":[host.hand[0].id], "option":""})
	assert(host.rules_engine.pending.is_empty() and host.rules_engine.discard.is_empty())
	assert(host.rules_engine.deck.size() == 3 and host.current_turn_slot == 0)
	# 真血归零时，手牌/缓冲/装备进入同一公共弃牌区，双端胜负一致。
	for game in games:
		var rules := game.rules_engine
		rules.players[0].main = CardDatabase.find_card("neutral_sword")
		rules.players[0].main.attack = 10
		rules.players[1].hp = 1
		rules.players[1].hand.assign([CardDatabase.find_card("neutral_aid")])
		game._sync_from_rules_engine()
		game._combat_presenter.reset()
	var loser: Dictionary = client.rules_engine.players[1]
	var lost_cards: int = loser.hand.size() + loser.buffer.size() + 1
	var before := host.rules_engine.discard.size()
	await _send(0, {"type":"attack", "target_slot":1})
	await _send(1, {"type":"choose", "card_ids":[], "option":""})
	assert(host.game_over and client.game_over and host.rules_engine.winner == 0)
	assert(loser.hand.is_empty() and loser.buffer.is_empty() and loser.sub.is_empty())
	assert(host.rules_engine.discard.size() == before + lost_cards)
	var snapshot := client.rules_engine.players.duplicate(true)
	client._game_session.replay({"type":"end_turn", "actor_slot":0, "sequence":client._game_session.last_sequence})
	assert(client.rules_engine.players == snapshot)
	client.network_session.close_room(false)
	host.network_session.close_room(false)
	for container in containers: container.queue_free()
	await process_frame
	print("ONLINE_GAME_TEST_OK rejection=true buffer=true recycle=true elimination=true replay=true")
	quit(0)
