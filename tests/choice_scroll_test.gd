extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._begin_game(2, 82, false, 0)
	game._match_help.reset()
	game._combat_presenter.reset()
	var rules := game.rules_engine
	rules.dispose()
	rules.current = 0
	rules.players[0].hand.assign([CardDatabase.find_card("hunt_cutoff")])
	rules.players[0].cost = 3
	rules.discard.clear()
	for index in range(40):
		var card: Dictionary = CardDatabase.CARDS[index].duplicate(true)
		card.id = "discard-scroll-%d" % index
		rules.discard.append(card)
	game._sync_from_rules_engine()
	game._combat_presenter.reset()
	assert(game._game_session.submit_for_slot(0, {"type":"effect", "card_id":"hunt_cutoff", "target_slot":1}).is_empty())
	game._combat_presenter.reset()
	await process_frame
	await process_frame
	assert(rules.pending.title.begins_with("断援"))
	var choice = game._choice_panel
	var scroll: ScrollContainer = choice._choice_scroll
	var grid := choice.buttons.get_child(0) as GridContainer
	# Wheel over artwork and descriptive text, in a window with canvas scaling.
	for window_size in [Vector2i(1280, 720), Vector2i(2544, 1422)]:
		root.size = window_size
		await process_frame
		for local_x in [30.0, 180.0]:
			scroll.scroll_vertical = 0
			await process_frame
			var card_button := grid.get_child(1) as Button
			var point := card_button.get_global_transform_with_canvas() * Vector2(local_x, 45)
			_wheel(point, MOUSE_BUTTON_WHEEL_DOWN)
			await process_frame
			assert(scroll.scroll_vertical == 60, "wheel over a card scrolls once instead of being swallowed or doubled")
			assert(choice.selected_card_ids.is_empty(), "scrolling must not select a card")
			_wheel(point, MOUSE_BUTTON_WHEEL_UP)
			await process_frame
			assert(scroll.scroll_vertical == 0)
	# Outside the list, the wheel must not change its position.
	_wheel(choice.footer.get_global_transform_with_canvas() * (choice.footer.size * 0.5), MOUSE_BUTTON_WHEEL_DOWN)
	await process_frame
	assert(scroll.scroll_vertical == 0)
	scroll.ensure_control_visible(grid.get_child(39))
	await process_frame
	var previous_scroll := scroll.scroll_vertical
	var last := grid.get_child(39) as Button
	var point := last.get_global_transform_with_canvas() * (last.size * 0.5)
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	assert(choice.selected_card_ids == ["discard-scroll-39"] and scroll.scroll_vertical == previous_scroll)
	choice._confirm_cards()
	assert(rules.pending.is_empty() and rules.deck[0].id == "discard-scroll-39")
	game.queue_free()
	await process_frame
	print("CHOICE_SCROLL_TEST_OK cutoff=true wheel_art_and_text=true scaled_windows=true select_last=true")
	quit(0)

func _wheel(point: Vector2, button_index: int) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var wheel := InputEventMouseButton.new()
	wheel.position = point
	wheel.button_index = button_index
	wheel.pressed = true
	root.push_input(wheel, true)
	wheel = wheel.duplicate()
	wheel.pressed = false
	root.push_input(wheel, true)
