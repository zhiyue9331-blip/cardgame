extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)

	# 1. Check lobby custom name in offline game
	var name_input: LineEdit = game.get_node("%PlayerName")
	name_input.text = "伏谋策士"
	game.player_count_selector.select(0)
	game._start_game()
	await process_frame

	assert(game._player_name(game.local_player_slot) == "伏谋策士", "Local player name should match lobby input")
	assert(game.get_node("%PlayerTitle").text == "伏谋策士（你）", "PlayerTitle should show custom lobby name")

	# 2. Return to lobby, change name, start again
	game._on_back_to_lobby_pressed()
	await process_frame
	name_input.text = "星轨推演者"
	game._start_game()
	await process_frame

	assert(game._player_name(game.local_player_slot) == "星轨推演者", "Updated lobby name should apply on next game")
	assert(game.get_node("%PlayerTitle").text == "星轨推演者（你）", "PlayerTitle should reflect new custom lobby name")

	# 3. Check persistence in presentation.cfg
	var cfg := ConfigFile.new()
	assert(cfg.load("user://presentation.cfg") == OK)
	assert(str(cfg.get_value("player", "name", "")) == "星轨推演者", "Player name should be persisted in config")

	print("PLAYER_NAME_TEST_OK offline_lobby_name=true update_reconnect=true persistence=true")
	quit(0)
