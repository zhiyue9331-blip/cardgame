extends SceneTree

## 控制器拆分后的边界回归：选择顺序、拖放优先级、AI 节拍和战斗动画代际。

const CHOICE_PANEL_SCRIPT := preload("res://scripts/choice_panel.gd")
const CARD_INTERACTION_SCRIPT := preload("res://scripts/card_interaction.gd")

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
	game.set_process(false)

	# ChoicePanel 保持点击顺序，并把最终选择交给宿主。
	var choice = CHOICE_PANEL_SCRIPT.new()
	game.game_board.add_child(choice)
	choice.setup(game.game_board)
	var submitted: Array[Dictionary] = []
	choice.action_requested.connect(func(action: Dictionary) -> void: submitted.append(action))
	# Keep synthetic choice input isolated from tutorial/presentation overlays.
	game._match_help.reset()
	game._combat_presenter.reset()
	choice.render({"slot": 0, "title": "排序", "kind": "order", "cards": [
		{"id": "first", "name": "第一张", "faction": ""},
		{"id": "second", "name": "第二张", "faction": ""},
	], "min": 2, "max": 2}, [], 0, false)
	var initial_order_grid := choice.buttons.get_child(0) as GridContainer
	assert(initial_order_grid.columns == 2)
	(initial_order_grid.get_child(1) as Button).pressed.emit()
	await process_frame
	(initial_order_grid.get_child(0) as Button).pressed.emit()
	(choice.footer.get_child(1) as Button).pressed.emit()
	assert(submitted.size() == 1)
	assert(submitted[0].card_ids == ["second", "first"])
	# 他人选择无需操作时隐藏弹窗，公开检视牌仍可见。
	choice.render({"slot":1, "title":"缓冲1", "kind":"buffer"}, [], 0, false)
	assert(not choice.panel.visible and not choice.public_inspection.visible)
	choice.render({"slot":1, "title":"检视", "kind":"order"}, [{"name":"星落"}], 0, false)
	assert(not choice.panel.visible and choice.public_inspection.visible)
	assert(choice.public_inspection_text.text.contains("星落"))
	choice.reset()
	assert(not choice.public_inspection.visible)

	# Every ordinary card choice uses the same two-column scroll grid.  Exercise
	# the long path with real mouse press/release events so focus and scrolling
	# match an actual click.
	for kind in ["selection", "counter", "order"]:
		choice.reset()
		await _exercise_long_ordinary_choice(choice, kind, submitted)

	# Inspected/prepare art choices use a three-column grid with vertical-only
	# scrolling, including the public inspection payload shown to other seats.
	choice.reset()
	await _exercise_long_art_choice(choice, submitted)

	# 整备落点优先于牌面费用；洗回和缓冲由 ChoicePanel 处理。
	var interaction = CARD_INTERACTION_SCRIPT.new()
	interaction.setup(game.prepare_zone, game.main_equipment_zone, game.sub_equipment_zone, game.self_target_head)
	var card := game.hand_zone.cards[0] as DraggableCard
	card.has_dragged = true
	var prepare: Dictionary = interaction.classify_hand_drop(card, game.prepare_zone.get_global_rect().get_center(), 0)
	assert(str(prepare.get("kind", "")) == "prepare")
	var finale_card := DraggableCard.new()
	finale_card.card_data = CardDatabase.find_card("star_finale")
	finale_card.has_dragged = true
	var finale_drop: Dictionary = interaction.classify_hand_drop(finale_card, game.self_target_head.get_global_rect().get_center(), 3, game._effect_target_for(finale_card.card_data))
	assert(str(finale_drop.get("kind", "")) == "effect" and int(finale_drop.get("target_id", -1)) == 0)
	finale_card.card_data = CardDatabase.find_card("echo_finale")
	finale_drop = interaction.classify_hand_drop(finale_card, game.self_target_head.get_global_rect().get_center(), 3, game._effect_target_for(finale_card.card_data))
	assert(str(finale_drop.get("kind", "")) == "effect" and int(finale_drop.get("target_id", -1)) == 0)
	finale_drop = interaction.classify_hand_drop(finale_card, game.main_equipment_zone.get_global_rect().get_center(), 3, game._effect_target_for(finale_card.card_data))
	assert(str(finale_drop.get("kind", "")) == "reject")
	finale_card.free()

	# 减费后的铸锋装备（如紧急重铸后2费装备仅需1费或0费）在余费低于牌面时仍可正常装备
	var blade_card := DraggableCard.new()
	blade_card.card_data = CardDatabase.find_card("forge_blade")
	blade_card.has_dragged = true
	var blade_drop: Dictionary = interaction.classify_hand_drop(blade_card, game.main_equipment_zone.get_global_rect().get_center(), 1, "", 1)
	assert(str(blade_drop.get("kind", "")) == "equip" and bool(blade_drop.get("is_main", false)))
	var equipped_card := DraggableCard.new()
	equipped_card.card_data = blade_card.card_data
	equipped_card.set_meta("equipment_slot", "sub")
	equipped_card.has_dragged = true
	var invalid_equipment_drop: Dictionary = interaction.classify_equipment_drop(equipped_card, Vector2(-100, -100))
	assert(str(invalid_equipment_drop.get("kind", "")) == "reject")
	equipped_card.free()
	blade_card.free()

	# Consecutive card motion cancellation: the latest hover state owns all transforms,
	# and cancelling an entrance tween must leave the card visible.
	var motion_card := (load("res://cards/effect_card.tscn") as PackedScene).instantiate() as DraggableCard
	game.hand_zone.add_child(motion_card)
	await process_frame
	motion_card.home_position = Vector2(120, 40)
	motion_card.position = Vector2(360, 180)
	motion_card.modulate.a = 1.0
	motion_card.return_home()
	motion_card._on_mouse_entered()
	await game.get_tree().create_timer(0.32).timeout
	assert(motion_card.position.is_equal_approx(Vector2(360, 22)))
	assert(motion_card.scale.is_equal_approx(motion_card.rest_scale * 1.04))
	motion_card.rotation = deg_to_rad(-2.0)
	motion_card.return_home()
	motion_card.set_home(Vector2(140, 44), true)
	await game.get_tree().create_timer(0.28).timeout
	assert(motion_card.scale.is_equal_approx(motion_card.rest_scale))
	assert(is_zero_approx(motion_card.rotation))
	motion_card.position = Vector2(360, 180)
	motion_card.scale = Vector2(0.45, 0.45)
	motion_card.modulate.a = 0.0
	motion_card.play_enter_animation()
	motion_card._on_mouse_entered()
	await game.get_tree().create_timer(0.04).timeout
	assert(motion_card.modulate.a > 0.99)
	motion_card.queue_free()
	await process_frame

	# AI 通过真实 GameSession/CardRules 执行一步，延迟期间不重复提交。
	var session := GameSession.new()
	session.setup(game.rules_engine, game.network_session)
	session.start(2, 24680, false, 0)
	game.rules_engine.current = 1
	var runner := AiTurnRunner.new()
	var strategy := AiController.new()
	var expected := strategy.choose_rules_action(game.rules_engine, 1)
	assert(not expected.is_empty())
	var applied_count: Array[int] = [0]
	session.state_changed.connect(func() -> void: applied_count[0] += 1)
	runner.tick(0.0, session, strategy)
	var after_first: int = game.rules_engine.logs.size()
	assert(applied_count[0] == 1)
	assert(runner.delay > 0.0)
	runner.tick(0.1, session, strategy)
	assert(applied_count[0] == 1)
	assert(game.rules_engine.logs.size() == after_first)

	# reset 后旧队列不能清除新队列，且新队列最终能正常结束。
	var presenter := CombatPresenter.new()
	game.game_board.add_child(presenter)
	presenter.setup(game.game_board, game.self_target_head)
	presenter.enqueue([{"kind": "result", "target": 0, "buffered": 0, "lost_hp": 0}])
	presenter.reset()
	presenter.enqueue([{"kind": "result", "target": 0, "buffered": 0, "lost_hp": 0}])
	assert(presenter.running)
	await process_frame
	assert(presenter._feedback._mode == "result")
	var frames := 0
	while presenter.running and frames < 120:
		frames += 1
		await process_frame
	assert(not presenter.running)

	# 返回单机大厅后，隐藏棋盘会阻止旧 AI 继续推进规则状态。
	game.rules_engine.current = 1
	var before_leave_logs: int = game.rules_engine.logs.size()
	game._leave_to_lobby()
	game._process(1.0)
	assert(game.rules_engine.logs.size() == before_leave_logs)
	assert(game.rules_engine.current == 1)

	# 房间关闭同样清理联机状态，并阻止后续调度。
	game._game_session.online = true
	game.game_board.visible = true
	var before_close_logs: int = game.rules_engine.logs.size()
	game._on_room_closed()
	game._process(1.0)
	assert(not game.online_game)
	assert(game.rules_engine.logs.size() == before_close_logs)
	assert(not game.game_board.visible)

	# 重开后棋盘恢复，可继续进入调度生命周期。
	game._start_game()
	assert(game.game_board.visible)

	print("CONTROLLER_MODULES_TEST_OK")
	game.queue_free()
	await process_frame
	quit(0)


func _exercise_long_ordinary_choice(choice, kind: String, submitted: Array[Dictionary]) -> void:
	var cards: Array = []
	for index in range(12):
		var card: Dictionary = CardDatabase.CARDS[index].duplicate(true)
		card.id = "%s-scroll-%d" % [kind, index]
		cards.append(card)
	var pending := {"slot": 0, "title": kind, "kind": kind, "cards": cards, "min": 2, "max": 2}
	choice.render(pending, [], 0, false)
	await process_frame
	await process_frame
	var scroll: ScrollContainer = choice._choice_scroll
	var grid := choice.buttons.get_child(0) as GridContainer
	assert(grid.columns == 2)
	assert(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
	assert(scroll.get_v_scroll_bar().max_value > scroll.size.y)
	_scroll_down(grid.get_child(1))
	await process_frame
	assert(scroll.scroll_vertical > 0)
	scroll.scroll_vertical = 0
	await process_frame
	var hovered_card := grid.get_child(1) as Control
	var pan := InputEventPanGesture.new()
	pan.position = hovered_card.get_global_transform_with_canvas() * (hovered_card.size * 0.5)
	pan.delta = Vector2(0, 2)
	root.push_input(pan, true)
	await process_frame
	assert(scroll.scroll_vertical > 0, "touchpad gesture over a card must reach the scroll container")
	scroll.scroll_vertical = 0
	await process_frame
	var bar := scroll.get_v_scroll_bar()
	var grab_point := bar.get_global_transform_with_canvas() * Vector2(bar.size.x * 0.5, 12)
	var press := InputEventMouseButton.new()
	press.position = grab_point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var drag := InputEventMouseMotion.new()
	drag.position = grab_point + Vector2(0, 50)
	drag.relative = Vector2(0, 50)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(drag, true)
	press = press.duplicate()
	press.position = drag.position
	press.pressed = false
	root.push_input(press, true)
	await process_frame
	assert(scroll.scroll_vertical > 0, "scrollbar thumb must be draggable beside the card grid")
	scroll.ensure_control_visible(grid.get_child(11))
	await process_frame
	var previous_scroll := scroll.scroll_vertical
	var last_button := grid.get_child(11) as Button
	assert(scroll.get_global_rect().has_point(last_button.get_global_rect().get_center()))
	_click_real(last_button)
	await process_frame
	assert(scroll.scroll_vertical == previous_scroll)
	assert(choice.selected_card_ids == ["%s-scroll-11" % kind])
	assert(grid.get_child(11) == last_button)
	_click_real(grid.get_child(10) as Button)
	await process_frame
	assert(choice.selected_card_ids == ["%s-scroll-11" % kind, "%s-scroll-10" % kind])
	if kind == "order":
		choice._confirm_cards()
		await process_frame
		assert(submitted.back().card_ids == ["order-scroll-11", "order-scroll-10"])


func _exercise_long_art_choice(choice, submitted: Array[Dictionary]) -> void:
	var cards: Array = []
	var inspected: Array = []
	for index in range(12):
		cards.append({"id": "art-scroll-%d" % index, "name": "检视 %d" % index, "faction": ""})
		inspected.append({"id": "revealed-%d" % index, "name": "公开 %d" % index, "faction": ""})
	var pending := {"slot": 0, "title": "检视排序", "kind": "order", "cards": cards, "min": 2, "max": 2}
	choice.render(pending, inspected, 0, false)
	await process_frame
	await process_frame
	var scroll: ScrollContainer = choice._choice_scroll
	var grid := choice.buttons.get_child(0) as GridContainer
	assert(grid.columns == 3)
	assert(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
	assert(scroll.get_v_scroll_bar().max_value > scroll.size.y)
	_scroll_down(scroll)
	await process_frame
	assert(scroll.scroll_vertical > 0)
	scroll.ensure_control_visible(grid.get_child(11))
	await process_frame
	var previous_scroll := scroll.scroll_vertical
	var last_button := grid.get_child(11) as Button
	assert(scroll.get_global_rect().has_point(last_button.get_global_rect().get_center()))
	_click_real(last_button)
	await process_frame
	assert(scroll.scroll_vertical == previous_scroll)
	assert(choice.selected_card_ids == ["art-scroll-11"])
	assert(grid.get_child(11) == last_button)
	_click_real(grid.get_child(10) as Button)
	await process_frame
	choice._confirm_cards()
	await process_frame
	assert(submitted.back().card_ids == ["art-scroll-11", "art-scroll-10"])

	choice.render({"slot": 1, "title": "公开检视", "kind": "order"}, inspected, 0, false)
	await process_frame
	assert(not choice.panel.visible and choice.public_inspection.visible)
	assert(choice.public_inspection_cards.get_child_count() == 12)


func _scroll_down(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var wheel := InputEventMouseButton.new()
	wheel.position = point
	wheel.global_position = point
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel, true)
	wheel = wheel.duplicate()
	wheel.pressed = false
	root.push_input(wheel, true)


func _click_real(button: Button) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = point
	click.global_position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
