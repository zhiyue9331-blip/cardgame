class_name GameController
extends Control

## 组装模块并把规则状态映射到界面；所有牌局变更统一通过 GameSession。
@onready var lobby: Control = %Lobby
@onready var game_board: Control = %GameBoard
@onready var table_surface: TableSurface = $GameBoard/TableSurface
@onready var player_count_selector: OptionButton = %PlayerCount
@onready var network_session: NetworkSession = %NetworkSession
@onready var header_text: Label = %HeaderText
@onready var deck_zone: PileZone = %DeckZone
@onready var discard_zone: PileZone = %DiscardZone
@onready var prepare_zone: DropZone = %PrepareZone
@onready var resonance_mark: Label = %ResonanceMark
@onready var self_target_head: PanelContainer = %SelfTargetHead
@onready var main_equipment_zone: DropZone = %MainEquipment
@onready var sub_equipment_zone: DropZone = %SubEquipment
@onready var hand_zone: HandZone = %HandZone
@onready var end_turn_button: Button = %EndTurnButton
@onready var log_panel: PanelContainer = %LogPanel
@onready var drag_arrow: DragArrow = %DragArrow
@onready var discard_popup: PanelContainer = %DiscardPopup
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var game_over_title: Label = %GameOverTitle
@onready var rematch_button: Button = %RematchButton
@onready var back_to_lobby_button: Button = %BackToLobbyButton

var rules_engine := CardRules.new()
var ai_controller := AiController.new()
var _choice_panel := preload("res://scripts/choice_panel.gd").new()
var _combat_presenter := CombatPresenter.new()
var _board_view := BoardView.new()
var _lobby_controller := LobbyController.new()
var _game_session := GameSession.new()
var _ai_turn_runner := AiTurnRunner.new()
var _card_interaction := preload("res://scripts/card_interaction.gd").new()

# 只读规则视图，不再维护可单独修改的第二份牌局状态。
var local_player_slot: int:
	get: return _game_session.local_slot
var online_game: bool:
	get: return _game_session.online
var current_turn_slot: int:
	get: return rules_engine.current
var hand: Array[Dictionary]:
	get: return rules_engine.players[local_player_slot].hand
var round_number: int:
	get: return rules_engine.round_number
var game_over: bool:
	get: return game_board.visible and rules_engine.winner >= 0
var opponent_panels: Array[Node]:
	get: return _board_view.opponent_panels
var rules_choice_panel: PanelContainer:
	get: return _choice_panel.panel

var opponents: Array[Dictionary] = []
var main_equipped_node: DraggableCard
var sub_equipped_node: DraggableCard
var _active_arrow_origin := Vector2.ZERO
var _hand_signature := ""
var _log_cursor := 0
var _event_cursor := 0
var _presented_turn := ""


func _ready() -> void:
	_setup_view_modules()
	_game_session.setup(rules_engine, network_session)
	_game_session.state_changed.connect(_sync_from_rules_engine)
	_game_session.action_rejected.connect(_show_rejection)
	_lobby_controller.offline_start_requested.connect(_start_game)
	_lobby_controller.setup({
		"network_mode": %NetworkMode, "player_count_selector": player_count_selector,
		"player_name_input": %PlayerName, "server_address": %ServerAddress,
		"server_port": %ServerPort, "connection_button": %ConnectionButton,
		"leave_room_button": %LeaveRoomButton, "start_button": %StartButton,
		"room_status": %RoomStatus, "room_players": %RoomPlayers,
	}, network_session)
	network_session.game_started.connect(_start_online_game)
	network_session.action_requested.connect(_game_session.accept_request)
	network_session.action_received.connect(_game_session.replay)
	network_session.room_closed.connect(_on_room_closed)
	discard_zone.pile_pressed.connect(_toggle_discard_popup)
	deck_zone.pile_pressed.connect(_on_deck_clicked)
	end_turn_button.pressed.connect(_end_turn)
	rematch_button.pressed.connect(_on_rematch_pressed)
	back_to_lobby_button.pressed.connect(_on_back_to_lobby_pressed)
	%LogButton.pressed.connect(func() -> void: log_panel.visible = not log_panel.visible)


func _setup_view_modules() -> void:
	for module in [_board_view, _choice_panel, _combat_presenter, _lobby_controller]:
		add_child(module)
	_board_view.setup({
		"hand_zone": hand_zone, "deck_zone": deck_zone, "equipped_layer": %EquippedLayer,
		"discard_card_flow": %DiscardCardFlow, "opponent_cards": %OpponentCards,
		"my_buffer_cards": %MyBufferCards, "log_entry_list": %LogEntryList,
		"resonance_mark": resonance_mark, "detail_parent": $GameBoard/CenterArea,
	})
	_board_view.hand_drop_requested.connect(_on_card_dropped)
	_board_view.hand_drag_started.connect(_on_card_drag_started)
	_board_view.hand_drag_updated.connect(_on_card_drag_updated)
	_board_view.equipment_drop_requested.connect(_on_equipped_card_dropped)
	_board_view.equipment_drag_started.connect(_on_equipped_drag_started)
	_board_view.equipment_drag_updated.connect(_on_equipped_drag_updated)
	_choice_panel.setup(game_board)
	_choice_panel.action_requested.connect(_rules_submit)
	_choice_panel.effect_branch_closed.connect(_sync_turn_interaction)
	_combat_presenter.setup(game_board, self_target_head)
	_combat_presenter.running_changed.connect(_on_combat_running_changed)
	table_surface.audio_enabled_changed.connect(_combat_presenter.set_audio_enabled)
	_combat_presenter.set_audio_enabled(table_surface.audio_enabled)
	_card_interaction.setup(prepare_zone, main_equipment_zone, sub_equipment_zone, self_target_head)


func _exit_tree() -> void:
	rules_engine.dispose()


func _start_game() -> void:
	_begin_game(player_count_selector.get_selected_id(), int(Time.get_ticks_msec()), false, 0)


func _start_online_game(game_seed: int, roster: Array[Dictionary]) -> void:
	_begin_game(roster.size(), game_seed, true, network_session.local_slot())


func _begin_game(count: int, game_seed: int, online: bool, local_slot: int) -> void:
	_combat_presenter.reset()
	_choice_panel.reset()
	_ai_turn_runner.reset()
	drag_arrow.hide_arrow()
	_board_view.clear_board()
	main_equipped_node = null
	sub_equipped_node = null
	opponents.clear()
	_hand_signature = ""
	_log_cursor = 0
	_event_cursor = 0
	_presented_turn = ""
	log_panel.hide()
	discard_popup.hide()
	game_over_panel.hide()
	lobby.hide()
	game_board.show()
	_game_session.start(count, game_seed, online, local_slot)


func _leave_to_lobby() -> void:
	game_board.hide()
	lobby.show()
	_combat_presenter.reset()
	_choice_panel.reset()
	_ai_turn_runner.reset()
	drag_arrow.hide_arrow()
	game_over_panel.hide()
	_game_session.online = false
	_lobby_controller.update_controls()


func _on_room_closed() -> void:
	if online_game:
		_leave_to_lobby()
	_lobby_controller.update_controls()


func _on_rematch_pressed() -> void:
	if online_game:
		if network_session.is_host(): network_session.host_start_game()
	else:
		_start_game()


func _on_back_to_lobby_pressed() -> void:
	if network_session.is_online():
		network_session.close_room()
	else:
		_leave_to_lobby()


func _rules_submit(action: Dictionary) -> String:
	return _game_session.submit_local(action)


func _sync_from_rules_engine() -> void:
	for message in rules_engine.logs.slice(_log_cursor):
		_board_view.add_game_log(message)
	_log_cursor = rules_engine.logs.size()
	opponents.clear()
	for slot in range(rules_engine.players.size()):
		if slot == local_player_slot: continue
		var remote: Dictionary = rules_engine.players[slot]
		opponents.append({
			"id": opponents.size() + 1, "slot": slot, "name": _player_name(slot),
			"hp": remote.hp, "eliminated": not rules_engine.alive(slot),
			"hand": remote.hand.size(), "buffer": remote.buffer.size(),
			"buffer_cards": remote.buffer, "cost": remote.cost,
			"main_equipment": remote.main, "sub_equipment": remote.sub,
			"resonance": rules_engine.resonance(slot, str(remote.main.get("faction", ""))),
			"counter_used": remote.counter_used,
		})
	if opponent_panels.size() != opponents.size():
		_board_view.rebuild_opponents(opponents)
		_card_interaction.set_opponents(opponent_panels)
	var ids: PackedStringArray = []
	for card in hand: ids.append(str(card.id))
	var signature := "|".join(ids)
	if signature != _hand_signature:
		_hand_signature = signature
		hand_zone.clear_cards()
		for card in hand: _board_view.create_card(card)
	_sync_ui()
	_combat_presenter.set_targets(local_player_slot, opponents, opponent_panels)
	_combat_presenter.enqueue(rules_engine.visual_events.slice(_event_cursor))
	_event_cursor = rules_engine.visual_events.size()
	var turn_key := "%d:%d" % [round_number, current_turn_slot]
	if not game_over and turn_key != _presented_turn:
		_presented_turn = turn_key
		_combat_presenter.play_turn_cue(current_turn_slot == local_player_slot, current_turn_slot)


func _player_name(slot: int) -> String:
	return network_session.player_name_for_slot(slot) if online_game else "玩家 %d" % (slot + 1)


func _sync_ui() -> void:
	var player: Dictionary = rules_engine.players[local_player_slot]
	var pending := rules_engine.pending
	if game_over:
		var winner := _player_name(rules_engine.winner)
		header_text.text = "牌局结束 · %s 获胜" % winner
		game_over_title.text = "%s 获胜！" % winner
		rematch_button.visible = not online_game or network_session.is_host()
	elif not pending.is_empty():
		header_text.text = "第 %02d 回合    /    %s · %s" % [round_number, _player_name(int(pending.slot)), str(pending.title)]
	else:
		var actor := "你的回合" if current_turn_slot == local_player_slot else "%s 的回合" % _player_name(current_turn_slot)
		header_text.text = "第 %02d 回合    /    %s    ·    行动阶段" % [round_number, actor]
	game_over_panel.visible = game_over and not _combat_presenter.running
	%PlayerTitle.text = "%s（你）" % _player_name(local_player_slot)
	%PlayerHp.text = "真血：%d / 12" % int(player.hp)
	%PlayerCostPips.set_count(int(player.cost))
	deck_zone.update_pile(rules_engine.deck.size())
	var discard := rules_engine.discard
	discard_zone.update_pile(discard.size(), "—" if discard.is_empty() else str(discard.back().name), {} if discard.is_empty() else discard.back())
	main_equipment_zone.set_content("—" if player.main.is_empty() else "")
	sub_equipment_zone.set_content("—" if player.sub.is_empty() else "")
	%BufferZone.set_content("%d / 4" % player.buffer.size())
	prepare_zone.modulate = Color.WHITE if rules_engine.validate_action(local_player_slot, {"type":"prepare"}).is_empty() else Color(0.45, 0.49, 0.53)
	deck_zone.modulate = Color.WHITE if rules_engine.validate_action(local_player_slot, {"type":"draw_two"}).is_empty() else Color(0.45, 0.49, 0.53)
	main_equipped_node = _board_view.ensure_equipped_card(main_equipped_node, player.main, "main")
	sub_equipped_node = _board_view.ensure_equipped_card(sub_equipped_node, player.sub, "sub")
	_board_view.render_buffer(player.buffer)
	_board_view.render_opponents(opponents)
	var faction := str(player.main.get("faction", ""))
	var resonance := rules_engine.resonance(local_player_slot, faction)
	_board_view.render_resonance(faction, resonance)
	_refresh_header_hint(player, faction, resonance)
	for card_node in hand_zone.cards:
		if is_instance_valid(card_node) and card_node is DraggableCard:
			var is_equip: bool = str(card_node.card_data.get("type", "")) == "装备牌"
			var base_cost: int = int(card_node.card_data.get("cost", 0))
			var effective_cost: int = rules_engine.equip_cost(local_player_slot, card_node.card_data) if is_equip else base_cost
			card_node.set_displayed_cost(effective_cost, effective_cost < base_cost)
	var active_opponent := -1
	for index in range(opponents.size()):
		if int(opponents[index].slot) == current_turn_slot: active_opponent = index
	table_surface.update_turn(not game_over and current_turn_slot == local_player_slot, -1 if game_over else active_opponent)
	_sync_turn_interaction()
	_render_rules_pending()
	if discard_popup.visible: _board_view.refresh_discard(discard)


func _refresh_header_hint(player: Dictionary, faction: String, resonance: int) -> void:
	var details := ["体系：" + "、".join(rules_engine.enabled_factions)]
	if not faction.is_empty(): details.append("%s：%s" % [faction, ["未共鸣", "共鸣", "深度共鸣"][resonance]])
	details.append("反击已用" if player.counter_used else "反击可用")
	var modifier := 0
	for buff in player.attack_mods.values(): modifier += int(buff.get("atk", 0))
	if modifier > 0: details.append("下次攻击 +%d" % modifier)
	if int(player.res_once) > 0: details.append("下次 RES +1")
	if int(player.discount) > 0: details.append("下次铸锋装备费用 -%d" % int(player.discount))
	if not player.used.is_empty(): details.append("装备能力已用")
	header_text.tooltip_text = "\n".join(details)


func _can_act() -> bool:
	return game_board.visible and not game_over and rules_engine.alive(local_player_slot) and current_turn_slot == local_player_slot and rules_engine.pending.is_empty() and not _combat_presenter.running and not is_instance_valid(_choice_panel.effect_panel)


func _sync_turn_interaction() -> void:
	var enabled := _can_act()
	for card in hand_zone.cards: card.set_interaction_enabled(enabled)
	for card in [main_equipped_node, sub_equipped_node]:
		if is_instance_valid(card): card.set_interaction_enabled(enabled, true)
	end_turn_button.disabled = not enabled


func _render_rules_pending() -> void:
	_choice_panel.render(rules_engine.pending, rules_engine.inspected, local_player_slot, _combat_presenter.running)


func _on_combat_running_changed(running: bool) -> void:
	game_over_panel.visible = game_over and not running
	_sync_turn_interaction()
	_render_rules_pending()


func _on_card_dropped(card: DraggableCard, position: Vector2) -> void:
	drag_arrow.hide_arrow()
	card.return_home()
	if not _can_act(): return
	var player: Dictionary = rules_engine.players[local_player_slot]
	var required_cost: int = rules_engine.equip_cost(local_player_slot, card.card_data) if str(card.card_data.get("type", "")) == "装备牌" else int(card.card_data.get("cost", 0))
	var intent: Dictionary = _card_interaction.classify_hand_drop(card, position, int(player.cost), _effect_target_for(card.card_data), required_cost)
	match str(intent.kind):
		"prepare":
			if _rules_submit({"type":"prepare", "card_id":str(card.card_data.id)}).is_empty(): prepare_zone.pulse()
		"equip":
			_rules_submit({"type":"equip", "card_id":str(card.card_data.id), "equipment_slot":"main" if intent.is_main else "sub"})
		"effect":
			_play_effect_card(card.card_data, int(intent.target_id))
		"reject":
			_show_rejection(str(intent.reason))


func _effect_target_for(data: Dictionary) -> String:
	return rules_engine.effect_target_for(local_player_slot, data)


func _play_effect_card(data: Dictionary, target_id: int) -> void:
	var action := {"type":"effect", "card_id":str(data.id), "target_slot":_slot_for_target_id(target_id)}
	var enhanced := action.duplicate(true)
	enhanced["options"] = {"enhanced":true}
	if rules_engine.validate_action(local_player_slot, enhanced).is_empty():
		var resonating := rules_engine.resonance(local_player_slot, str(data.faction)) > 0
		_choice_panel.open_effect_branch(data, action, enhanced, rules_engine.legal_actions(local_player_slot), resonating)
		_sync_turn_interaction()
	else:
		_rules_submit(action)


func _on_equipped_card_dropped(card: DraggableCard, position: Vector2) -> void:
	drag_arrow.hide_arrow()
	var intent: Dictionary = _card_interaction.classify_equipment_drop(card, position)
	card.return_home()
	if not _can_act(): return
	if intent.kind == "move":
		if str(intent.source) != str(intent.target): _rules_submit({"type":"swap_equipment"})
	elif intent.kind == "target":
		if intent.source == "main":
			_rules_submit({"type":"attack", "target_slot":_slot_for_target_id(int(intent.panel.target_id))})
		else:
			_show_rejection("请用主装备攻击")
	elif card.has_dragged and intent.source == "main":
		_show_rejection("请将主装备拖到对手区域")


func _slot_for_target_id(target_id: int) -> int:
	return local_player_slot if target_id == 0 else int(opponents[target_id - 1].slot)


func _on_card_drag_started(card: DraggableCard) -> void:
	if card.card_data.type == "效果牌":
		_active_arrow_origin = card.get_global_rect().get_center()
		_on_card_drag_updated(card, get_global_mouse_position())


func _on_card_drag_updated(card: DraggableCard, position: Vector2) -> void:
	if card.card_data.type == "效果牌":
		var color := Color("#83e6a4") if _effect_target_for(card.card_data) == "self" else Color("#e8c45f")
		drag_arrow.show_arrow(_active_arrow_origin, position, color)


func _on_equipped_drag_started(card: DraggableCard) -> void:
	_active_arrow_origin = card.get_global_rect().get_center()
	_on_equipped_drag_updated(card, get_global_mouse_position())


func _on_equipped_drag_updated(card: DraggableCard, position: Vector2) -> void:
	if str(card.get_meta("equipment_slot", "")) == "main":
		drag_arrow.show_arrow(_active_arrow_origin, position, Color("#ef765f"))


func _on_deck_clicked() -> void:
	if not _can_act(): return
	var err := rules_engine.validate_action(local_player_slot, {"type": "draw_two"})
	if not err.is_empty():
		_show_rejection(err)
		return
	if _rules_submit({"type": "draw_two"}).is_empty():
		deck_zone.pulse()


func _end_turn() -> void:
	if _can_act(): _rules_submit({"type":"end_turn"})


func _toggle_discard_popup() -> void:
	discard_popup.visible = not discard_popup.visible
	if discard_popup.visible: _board_view.refresh_discard(rules_engine.discard)


func _show_rejection(message: String) -> void:
	_board_view.add_game_log("玩家操作未执行：%s" % message)
	_combat_presenter.show_center_message(message, Color("#efb26a"))


func _process(delta: float) -> void:
	if game_board.visible and not game_over and not online_game and not _combat_presenter.running:
		_ai_turn_runner.tick(delta, _game_session, ai_controller)
