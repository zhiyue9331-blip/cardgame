extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._begin_game(2, 82, false, 0)
	game._match_help.reset()
	game._combat_presenter.reset()
	game._combat_presenter.set_audio_enabled(true)
	var rules := game.rules_engine
	rules.dispose()
	rules.current = 0
	rules.round_number = 2
	rules.players[0].hand.assign([CardDatabase.find_card("neutral_sword")])
	rules.players[0].prepared = false
	rules.deck.clear()
	for index in range(9):
		var data := CardDatabase.find_card(["star_gaze", "forge_temper", "echo_record"][index % 3])
		data.id = "presentation-%d" % index
		rules.deck.append(data)
	game._sync_from_rules_engine()
	game._combat_presenter.reset()
	await process_frame
	assert(game._game_session.submit_for_slot(0, {"type":"draw_two"}).is_empty())
	var presenter := game._combat_presenter
	assert(presenter.running and presenter._feedback._mode == "draw")
	assert(presenter._feedback._card_visual is DraggableCard)
	assert(not game.hand_zone.cards[1].visible and not game.hand_zone.cards[2].visible)
	assert(presenter._feedback._audio._streams.has("draw"))
	await _wait_for_presenter(presenter)
	for card in game.hand_zone.cards: assert(card.visible)
	assert(not game.end_turn_button.disabled)

	# 他人实际装备行动必须展示牌面和牌名。
	rules.current = 1
	rules.players[1].hand.assign([CardDatabase.find_card("neutral_shield")])
	rules.players[1].cost = 3
	rules.players[1].prepared = false
	assert(game._game_session.submit_for_slot(1, {"type":"equip", "card_id":"neutral_shield", "equipment_slot":"main"}).is_empty())
	assert(presenter._feedback._mode == "card_play")
	var played := presenter._feedback._card_visual as DraggableCard
	assert(played.card_data.base_id == "neutral_shield" and played.artwork.texture != null)
	assert(presenter._feedback._caption.text.contains(played.card_data.name))
	await create_timer(0.4).timeout
	await _capture("card-play")
	await _wait_for_presenter(presenter)
	assert(game._game_session.submit_for_slot(1, {"type":"draw_two"}).is_empty())
	assert(presenter._feedback._mode == "draw")
	assert(presenter._feedback._card_visual is PanelContainer)
	assert(not presenter._feedback._card_visual is DraggableCard)
	await _wait_for_presenter(presenter)

	# 三选一展示卡图；确认时从旧候选位置飞入手牌。
	rules.current = 0
	rules.players[0].cost = 3
	rules.players[0].prepared = false
	assert(game._game_session.submit_for_slot(0, {"type":"prepare", "card_id":rules.players[0].hand[0].id}).is_empty())
	assert(rules.pending.kind == "prepare_pick" and rules.pending.cards.size() == 3)
	await _wait_for_presenter(presenter)
	await process_frame
	var choice = game._choice_panel
	assert(choice.buttons.get_child(0).get_child_count() == 3)
	for button in choice.buttons.get_child(0).get_children():
		var preview := button.get_child(0).get_child(0) as CardThumbnail
		assert(preview.artwork.texture != null)
		assert(preview.cost_label.text == str(button.get_meta("card_data").cost))
		assert(not preview.faction_badge.badge_label.text.is_empty())
	var selected_id := str(rules.pending.cards[0].id)
	choice.toggle_card(selected_id)
	await process_frame
	await _capture("prepare-choice")
	var source: Vector2 = choice.card_global_center(selected_id)
	choice._confirm_cards()
	assert(presenter._feedback._mode == "draw")
	assert(presenter._feedback._source.is_equal_approx(presenter._feedback.get_global_transform().affine_inverse() * source))
	assert(not game.hand_zone.cards.back().visible)
	await _wait_for_presenter(presenter)
	assert(game.hand_zone.cards.back().visible)
	choice.render({"slot":1, "kind":"selection", "cards":rules.players[1].hand}, [], 0, false)
	assert(not choice.public_inspection.visible)
	presenter.set_audio_enabled(false)
	presenter.enqueue([{"kind":"draw", "target":0, "card":rules.players[0].hand.back()}])
	assert(presenter._feedback._audio._players.is_empty())
	presenter.reset()
	assert(not presenter.running and presenter._feedback._card_visual == null)
	for card in game.hand_zone.cards: assert(card.visible)
	# 普通手牌选择、公开缓冲、装备及弃牌顶部均有卡图、费用和字段。
	var public_cards := [CardDatabase.find_card("forge_blade"), CardDatabase.find_card("star_counter"), CardDatabase.find_card("echo_record")]
	choice.render({"slot":0, "kind":"buffer", "title":"缓冲选择", "cards":public_cards, "min":0, "max":2}, [], 0, false)
	await process_frame
	for button in choice.buttons.get_child(0).get_children():
		var chip := button.get_child(0).get_child(0) as BufferCardChip
		assert(chip.get_node("Content/Artwork").texture != null)
		assert(chip.get_node("Content/CardFields").text.contains(str(chip.card_data.cost) + "费"))
		assert(chip.get_node("Content/CardFields").text.contains(chip.card_data.faction))
	game._board_view.render_buffer(public_cards)
	rules.players[1].main = public_cards[0]
	rules.players[1].buffer.assign(public_cards)
	rules.discard.assign([public_cards[1]])
	game._sync_from_rules_engine()
	presenter.reset()
	choice.render({"slot":0, "kind":"buffer", "title":"缓冲选择", "cards":public_cards, "min":0, "max":2}, [], 0, false)
	await process_frame
	var opponent := game._board_view.opponent_panels[0] as OpponentPanel
	assert(opponent.main_art.texture != null)
	assert(opponent.main_stats.text.contains("铸锋") and opponent.main_stats.text.contains("2费"))
	assert(game.discard_zone.top_art.texture != null and game.discard_zone.top_fields.text.contains("星序"))
	await _capture("public-card-fields")
	choice.reset()
	game._board_view._on_card_hover_changed(game.hand_zone.cards[0], true)
	assert(game._board_view._card_detail_art.texture != null)
	assert(game._board_view._card_detail_label.text.contains(game.hand_zone.cards[0].cost_label.text + "费"))
	print("CARD_PRESENTATION_TEST_OK play_face=true draw_privacy=true prepare_art=3 reset=true")
	game.queue_free()
	await process_frame
	quit(0)

func _wait_for_presenter(presenter: CombatPresenter) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while presenter.running and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not presenter.running)

func _capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/%s.png" % label)
