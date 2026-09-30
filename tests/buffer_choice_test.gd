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
	game.queue_free()
	await process_frame
	print("BUFFER_CHOICE_TEST_OK defense=true selected=2 skipped=true")
	quit(0)
