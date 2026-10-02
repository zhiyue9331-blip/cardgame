extends SceneTree

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
	assert(game.rules_engine != null)
	assert(game.rules_engine.players.size() == 2)
	assert(game.rules_engine.deck.size() > 0)
	assert(game.current_turn_slot == int(game.rules_engine.get("current")))
	assert(game.hand_zone.cards.size() == game.rules_engine.players[game.local_player_slot].hand.size())
	# 手牌变化只增删对应节点，既有牌不能重新播放入场动画。
	var kept := game.hand_zone.cards[0]
	var added := CardDatabase.find_card("neutral_meditate")
	added.id = "ui-added-card"
	game.rules_engine.players[game.local_player_slot].hand.append(added)
	game._sync_from_rules_engine()
	assert(game.hand_zone.cards[0] == kept)
	var removed: DraggableCard = game.hand_zone.cards.back()
	game._board_view._on_card_hover_changed(removed, true)
	game.rules_engine.players[game.local_player_slot].hand.pop_back()
	game._sync_from_rules_engine()
	assert(game.hand_zone.cards[0] == kept and not game._board_view._card_detail_panel.visible)
	# 释放点须落在高亮头像内；装备区及淘汰头像不是攻击目标。
	var opponent := game.opponent_panels[0] as OpponentPanel
	assert(game._card_interaction.panel_at(opponent.head_center()) == opponent)
	assert(game._card_interaction.panel_at(opponent.main_slot.get_global_rect().get_center()) == null)
	opponent.eliminated = true
	assert(game._card_interaction.panel_at(opponent.head_center()) == null)
	opponent.eliminated = false
	# 长昵称不能撑宽四人对手行；完整昵称仍可通过提示查看。
	game._begin_game(4, 10000, false, 0)
	game.set_process(false)
	var long_name := "测试长昵称一二三四五六七八九十甲乙"
	for index in range(game.opponents.size()):
		var state: Dictionary = game.opponents[index].duplicate(true)
		state.name = long_name
		game.opponent_panels[index].update_state(state)
	await process_frame
	await process_frame
	for panel in game.opponent_panels:
		assert(game.get_global_rect().encloses(panel.get_global_rect()))
		assert(panel.player_name.tooltip_text == long_name)
	var actor := int(game.rules_engine.get("current"))
	var actions: Array = game.rules_engine.legal_actions(actor)
	assert(not actions.is_empty())
	var effect: Dictionary = {}
	for action in actions:
		if str(action.get("type", "")) == "effect":
			effect = action
			break
	if not effect.is_empty():
		var submitted := effect.duplicate(true)
		submitted.erase("label")
		var result: String = game.rules_engine.submit(actor, submitted)
		assert(result.is_empty())
		if not game.rules_engine.pending.is_empty():
			assert(game.rules_engine.pending.has("cards") or game.rules_engine.pending.has("options"))
	game._sync_from_rules_engine()
	assert(game.hand_zone.cards.size() == game.hand.size())
	assert(game.current_turn_slot == int(game.rules_engine.get("current")))
	var local := int(game.local_player_slot)
	var self_state: Dictionary = game.rules_engine.players[local]
	self_state.main = {}
	self_state.sub = {}
	self_state.buffer = []
	game._sync_from_rules_engine()
	assert(game.resonance_mark.visible and game.resonance_mark.text.contains("未共鸣"))
	assert(game._board_view.resonance_seal.level == 0)
	assert(game.get_node("%MyBufferCards").get_child_count() == 4)
	assert(game.main_equipment_zone.get_node("EmptySlotArt").visible)
	self_state.main = {"id": "main-forge", "name": "锻工锤", "faction": "铸锋", "type": "装备牌"}
	self_state.sub = {"id": "sub-temper", "name": "回火战刃", "faction": "铸锋", "type": "装备牌"}
	game._sync_from_rules_engine()
	assert(game.resonance_mark.text == "铸锋 · 共鸣")
	assert(game._board_view.resonance_seal.level == 1)
	assert(not game.main_equipment_zone.get_node("EmptySlotArt").visible)
	self_state.buffer = [{"id": "buffer-blade", "name": "淬刃", "faction": "铸锋", "type": "效果牌"}]
	game._sync_from_rules_engine()
	assert(game.resonance_mark.text == "铸锋 · 深度共鸣")
	assert(game._board_view.resonance_seal.level == 2 and game._board_view.resonance_seal.is_processing())
	# 伏谋筹划回归：伤害计划可拖到自己的头像设置，不需要先选立即目标。
	game._begin_game(2, 20261001, false, 0)
	game.set_process(false)
	await process_frame
	var plan_actor: Dictionary = game.rules_engine.players[0]
	var plan_target: Dictionary = game.rules_engine.players[1]
	plan_actor.main = CardDatabase.find_card("scheme_lamp")
	plan_actor.sub = {}
	plan_actor.cost = 3
	plan_actor.plan = {}
	plan_actor.plan_used = false
	plan_actor.hand.assign([CardDatabase.find_card("scheme_detonate")])
	plan_actor.hand[0].id = "ui-plan-detonate"
	plan_target.plan = {}
	game.rules_engine.current = 0
	game.rules_engine.pending.clear()
	game._combat_presenter.reset()
	game._event_cursor = game.rules_engine.visual_events.size()
	game._sync_from_rules_engine()
	await process_frame
	var plan_card_node: DraggableCard = game.hand_zone.cards[0]
	plan_card_node.has_dragged = true
	game._on_card_dropped(plan_card_node, game.self_target_head.get_global_rect().get_center())
	game._combat_presenter.reset()
	game._event_cursor = game.rules_engine.visual_events.size()
	await process_frame
	assert(plan_actor.plan.get("base_id", "") == "scheme_detonate", "self avatar sets damage plan without target")
	assert(game._plan_panel.visible and game._plan_title.text.contains("伏线引爆"), "own public plan slot shows card")
	assert(not game._cancel_plan_button.disabled, "cancel is enabled during a normal action")
	# 对手的计划也公开显示卡名与兑现说明。
	plan_target.plan = CardDatabase.find_card("scheme_supply")
	plan_target.plan_due = 1
	game._sync_from_rules_engine()
	var public_opponent := game.opponent_panels[0] as OpponentPanel
	assert(public_opponent.equipment_title.text.contains("计划：预留补给"), "opponent public plan is visible")
	assert(public_opponent.equipment_title.tooltip_text.contains("下个自己的回合兑现"), "opponent plan explains due turn")
	# 撤案清理计划位并进入弃牌区。
	game._cancel_plan()
	await process_frame
	assert(plan_actor.plan.is_empty() and game._plan_title.text == "筹划 · 空", "cancel clears own plan UI")
	assert(game.rules_engine.discard.back().get("base_id", "") == "scheme_detonate", "cancel discards the plan")
	# 对手头像触发正常目标分支，分支面板同时提供立即与筹划。
	plan_actor.plan_used = false
	plan_actor.cost = 3
	plan_actor.hand.assign([CardDatabase.find_card("scheme_detonate")])
	plan_actor.hand[0].id = "ui-plan-branch"
	plan_target.plan = {}
	game._sync_from_rules_engine()
	await process_frame
	plan_card_node = game.hand_zone.cards[0]
	plan_card_node.has_dragged = true
	game._on_card_dropped(plan_card_node, public_opponent.head_center())
	assert(is_instance_valid(game._choice_panel.effect_panel), "opponent target opens effect branch")
	var branch_labels: Array[String] = []
	var branch_box := game._choice_panel.effect_panel.get_child(0) as VBoxContainer
	for child in branch_box.get_children():
		if child is Button and (child as Button).text != "取消":
			branch_labels.append((child as Button).text)
	assert(branch_labels.size() == 2, "effect branch has immediate and plan choices")
	var has_plan_label := false
	var has_immediate_label := false
	for label in branch_labels:
		has_plan_label = has_plan_label or label.contains("筹划")
		has_immediate_label = has_immediate_label or label.contains("伏线引爆")
	assert(has_plan_label and has_immediate_label, "effect branch labels plan and immediate actions")
	# 动画或待选状态下，撤案按钮保持禁用，不能绕过行动路由。
	plan_actor.plan = CardDatabase.find_card("scheme_supply")
	game._sync_ui()
	assert(game._cancel_plan_button.disabled, "cancel disabled while effect branch is open")
	game._choice_panel.close_effect_branch()
	await process_frame
	game.rules_engine.pending = {"slot":0, "kind":"plan_target", "title":"计划目标", "cards":[], "min":0, "max":0, "options":[{"id":"1", "label":"玩家2"}]}
	game._sync_ui()
	assert(game._cancel_plan_button.disabled, "cancel disabled while a choice is pending")
	game.rules_engine.pending.clear()
	game._combat_presenter._set_running(true)
	game._sync_ui()
	assert(game._cancel_plan_button.disabled, "cancel disabled during combat animation")
	game._combat_presenter._set_running(false)
	game._cancel_plan()
	await process_frame
	assert(plan_actor.plan.is_empty(), "cancel works again after action gates clear")
	print("RULES_UI_TEST_OK actions=%d hand=%d pending=%s resonance=%s" % [actions.size(), game.hand.size(), str(not game.rules_engine.pending.is_empty()), game.resonance_mark.text])
	game.queue_free()
	await process_frame
	quit(0)
