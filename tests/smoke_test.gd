extends SceneTree

## 实际装备拖放、交换、攻击、效果分支、弃牌查看和卡面加载。
func _init() -> void: call_deferred("_run")

func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate() as GameController
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player_count_selector.select(2)
	game._start_game()
	var rules := game.rules_engine
	rules.current = 0
	var player: Dictionary = rules.players[0]
	player.hand.assign([CardDatabase.find_card("neutral_sword"), CardDatabase.find_card("neutral_shield")])
	for slot in range(1, 4): rules.players[slot].hand.clear()
	game._sync_from_rules_engine()
	game._combat_presenter.reset()
	await process_frame
	assert(game.hand_zone.cards.size() == 2 and game.opponent_panels.size() == 3)
	assert(not game.deck_zone.get_signal_connection_list("pile_pressed").is_empty())
	var sword := game.hand_zone.cards[0]
	sword.has_dragged = true
	game._on_card_dropped(sword, game.main_equipment_zone.get_global_rect().get_center())
	assert(player.main.base_id == "neutral_sword")
	await process_frame
	var shield := game.hand_zone.cards[0]
	shield.has_dragged = true
	game._on_card_dropped(shield, game.sub_equipment_zone.get_global_rect().get_center())
	assert(player.sub.base_id == "neutral_shield")
	game._on_equipped_card_dropped(game.main_equipped_node, game.sub_equipment_zone.get_global_rect().get_center())
	assert(player.main.base_id == "neutral_shield" and player.sub.base_id == "neutral_sword")
	game._on_equipped_card_dropped(game.main_equipped_node, game.opponent_panels[0].head_center())
	assert(player.attack_used and rules.players[1].hp < 12)
	var hp: int = rules.players[1].hp
	game._combat_presenter.reset()
	game._on_equipped_card_dropped(game.main_equipped_node, game.opponent_panels[0].head_center())
	assert(rules.players[1].hp == hp)
	player.cost = 3
	player.hand.append(CardDatabase.find_card("blood_sever"))
	game._sync_from_rules_engine()
	game._combat_presenter.reset()
	await process_frame
	var effect := game.hand_zone.cards[0]
	effect.has_dragged = true
	game._on_card_dropped(effect, game.opponent_panels[0].head_center())
	assert(rules.players[1].hp == hp - 2 and player.hand.is_empty())
	game._toggle_discard_popup()
	assert(game.discard_popup.visible)
	assert(game.get_node("%DiscardCardFlow").get_child_count() == rules.discard.size())
	game._toggle_discard_popup()
	assert(not game.discard_popup.visible)
	# 额外代价弹窗取消后恢复操作，不能把结束回合按钮永久锁住。
	player.cost = 3
	player.hand.append(CardDatabase.find_card("blood_pact"))
	game._sync_from_rules_engine()
	game._combat_presenter.reset()
	await process_frame
	var pact := game.hand_zone.cards[0]
	pact.has_dragged = true
	game._on_card_dropped(pact, game.opponent_panels[0].head_center())
	assert(is_instance_valid(game._choice_panel.effect_panel) and game.end_turn_button.disabled)
	game._choice_panel.close_effect_branch()
	assert(not game.end_turn_button.disabled)
	assert(not game.main_equipped_node.card_data.is_empty() and not pact.card_data.is_empty())
	game.queue_free()
	await process_frame
	print("SMOKE_TEST_OK equip=true swap=true attack=true effect=true branch_cancel=true")
	quit(0)
