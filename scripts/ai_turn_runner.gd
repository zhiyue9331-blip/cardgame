class_name AiTurnRunner
extends RefCounted

## 只负责行动节奏。选牌策略仍由 AiController 提供，执行交给 GameSession。
var delay := 0.0


func reset() -> void:
	delay = 0.0


func tick(delta: float, session: GameSession, strategy: AiController) -> void:
	var rules := session.rules
	var pending: Dictionary = rules.pending
	var slot := int(pending.get("slot", -1)) if not pending.is_empty() else int(rules.current)
	if slot <= 0:
		return
	if delay > 0.0:
		delay -= delta
		return
	delay = 0.65
	var action := strategy.choose_rules_action(rules, slot)
	if not action.is_empty():
		session.submit_for_slot(slot, action)
