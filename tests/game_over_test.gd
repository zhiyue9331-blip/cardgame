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
	game.queue_free()
	await process_frame
	print("GAME_OVER_TEST_OK")
	quit(0)
