extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var preferences := ConfigFile.new()
	preferences.load("user://presentation.cfg")
	var first_time := ConfigFile.new()
	first_time.load("user://presentation.cfg")
	first_time.set_value("help", "seen", false)
	first_time.save("user://presentation.cfg")
	var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._begin_game(4, 9200, false, 0)
	assert(game._match_help.is_open() and game.end_turn_button.disabled)
	# 切换音效不能丢失新写入的首次引导记忆。
	var sound: Button = game.table_surface.get_node("SoundToggle")
	sound.button_pressed = not sound.button_pressed
	var saved := ConfigFile.new()
	saved.load("user://presentation.cfg")
	assert(saved.get_value("help", "seen", false))
	game._match_help.reset()
	game._begin_game(4, 9201, false, 0)
	assert(not game._match_help.is_open())
	# 改变窗口比例后，底部操作仍在虚拟画布内。
	for window_size in [Vector2i(1280, 800), Vector2i(960, 540)]:
		root.size = window_size
		await process_frame
		assert(game.get_global_rect().encloses(game.end_turn_button.get_global_rect()))
		assert(game.get_global_rect().encloses(game.hand_zone.get_global_rect()))
		assert(game.get_global_rect().encloses(game.sub_equipment_zone.get_global_rect()))
	game._open_match_menu()
	await process_frame
	var help_card: Control = game._match_help.panel.get_node("HelpCard")
	assert(help_card.get_global_rect().get_center().is_equal_approx(game.get_global_rect().get_center()))
	# Esc 菜单关闭未提交的效果分支，避免遮罩下仍能点到分支按钮。
	game._match_help.reset()
	game._choice_panel.open_effect_branch({"name":"测试"}, {}, {})
	game._open_match_menu()
	assert(not is_instance_valid(game._choice_panel.effect_panel))
	game._match_help.open_tutorial()
	var help := game._match_help
	var planning_page := -1
	for index in range(help._tutorial_pages.size()):
		if help._tutorial_pages[index].begins_with("筹划：提前付费"):
			planning_page = index
	assert(planning_page >= 0)
	for step in range(planning_page): help._next_page()
	assert(help._tutorial_text.text.contains("每个自己的回合最多筹划一次"))
	assert(help._tutorial_text.text.contains("把可筹划牌拖到自己的头像"))
	assert(help._tutorial_text.text.contains("兑现不再次付费"))
	assert(help._tutorial_text.text.contains("新抽到的装备不能提前装上"))
	assert(help._tutorial_next.text == "下一步")
	help._next_page()
	assert(help._tutorial_text.text.contains("不能用于缓冲"))
	assert(help._tutorial_text.text.contains("不返还本回合筹划次数"))
	assert(help._tutorial_text.text.contains("取回后原定兑现取消"))
	assert(help._tutorial_text.text.contains("没有合法伤害目标"))
	help._previous_page()
	assert(help._tutorial_page == planning_page)
	while help._tutorial_page < help._tutorial_pages.size() - 1: help._next_page()
	assert(help.is_open() and help._tutorial_next.text == "完成")
	help._next_page()
	assert(not game._match_help.is_open())
	# 每次缓冲都等待手动确认，关闭菜单不会提交选择。
	var answers := {"count":0}
	var on_buffer := func(cards: Array, _option: String) -> void:
		assert(cards.is_empty())
		answers.count += 1
	game.rules_engine.choose(0, "缓冲1", game.hand, 0, 1, on_buffer, [], Callable(), "buffer")
	game._render_rules_pending()
	var confirm: Button = game._choice_panel.footer.get_child(game._choice_panel.footer.get_child_count() - 1)
	assert(confirm.text == "确认缓冲")
	confirm.pressed.emit()
	assert(answers.count == 1)
	game._combat_presenter.reset()
	game.rules_engine.choose(0, "缓冲1", game.hand, 0, 1, on_buffer, [], Callable(), "buffer")
	game._open_match_menu()
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	game._unhandled_key_input(escape)
	assert(not game._match_help.is_open() and answers.count == 1 and not game.rules_engine.pending.is_empty())
	game._rules_submit({"type":"choose", "card_ids":[], "option":""})
	assert(answers.count == 2)
	preferences.save("user://presentation.cfg")
	game.queue_free()
	await process_frame
	print("MATCH_HELP_TEST_OK tutorial=true preferences=true window=true menu=true")
	quit(0)
