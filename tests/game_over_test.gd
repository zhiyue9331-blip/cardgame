extends SceneTree

## 胜负来自规则结算，验证结束面板、重开和返回大厅。
func _init() -> void:
	call_deferred("_run")

func _finish(game: GameController, winner: int) -> void:
	game.rules_engine.players[1 - winner].hp = 0
	game.rules_engine.refresh_winner()
	game.rules_engine._drain()
	game._sync_from_rules_engine()
	game._combat_presenter.reset()

func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._start_game()
	assert(not game.game_over_panel.visible)
	_finish(game, 1)
	assert(game.game_over and game.game_over_panel.visible)
	assert(game.rematch_button.visible and game.back_to_lobby_button.visible)
	assert(game.game_over_title.text.contains("获胜"))
	game._on_rematch_pressed()
	assert(not game.game_over and not game.game_over_panel.visible)
	assert(game.round_number == 1 and game.rules_engine.players[0].hp == 12)
	assert(game.game_board.visible and not game.lobby.visible)
	_finish(game, 0)
	assert(game.game_over_panel.visible)
	game._on_back_to_lobby_pressed()
	assert(not game.game_over and game.lobby.visible and not game.game_board.visible)
	game._start_game()
	assert(not game.game_over and game.game_board.visible and game.round_number == 1)
	# 三、四人局本地出局时先提供观战选项，再继续真实 AI 结算。
	for count in [3, 4]:
		game._begin_game(count, 9100 + count, false, 0)
		game._match_help.reset()
		game.rules_engine.players[0].hp = 0
		game.rules_engine.refresh_winner()
		game.rules_engine._drain()
		game._sync_from_rules_engine()
		game._combat_presenter.reset()
		assert(not game.game_over and game.game_over_panel.visible)
		assert(game.game_over_title.text == "你已出局")
		assert(game._watch_button.visible and game._skip_button.visible)
		var before := game.rules_engine.logs.size()
		game._process(1.0)
		assert(game.rules_engine.logs.size() == before)
		game._watch_button.pressed.emit()
		assert(not game.game_over_panel.visible and game.header_text.text.contains("你已出局"))
		game._skip_to_result()
		var frames := 0
		while not game.game_over and frames < 150:
			game._process(1.0)
			frames += 1
			await process_frame
		assert(game.game_over and game.game_over_panel.visible)
		assert(game.rules_engine.winner != 0 and game.game_over_title.text.contains("获胜"))
		assert(not game._watch_button.visible and not game._skip_button.visible)
	# 菜单暂停单机 AI；重开和返回大厅清理菜单与快进状态。
	game._begin_game(2, 42, false, 0)
	game._match_help.reset()
	game._combat_presenter.reset()
	game.rules_engine.current = 1
	game._open_match_menu()
	var paused_logs := game.rules_engine.logs.size()
	game._process(1.0)
	assert(game.rules_engine.logs.size() == paused_logs and game.end_turn_button.disabled)
	game._on_rematch_pressed()
	assert(not game._match_help.is_open() and not game._fast_forward_to_result)
	game._on_back_to_lobby_pressed()
	assert(not game._match_help.is_open() and game.lobby.visible)
	game.queue_free()
	await process_frame
	print("GAME_OVER_TEST_OK")
	quit(0)
