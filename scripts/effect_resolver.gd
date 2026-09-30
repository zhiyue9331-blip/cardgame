class_name EffectResolver
extends RefCounted


const EFFECT_STEPS := {
	"damage_2": [{"kind": "damage", "amount": 2}],
	"damage_1": [{"kind": "damage", "amount": 1}],
	"draw_2": [{"kind": "draw", "amount": 2}],
	"draw_1": [{"kind": "draw", "amount": 1}],
	"heal_2": [{"kind": "heal", "amount": 2}],
	"clear_buffer": [{"kind": "clear_buffer"}],
	"siphon": [{"kind": "damage", "amount": 2}, {"kind": "heal", "amount": 1}],
	"battle_insight": [{"kind": "damage", "amount": 1}, {"kind": "draw", "amount": 1}],
	"purifying_light": [{"kind": "clear_buffer"}, {"kind": "heal", "amount": 1}, {"kind": "draw", "amount": 1}]
}


static func resolve(game: Node, card_data: Dictionary, actor_slot: int, target_slot: int) -> void:
	var steps: Array = EFFECT_STEPS.get(str(card_data.get("effect_id", "")), [])
	if steps.is_empty():
		game.add_game_log("玩家 %d：%s没有可执行的效果。" % [actor_slot + 1, card_data.get("name", "卡牌")])
		return
	for step in steps:
		match str(step.get("kind", "")):
			"damage":
				game.apply_effect_damage(game._target_id_for_slot(target_slot), int(step.get("amount", 0)), true)
			"draw":
				game._draw_for_slot(actor_slot, int(step.get("amount", 0)))
			"heal":
				game._heal_slot(actor_slot, int(step.get("amount", 0)))
			"clear_buffer":
				game._clear_buffer_for_slot(actor_slot)
