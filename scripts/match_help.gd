extends Node

## Lightweight pause menu and first-match tutorial for GameController.
## This node owns only its UI; the host decides how to pause or leave the lobby.

class_name MatchHelp

signal returned_to_lobby
signal closed

var panel: Control
var skip_buffer_checkbox: CheckButton

var _board: Control
var _menu_view: VBoxContainer
var _tutorial_view: VBoxContainer
var _tutorial_title: Label
var _tutorial_text: Label
var _tutorial_back: Button
var _tutorial_next: Button
var _menu_hint: Label
var _tutorial_pages: Array[String] = []
var _tutorial_page := 0


func setup(board: Control) -> void:
	_board = board
	if panel != null and is_instance_valid(panel):
		return

	panel = Control.new()
	panel.name = "MatchHelp"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.z_index = 300
	panel.visible = false
	_board.add_child(panel)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.045, 0.82)
	panel.add_child(shade)

	var card := PanelContainer.new()
	card.name = "HelpCard"
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -430
	card.offset_top = -330
	card.offset_right = 430
	card.offset_bottom = 330
	card.size = Vector2(860, 660)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#102425")
	card_style.border_color = Color("#a48d5d")
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(14)
	card_style.content_margin_left = 30
	card_style.content_margin_right = 30
	card_style.content_margin_top = 24
	card_style.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", card_style)
	panel.add_child(card)

	_menu_view = VBoxContainer.new()
	_menu_view.name = "PauseMenu"
	_menu_view.add_theme_constant_override("separation", 14)
	card.add_child(_menu_view)
	var menu_title := Label.new()
	menu_title.text = "对局帮助"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 30)
	_menu_view.add_child(menu_title)
	_menu_hint = Label.new()
	_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_hint.add_theme_font_size_override("font_size", 16)
	_menu_view.add_child(_menu_hint)
	_add_menu_button("继续游戏", _close_by_user)
	_add_menu_button("规则教学", open_tutorial)
	skip_buffer_checkbox = CheckButton.new()
	skip_buffer_checkbox.text = "本局自动不缓冲（保留手牌、承担伤害）"
	skip_buffer_checkbox.tooltip_text = "关闭后恢复每次手动选择缓冲；新开一局自动恢复手动。"
	skip_buffer_checkbox.add_theme_font_size_override("font_size", 20)
	_menu_view.add_child(skip_buffer_checkbox)
	_add_menu_button("回主菜单", _return_to_lobby)

	_tutorial_view = VBoxContainer.new()
	_tutorial_view.name = "Tutorial"
	_tutorial_view.add_theme_constant_override("separation", 12)
	_tutorial_view.visible = false
	card.add_child(_tutorial_view)
	_tutorial_title = Label.new()
	_tutorial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_title.add_theme_font_size_override("font_size", 26)
	_tutorial_view.add_child(_tutorial_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 475)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tutorial_view.add_child(scroll)
	_tutorial_text = Label.new()
	_tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_text.add_theme_font_size_override("font_size", 19)
	_tutorial_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_text.custom_minimum_size = Vector2(790, 0)
	scroll.add_child(_tutorial_text)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 14)
	_tutorial_view.add_child(nav)
	_tutorial_back = Button.new()
	_tutorial_back.text = "上一步"
	_tutorial_back.custom_minimum_size = Vector2(150, 48)
	_tutorial_back.pressed.connect(_previous_page)
	nav.add_child(_tutorial_back)
	_tutorial_next = Button.new()
	_tutorial_next.text = "下一步"
	_tutorial_next.custom_minimum_size = Vector2(150, 48)
	_tutorial_next.pressed.connect(_next_page)
	nav.add_child(_tutorial_next)
	var close_tutorial := Button.new()
	close_tutorial.text = "关闭"
	close_tutorial.custom_minimum_size = Vector2(150, 48)
	close_tutorial.pressed.connect(_close_by_user)
	nav.add_child(close_tutorial)


func _add_menu_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	_menu_view.add_child(button)


func open_menu(online: bool) -> void:
	if panel == null:
		return
	_menu_view.visible = true
	_menu_hint.text = "联机对局仍在继续，请留意回合与响应窗口。" if online else "单机 AI 已暂停，可以查看规则教学。"
	_tutorial_view.visible = false
	panel.visible = true


func open_tutorial() -> void:
	_tutorial_pages = [
		"胜负与回合\n\n每位玩家有 12 点真血；真血降至 0 立即出局。自己的准备阶段费用重置为 3，并抽 2 张牌。每回合最多攻击一次，攻击本身不消耗费用。费用也可以留到对手回合，用来打反击牌。\n\n这是一套可转型的体系：公共池随机启用可用的牌系，再由你选择的主装备决定当前主线。它不是固定职业，换主装备就能换方向。",
		"装备与伤害\n\n主装备提供 ATK（攻击）、DEF（防御）和装备技能；副装备只参与共鸣，不提供属性和技能。交换主副装备免费。把装备拖到主槽或副槽；用主装备攻击时，把它拖到对手头像，每回合一次。\n\n盾牌图标是 DEF，只减少普通攻击。普通攻击扣除 DEF 后通常至少有 1 点伤害；一次性 RES（抗性）还能减少下一次攻击或效果伤害，有机会完全挡住。反击随后再减伤。装备共鸣技能在满足牌面条件时自动触发。",
		"手牌与缓冲\n\n受伤时，每张选中的手牌可以缓冲 1 点伤害；未缓冲的部分扣真血。选择 0 张并确认，就是保留手牌、承担伤害。缓冲牌会公开并按顺序放入缓冲区，也能成为共鸣组件。\n\n缓冲区最多保留 4 张。超过 4 张时，弃置最早的 4 张，并扣 1 点真血，重复处理直到不超过 4 张。不可缓冲的伤害，以及支付真血的代价，不能用手牌抵挡。",
		"共鸣\n\n共鸣需要主装备属于一个体系，并在副槽或缓冲区放入同体系、不同名的组件。放 1 张满足普通共鸣，放满 2 张满足深度共鸣；主装备本身不重复计数。\n\n共鸣组件必须公开，所以副装备和缓冲区既是资源也是对手能观察到的弱点。打出牌时先支付费用和额外代价，再锁定本次共鸣；效果中途移走组件不会取消已经锁定的强化。",
		"公共行动与整备\n\n自己的行动阶段，公共抽牌和整备二选一，每回合最多一次。公共抽牌支付 1 费，抽 2 张。\n\n第 1 轮禁止整备；之后整备通常支付 1 费并弃 1 张手牌。双人局检视牌堆顶最多 3 张，三人或四人局最多 4 张，选 1 张入手，其余按点击次序置于牌堆底。主装备为命轨仪且已共鸣时，整备费用为 0。",
		"出牌与排序\n\n普通效果牌拖到目标头像；对自己生效的牌拖到自己的头像；装备拖到装备槽。结束回合后，对手仍会行动：以你为目标时可能先询问反击，再询问缓冲，这是正常的回合外响应。绿色圆点表示剩余费用。悬停卡牌可查看完整说明。\n\n血价寻契检视牌堆顶 3 张（支付真血强化时 5 张），从中取 1 张血契牌；其他牌需要排序放到牌堆底。排序时按想要的顺序逐张点击，按钮上的 1、2、3 就是最终顺序，再确认。牌底排第一的会先于本次其他置底牌被抽到，但要等上面的牌抽完。"
	]
	_tutorial_page = 0
	_menu_view.visible = false
	_tutorial_view.visible = true
	panel.visible = true
	_render_tutorial()


func _render_tutorial() -> void:
	_tutorial_title.text = "规则教学  %d / %d" % [_tutorial_page + 1, _tutorial_pages.size()]
	_tutorial_text.text = _tutorial_pages[_tutorial_page]
	_tutorial_back.disabled = _tutorial_page == 0
	_tutorial_next.text = "完成" if _tutorial_page == _tutorial_pages.size() - 1 else "下一步"


func _previous_page() -> void:
	if _tutorial_page > 0:
		_tutorial_page -= 1
		_render_tutorial()


func _next_page() -> void:
	if _tutorial_page < _tutorial_pages.size() - 1:
		_tutorial_page += 1
		_render_tutorial()
	else:
		_close_by_user()


func _close_by_user() -> void:
	if panel != null:
		panel.visible = false
	closed.emit()


func _return_to_lobby() -> void:
	if panel != null:
		panel.visible = false
	returned_to_lobby.emit()


func reset() -> void:
	if skip_buffer_checkbox != null:
		skip_buffer_checkbox.button_pressed = false
	if panel != null:
		panel.visible = false


func is_open() -> bool:
	return panel != null and panel.visible
