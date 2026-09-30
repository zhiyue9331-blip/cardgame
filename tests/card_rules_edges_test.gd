extends SceneTree

var checks := 0
var failures := 0
var serial := 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func card(base_id: String) -> Dictionary:
	serial += 1
	var c := CardDatabase.find_card(base_id)
	c.id = "%s:edge:%d" % [base_id, serial]
	return c

func game(count: int = 3) -> CardRules:
	var g := CardRules.new()
	g.start(count, 82)
	g.current = 0
	g.pending = {}
	g._queue.clear()
	g.discard.clear()
	for p in g.players:
		p.hand.clear()
		p.buffer.clear()
		p.main = {}
		p.sub = {}
		p.cost = 3
	return g

func submit(g: CardRules, slot: int, action: Dictionary) -> void:
	var error := g.submit(slot, action)
	check(error.is_empty(), "action accepted: %s (%s)" % [action.type, error])

func choose(g: CardRules, selected: Array = [], option: String = "") -> void:
	check(not g.pending.is_empty(), "expected pending choice")
	if g.pending.is_empty(): return
	var ids: Array = []
	for c in selected: ids.append(c.id)
	submit(g, int(g.pending.slot), {"type":"choose", "card_ids":ids, "option":option})

func run() -> void:
	# The acting player may die to delayed retaliation while two opponents live.
	var g := game()
	g.players[0].hp = 1
	g.players[0].main = card("neutral_sword")
	g.players[1].main = card("forge_hammer")
	g.players[1].sub = card("forge_blade")
	var counter := card("forge_counter")
	g.players[1].hand.append(counter)
	submit(g, 0, {"type":"attack", "target_slot":1})
	choose(g, [counter])
	check(not g.alive(0) and g.winner == -1, "retaliation eliminates only acting player")
	check(g.current == 1 and g.players[1].cost == 3 and g.players[1].hand.size() == 2, "dead actor advances after retaliation, next player prepares")
	check(g.resolving.is_empty() and g.pending.is_empty(), "dead actor resolution completes")

	# Voluntary buffer overflow is another path to elimination during one's turn.
	g = game()
	g.players[0].hp = 1
	for i in range(4): g.players[0].buffer.append(card("neutral_sword"))
	var record := card("echo_record")
	var component := card("echo_return")
	g.players[0].hand.append_array([record, component])
	submit(g, 0, {"type":"effect", "card_id":record.id, "target_slot":0})
	choose(g, [component])
	check(not g.alive(0) and g.current == 1, "own overflow advances eliminated actor")
	check(g.players[0].hand.is_empty() and g.players[0].buffer.is_empty() and g.resolving.is_empty(), "elimination clears zones and prevents subsequent draw")

	# Counter costs trigger chalice before the source resumes; retaliation runs last.
	g = game()
	g.players[1].hp = 6
	g.players[1].main = card("blood_chalice")
	g.players[1].sub = card("blood_blade")
	g.players[0].res_once = 1
	counter = card("blood_counter")
	g.players[1].hand.append(counter)
	var sever := card("blood_sever")
	g.players[0].hand.append(sever)
	g.players[0].hand.append(card("echo_counter"))
	submit(g, 0, {"type":"effect", "card_id":sever.id, "target_slot":1})
	choose(g, [counter])
	choose(g, [], "enhanced")
	check(g.players[1].hp == 6 and g.players[1].used.has("blood_chalice"), "counter payment and chalice heal resolve before fully reduced source")
	check(g.pending.get("kind") == "buffer", "retaliation permits buffering but never another counter")
	choose(g)
	check(g.players[0].hp == 11 and g.players[0].res_once == 0, "delayed blood retaliation independently applies RES")
	check(g.players[1].cost == 2 and g.players[1].counter_used, "counter consumes retained cost and shared count")
	check(g.resolving.is_empty(), "both source and counter finalized")

	# RES applies to unbufferable damage, then first-segment counter reduction.
	g = game()
	g.players[1].res_once = 1
	g.players[1].hand.append(card("neutral_sword"))
	var ctx := g._context(0, 1, card("blood_sever"))
	ctx.reduction = 2
	g.damage(ctx, 1, 3, false)
	check(g.players[1].hp == 12 and g.players[1].res_once == 0 and int(ctx.reduction) == 0, "RES and counter reduction consume even when final damage is zero")
	g.damage(ctx, 1, 3, false)
	check(g.players[1].hp == 9 and g.players[1].hand.size() == 1 and g.pending.is_empty(), "later unbufferable segment receives neither spent reduction nor buffer choice")

	# Running out midway through a draw resumes exactly the unfulfilled count.
	g = game()
	g.deck.clear()
	g.deck.append(card("neutral_sword"))
	g.discard.append(card("neutral_shield"))
	var original := card("echo_record")
	g.players[0].hand.append(original)
	var other := card("forge_temper")
	g.players[1].hand.append(other)
	g.add_steps([func(): g.draw(0, 3)])
	g._drain()
	check(g.pending.get("slot") == 1, "recycle asks opponent before drawing player")
	choose(g, [other])
	check(g.pending.get("slot") == 0, "recycle asks drawing player last")
	choose(g, [original])
	check(g.players[0].hand.size() == 3 and g.deck.size() == 1, "recycle resumes two remaining draws")
	check(g.discard.is_empty() and g.players[1].hand.is_empty(), "recycle moves public discard exactly once")

	# Opponents' turns and equipment swaps do not refresh ability/counter limits.
	g = game()
	g.players[0].main = card("forge_hammer")
	g.players[0].sub = card("forge_blade")
	g.players[0].used["forge_hammer"] = true
	g.players[0].counter_used = true
	g.players[0].cost = 1
	submit(g, 0, {"type":"swap_equipment"})
	submit(g, 0, {"type":"swap_equipment"})
	check(g.players[0].used.has("forge_hammer"), "swapping does not reset same-name limit")
	submit(g, 0, {"type":"end_turn"})
	check(g.players[0].cost == 1 and g.players[0].counter_used and g.players[0].used.has("forge_hammer"), "next opponent preserves residual fees and used limits")
	submit(g, 1, {"type":"end_turn"})
	check(g.players[0].counter_used and g.players[0].used.has("forge_hammer"), "second opponent still preserves limits")
	submit(g, 2, {"type":"end_turn"})
	check(g.current == 0 and g.players[0].cost == 3 and not g.players[0].counter_used and g.players[0].used.is_empty(), "own preparation resets fees and limits")

	print("CARD_RULES_EDGES_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
