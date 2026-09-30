extends SceneTree

## 玩家只结束回合；控制器调度 AI 和回合外待选，必须完整产生胜负。
func _init() -> void: call_deferred("_run")

func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._begin_game(2, 31, false, 0)
	var steps := 0
	var ai_steps := 0
	while not game.game_over and steps < 1500:
		game._combat_presenter.reset() # 跳过播放时长，保留相同的规则与 UI 同步路径。
		var rules := game.rules_engine
		var slot := int(rules.pending.get("slot", rules.current))
		if slot == 0:
			if rules.pending.is_empty():
				game._end_turn()
			else:
				assert(game._rules_submit(game.ai_controller.choose_rules_action(rules, 0)).is_empty())
		else:
			game._ai_turn_runner.reset()
			game._process(1.0)
			ai_steps += 1
		steps += 1
		await process_frame
	game._combat_presenter.reset()
	assert(game.game_over and game.game_over_panel.visible)
	assert(ai_steps > 0 and game.round_number >= 2)
	print("AI_AUTOPLAY_OK steps=%d ai_steps=%d round=%d winner=%d" % [steps, ai_steps, game.round_number, game.rules_engine.winner])
	game.queue_free()
	await process_frame
	quit(0)
