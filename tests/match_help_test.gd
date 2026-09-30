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
	for step in range(6): game._match_help._next_page()
	assert(not game._match_help.is_open())
	preferences.save("user://presentation.cfg")
	game.queue_free()
	await process_frame
	print("MATCH_HELP_TEST_OK tutorial=true preferences=true window=true menu=true")
	quit(0)
