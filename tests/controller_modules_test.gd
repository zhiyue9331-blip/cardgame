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
	choice.render({"slot": 0, "title": "排序", "kind": "order", "cards": [
		{"id": "first", "name": "第一张", "faction": ""},
		{"id": "second", "name": "第二张", "faction": ""},
	], "min": 2, "max": 2}, [], 0, false)
	(choice.buttons.get_child(1) as Button).pressed.emit()
	await process_frame
	(choice.buttons.get_child(0) as Button).pressed.emit()
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
