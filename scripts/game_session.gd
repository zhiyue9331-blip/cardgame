class_name GameSession
extends RefCounted

## 新版规则的行动入口；网络传输仍由 NetworkSession 负责。
signal state_changed
signal action_rejected(message: String)

var rules: RefCounted
var network: NetworkSession
var online := false
var local_slot := 0
var last_sequence := 0
var _host_applied_action: Dictionary = {}


func setup(engine: RefCounted, transport: NetworkSession) -> void:
	rules = engine
	network = transport


func start(count: int, seed_value: int, is_online: bool, slot: int) -> void:
	online = is_online
	local_slot = slot
	last_sequence = 0
	_host_applied_action.clear()
	rules.start(count, seed_value)
	state_changed.emit()


func submit_local(action: Dictionary) -> String:
	if online:
		network.submit_action(action)
		return ""
	return submit_for_slot(local_slot, action)


func submit_for_slot(slot: int, action: Dictionary) -> String:
	var result := str(rules.submit(slot, action))
	if result.is_empty():
		state_changed.emit()
	else:
		action_rejected.emit(result)
	return result


func accept_request(sender_peer_id: int, action: Dictionary) -> void:
	var actor := int(action.get("actor_slot", -1))
	var check := str(rules.validate_action(actor, action))
	if not check.is_empty():
		network.reject_action(sender_peer_id, check)
		return
	var applied := str(rules.submit(actor, action))
	if not applied.is_empty():
		network.reject_action(sender_peer_id, applied)
		return
	_host_applied_action = action.duplicate(true)
	network.accept_action(action)


func replay(action: Dictionary) -> void:
	var incoming := int(action.get("sequence", 0))
	if incoming <= last_sequence:
		return
	last_sequence = incoming
	# 房主在广播前已执行操作；收到自己的广播时仅同步显示。
	if online and network.is_host() and not _host_applied_action.is_empty():
		_host_applied_action.clear()
		state_changed.emit()
		return
	var result := str(rules.submit(int(action.get("actor_slot", -1)), action))
	if not result.is_empty():
		action_rejected.emit("联机操作重放失败：%s" % result)
	state_changed.emit()
