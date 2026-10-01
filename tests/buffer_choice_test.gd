extends SceneTree

## 当前规则入口的攻击防御、效果伤害以及 ChoicePanel 指定缓冲/零缓冲。
func _init() -> void: call_deferred("_run")

func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._start_game()
	var rules := game.rules_engine
	rules.current = 1
	var defender: Dictionary = rules.players[0]
	defender.main = CardDatabase.find_card("neutral_shield")
	defender.main.defense = 2
	defender.sub = CardDatabase.find_card("neutral_shield")
	defender.sub.defense = 10
	var ctx := rules._context(1, 0, {})
	ctx.kind = "attack"
	ctx.defense = int(defender.main.defense)
	rules.damage(ctx, 0, 5, false)
	assert(defender.hp == 9) # 副装备防御不参与，5 - 2 = 3。
	defender.hp = 12
	ctx.defense = 10
	rules.damage(ctx, 0, 5, false)
	assert(defender.hp == 11) # RES=0 时攻击保底 1。
	defender.hp = 12
	ctx.kind = "effect"
	rules.damage(ctx, 0, 2, false)
	assert(defender.hp == 10) # 效果伤害不减 DEF。
	defender.hp = 12
	defender.main.clear()
	defender.buffer.clear()
	defender.hand.assign([CardDatabase.find_card("neutral_sword"), CardDatabase.find_card("neutral_shield"), CardDatabase.find_card("neutral_aid")])
	var selected := [str(defender.hand[0].id), str(defender.hand[2].id)]
	rules.damage(rules._context(1, 0, {}), 0, 3)
	game._sync_from_rules_engine()
	game._combat_presenter.reset()
	assert(game.rules_choice_panel.visible and rules.pending.kind == "buffer")
	assert(defender.hp == 12 and defender.hand.size() == 3)
	for id in selected: game._choice_panel.toggle_card(id)
	game._choice_panel._confirm_cards()
	assert(defender.buffer.size() == 2 and defender.hand.size() == 1 and defender.hp == 11)
	assert(defender.buffer[0].id == selected[0] and defender.buffer[1].id == selected[1])
	rules.damage(rules._context(1, 0, {}), 0, 2)
	game._sync_from_rules_engine()
	game._combat_presenter.reset()
	game._choice_panel._confirm_cards()
	assert(defender.hand.size() == 1 and defender.hp == 9 and rules.pending.is_empty())
	game._combat_presenter.reset()
	assert(not game.rules_choice_panel.visible)
	# 长手牌列表：滚轮可下滑，选中后保持位置，后面的牌能连续选择。
	defender.hand.clear()
	for index in range(12):
		var data: Dictionary = CardDatabase.CARDS[index].duplicate(true)
		data.id = "buffer-scroll-%d" % index
		defender.hand.append(data)
	rules.damage(rules._context(1, 0, {}), 0, 3)
	game._sync_from_rules_engine()
	game._combat_presenter.reset()
	await process_frame
	await process_frame
	var choice = game._choice_panel
	var scroll: ScrollContainer = choice._choice_scroll
	var card_list := choice.buttons.get_child(0) as GridContainer
	assert(card_list.columns == 2)
	assert(choice.panel.size.y < 500)
	assert(scroll.get_v_scroll_bar().max_value > scroll.size.y)
	var point := scroll.get_global_transform_with_canvas() * (scroll.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var wheel := InputEventMouseButton.new()
	wheel.position = point
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel, true)
	wheel = wheel.duplicate()
	wheel.pressed = false
	root.push_input(wheel, true)
	await process_frame
	assert(scroll.scroll_vertical > 0)
	scroll.ensure_control_visible(card_list.get_child(11))
	await process_frame
	var previous_scroll := scroll.scroll_vertical
	var last_button := card_list.get_child(11) as Button
	assert(scroll.get_global_rect().has_point(last_button.get_global_rect().get_center()))
	_click(last_button)
	await process_frame
	await process_frame
	assert(scroll.scroll_vertical == previous_scroll)
	assert(choice.selected_card_ids == ["buffer-scroll-11"])
	assert(card_list.get_child(11) == last_button)
	_click(card_list.get_child(10) as Button)
	await process_frame
	choice._confirm_cards()
	assert(defender.buffer.back().id == "buffer-scroll-10")
	# 截图中的六张手牌无需滚动即可全部选择。
	choice.render({"slot":0,"kind":"buffer","title":"缓冲1","cards":defender.hand.slice(0, 6),"min":0,"max":1}, [], 0, false)
	await process_frame
	await process_frame
	var six_cards := choice.buttons.get_child(0) as GridContainer
	assert(scroll.get_global_rect().encloses(six_cards.get_child(5).get_global_rect()))
	game.queue_free()
	await process_frame
	print("BUFFER_CHOICE_TEST_OK defense=true selected=2 skipped=true scroll_last_card=true")
	quit(0)

func _click(button: Button) -> void:
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
