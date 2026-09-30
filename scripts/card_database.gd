class_name CardDatabase
extends RefCounted

const FACTIONS: Array[String] = ["铸锋", "回响", "血契", "星序", "归骸", "围猎"]
# Stable identities are deliberately independent of the design document's E/S numbers.
const CARDS: Array[Dictionary] = [
	{
		"id": "forge_hammer",
		"base_id": "forge_hammer",
		"name": "锻工锤",
		"type": "装备牌",
		"cost": 1,
		"faction": "铸锋",
		"description": "【共鸣·每轮限1次】当你付费装入铸锋装备后，可将自己 1 张铸锋缓冲牌移入手牌。",
		"subtype": "equipment",
		"attack": 1,
		"defense": 1,
		"ability_id": "forge_hammer",
		"limit_key": "forge_hammer"
	},
	{
		"id": "forge_blade",
		"base_id": "forge_blade",
		"name": "回火战刃",
		"type": "装备牌",
		"cost": 2,
		"faction": "铸锋",
		"description": "【共鸣】攻击时，若本回合曾付费装入铸锋装备：本次 ATK +2。",
		"subtype": "equipment",
		"attack": 1,
		"defense": 0,
		"ability_id": "forge_blade",
		"limit_key": "forge_blade"
	},
	{
		"id": "forge_temper",
		"base_id": "forge_temper",
		"name": "淬刃",
		"type": "效果牌",
		"cost": 1,
		"faction": "铸锋",
		"description": "本回合下一次攻击 ATK +1。\n【共鸣】改为 ATK +2，且目标 DEF 视为至多 1。",
		"subtype": "effect",
		"effect_id": "forge_temper",
		"effect_target": "self"
	},
	{
		"id": "forge_reclaim",
		"base_id": "forge_reclaim",
		"name": "铸件回收",
		"type": "效果牌",
		"cost": 1,
		"faction": "铸锋",
		"description": "将自己缓冲区的 1 张装备牌移入手牌。\n【共鸣】若移入的是铸锋装备，抽 1 张。",
		"subtype": "effect",
		"effect_id": "forge_reclaim",
		"effect_target": "self"
	},
	{
		"id": "forge_wedge",
		"base_id": "forge_wedge",
		"name": "破甲楔",
		"type": "效果牌",
		"cost": 1,
		"faction": "铸锋",
		"description": "对目标造成 1 点伤害。\n【共鸣】本回合你对该目标的下一次攻击无视 DEF。",
		"subtype": "effect",
		"effect_id": "forge_wedge",
		"effect_target": "opponent"
	},
	{
		"id": "forge_reforge",
		"base_id": "forge_reforge",
		"name": "紧急重铸",
		"type": "效果牌",
		"cost": 2,
		"faction": "铸锋",
		"description": "可将副装备移入手牌；本回合下一次装备铸锋装备费用 -1（最低0）。\n【共鸣】改为费用 -2，且下一次攻击额外 ATK +1。",
		"subtype": "effect",
		"effect_id": "forge_reforge",
		"effect_target": "self"
	},
	{
		"id": "forge_finale",
		"base_id": "forge_finale",
		"name": "决战铸锋",
		"type": "效果牌",
		"cost": 3,
		"faction": "铸锋",
		"description": "本回合下一次攻击 ATK +1。\n【共鸣】改为 ATK +3。\n【深度共鸣】额外无视至多 1 点 RES；若目标缓冲此攻击达 2 张手牌，抽 1 张。",
		"subtype": "effect",
		"effect_id": "forge_finale",
		"effect_target": "self"
	},
	{
		"id": "echo_amulet",
		"base_id": "echo_amulet",
		"name": "回声护符",
		"type": "装备牌",
		"cost": 1,
		"faction": "回响",
		"description": "【共鸣·每轮限1次】当你缓冲伤害放入至少 1 张回响牌后：抽 1 张。",
		"subtype": "equipment",
		"attack": 0,
		"defense": 1,
		"ability_id": "echo_amulet",
		"limit_key": "echo_amulet"
	},
	{
		"id": "echo_focus",
		"base_id": "echo_focus",
		"name": "共振法器",
		"type": "装备牌",
		"cost": 1,
		"faction": "回响",
		"description": "【共鸣·每轮限1次】当你的回响效果牌将回响缓冲牌移入手牌后：恢复 1 真血。",
		"subtype": "equipment",
		"attack": 1,
		"defense": 1,
		"ability_id": "echo_focus",
		"limit_key": "echo_focus"
	},
	{
		"id": "echo_record",
		"base_id": "echo_record",
		"name": "留声",
		"type": "效果牌",
		"cost": 1,
		"faction": "回响",
		"description": "可将 1 张回响手牌放入缓冲区末尾；抽 1 张。\n【共鸣】再抽 1 张。",
		"subtype": "effect",
		"effect_id": "echo_record",
		"effect_target": "self"
	},
	{
		"id": "echo_return",
		"base_id": "echo_return",
		"name": "逆流",
		"type": "效果牌",
		"cost": 1,
		"faction": "回响",
		"description": "将自己 1 张缓冲牌移入手牌。\n【共鸣】改为至多移入 2 张（须含至少 1 张回响牌）。",
		"subtype": "effect",
		"effect_id": "echo_return",
		"effect_target": "self"
	},
	{
		"id": "echo_aftershock",
		"base_id": "echo_aftershock",
		"name": "余震",
		"type": "效果牌",
		"cost": 2,
		"faction": "回响",
		"description": "对目标造成 2 点伤害。\n【共鸣】结算后，可弃置自己 1 张回响缓冲牌，再对该目标造成 2 点伤害。",
		"subtype": "effect",
		"effect_id": "echo_aftershock",
		"effect_target": "opponent"
	},
	{
		"id": "echo_barrier",
		"base_id": "echo_barrier",
		"name": "回声结界",
		"type": "效果牌",
		"cost": 2,
		"faction": "回响",
		"description": "弃置自己 1 张缓冲牌（不扣真血）。\n【共鸣】若此前已有至少 2 张回响缓冲牌，获得“下次受击 RES +1”（持续至下回合）。",
		"subtype": "effect",
		"effect_id": "echo_barrier",
		"effect_target": "self"
	},
	{
		"id": "echo_finale",
		"base_id": "echo_finale",
		"name": "万象回声",
		"type": "效果牌",
		"cost": 3,
		"faction": "回响",
		"description": "将自己至多 2 张缓冲牌移入手牌。\n【共鸣】移入的牌中每有 1 张回响牌，对目标造成 2 点伤害（至多4点）。\n【深度共鸣】再恢复 1 真血。",
		"subtype": "effect",
		"effect_id": "echo_finale",
		"effect_target": "self"
	},
	{
		"id": "blood_blade",
		"base_id": "blood_blade",
		"name": "契血刃",
		"type": "装备牌",
		"cost": 1,
		"faction": "血契",
		"description": "【共鸣】攻击时，若本回合曾为血契牌支付真血：本次 ATK +2。",
		"subtype": "equipment",
		"attack": 1,
		"defense": 0,
		"ability_id": "blood_blade",
		"limit_key": "blood_blade"
	},
	{
		"id": "blood_chalice",
		"base_id": "blood_chalice",
		"name": "猩红圣杯",
		"type": "装备牌",
		"cost": 2,
		"faction": "血契",
		"description": "【共鸣·每轮限1次】当你的血契效果牌结算完毕，若曾为此支付真血：恢复 1 真血。",
		"subtype": "equipment",
		"attack": 1,
		"defense": 1,
		"ability_id": "blood_chalice",
		"limit_key": "blood_chalice"
	},
	{
		"id": "blood_pact",
		"base_id": "blood_pact",
		"name": "割血盟约",
		"type": "效果牌",
		"cost": 1,
		"faction": "血契",
		"description": "对目标造成 1 点伤害；可支付 1 真血改为造成 2 点。\n【共鸣】若支付真血，改为造成 3 点。",
		"subtype": "effect",
		"effect_id": "blood_pact",
		"effect_target": "opponent"
	},
	{
		"id": "blood_heal",
		"base_id": "blood_heal",
		"name": "止血契约",
		"type": "效果牌",
		"cost": 1,
		"faction": "血契",
		"description": "恢复 1 真血。\n【共鸣】若本回合曾为其他血契牌支付真血，改为恢复 2 真血。",
		"subtype": "effect",
		"effect_id": "blood_heal",
		"effect_target": "self"
	},
	{
		"id": "blood_search",
		"base_id": "blood_search",
		"name": "血价寻契",
		"type": "效果牌",
		"cost": 1,
		"faction": "血契",
		"description": "检视 3：选 1 张血契牌加入手牌，其余置底。\n【共鸣】可支付 1 真血，将检视改为 5。",
		"subtype": "effect",
		"effect_id": "blood_search",
		"effect_target": "self"
	},
	{
		"id": "blood_sever",
		"base_id": "blood_sever",
		"name": "断脉",
		"type": "效果牌",
		"cost": 2,
		"faction": "血契",
		"description": "对目标造成 2 点伤害。\n【共鸣】可支付 1 真血改为不可缓冲伤害。\n【深度共鸣】若支付真血，伤害增至 3 点。",
		"subtype": "effect",
		"effect_id": "blood_sever",
		"effect_target": "opponent"
	},
	{
		"id": "blood_finale",
		"base_id": "blood_finale",
		"name": "赤月仪式",
		"type": "效果牌",
		"cost": 3,
		"faction": "血契",
		"description": "对目标造成 2 点伤害。\n【共鸣】可支付 2 真血将伤害改为 5 点。\n【深度共鸣】若支付真血：结算后恢复 1 真血并抽 1 张。",
		"subtype": "effect",
		"effect_id": "blood_finale",
		"effect_target": "opponent"
	},
	{
		"id": "star_chart",
		"base_id": "star_chart",
		"name": "星盘",
		"type": "装备牌",
		"cost": 1,
		"faction": "星序",
		"description": "【共鸣·每轮限1次】当你通过星序牌检视并获得星序牌后：可将 1 张手牌置底，然后抽 1 张。",
		"subtype": "equipment",
		"attack": 0,
		"defense": 1,
		"ability_id": "star_chart",
		"limit_key": "star_chart"
	},
	{
		"id": "star_instrument",
		"base_id": "star_instrument",
		"name": "命轨仪",
		"type": "装备牌",
		"cost": 2,
		"faction": "星序",
		"description": "【共鸣】你使用星序效果牌时，其检视张数 +1。",
		"subtype": "equipment",
		"attack": 1,
		"defense": 1,
		"ability_id": "star_instrument",
		"limit_key": "star_instrument"
	},
	{
		"id": "star_gaze",
		"base_id": "star_gaze",
		"name": "观星",
		"type": "效果牌",
		"cost": 1,
		"faction": "星序",
		"description": "检视 3：选 1 张星序牌加入手牌。\n【共鸣】改为检视 4，且可选择任意牌。",
		"subtype": "effect",
		"effect_id": "star_gaze",
		"effect_target": "self"
	},
	{
		"id": "star_prophecy",
		"base_id": "star_prophecy",
		"name": "错位预言",
		"type": "效果牌",
		"cost": 1,
		"faction": "星序",
		"description": "检视 2 并按任意顺序放回顶部。\n【共鸣】可将其中 1 张置底，再排列其余放回顶部；然后抽 1 张。",
		"subtype": "effect",
		"effect_id": "star_prophecy",
		"effect_target": "self"
	},
	{
		"id": "star_intercept",
		"base_id": "star_intercept",
		"name": "截取未来",
		"type": "效果牌",
		"cost": 2,
		"faction": "星序",
		"description": "检视 4：选 1 张牌加入手牌。\n【共鸣】若选的是星序牌，可再从剩余牌中选 1 张非星序牌加入手牌。",
		"subtype": "effect",
		"effect_id": "star_intercept",
		"effect_target": "self"
	},
	{
		"id": "star_fall",
		"base_id": "star_fall",
		"name": "星落",
		"type": "效果牌",
		"cost": 2,
		"faction": "星序",
		"description": "对目标造成 2 点伤害。\n【共鸣】先检视 3，其中每展示 1 张不同名星序牌（至多2张），伤害 +1；全部检视牌置底。",
		"subtype": "effect",
		"effect_id": "star_fall",
		"effect_target": "opponent"
	},
	{
		"id": "star_finale",
		"base_id": "star_finale",
		"name": "改写命轨",
		"type": "效果牌",
		"cost": 3,
		"faction": "星序",
		"description": "检视 5：选 1 张牌加入手牌。\n【共鸣】改为至多选 2 张（须含至少 1 张星序牌）。\n【深度共鸣】取牌后对目标造成 3 点伤害。",
		"subtype": "effect",
		"effect_id": "star_finale",
		"effect_target": "self"
	},
	{
		"id": "grave_lamp",
		"base_id": "grave_lamp",
		"name": "送葬灯",
		"type": "装备牌",
		"cost": 1,
		"faction": "归骸",
		"description": "【共鸣·每轮限1次】当你支付归葬后，可将自己 1 张归骸缓冲牌移入手牌。",
		"subtype": "equipment",
		"attack": 1,
		"defense": 0,
		"ability_id": "grave_lamp",
		"limit_key": "grave_lamp"
	},
	{
		"id": "grave_casket",
		"base_id": "grave_casket",
		"name": "骨匣",
		"type": "装备牌",
		"cost": 2,
		"faction": "归骸",
		"description": "【共鸣·每轮限1次】当你的归骸效果牌从弃牌区回收归骸牌后：恢复 1 真血。",
		"subtype": "equipment",
		"attack": 1,
		"defense": 1,
		"ability_id": "grave_casket",
		"limit_key": "grave_casket"
	},
	{
		"id": "grave_pick",
		"base_id": "grave_pick",
		"name": "拾骨",
		"type": "效果牌",
		"cost": 1,
		"faction": "归骸",
		"description": "从弃牌区选 1 张费用 ≤1 的归骸牌加入手牌。\n【共鸣】费用上限提高至 2。",
		"subtype": "effect",
		"effect_id": "grave_pick",
		"effect_target": "self"
	},
	{
		"id": "grave_rite",
		"base_id": "grave_rite",
		"name": "葬仪",
		"type": "效果牌",
		"cost": 1,
		"faction": "归骸",
		"description": "弃置 1 张手牌，抽 1 张。\n【共鸣】若弃置的是归骸牌，再抽 1 张。",
		"subtype": "effect",
		"effect_id": "grave_rite",
		"effect_target": "self"
	},
	{
		"id": "grave_spike",
		"base_id": "grave_spike",
		"name": "骨刺",
		"type": "效果牌",
		"cost": 2,
		"faction": "归骸",
		"description": "对目标造成 2 点伤害。\n【共鸣】可归葬 1 张牌，将伤害改为 3 点。",
		"subtype": "effect",
		"effect_id": "grave_spike",
		"effect_target": "opponent"
	},
	{
		"id": "grave_summon",
		"base_id": "grave_summon",
		"name": "引魂",
		"type": "效果牌",
		"cost": 2,
		"faction": "归骸",
		"description": "从弃牌区选 1 张费用 ≤1 的牌加入手牌。\n【共鸣】可改为选任意费用的归骸牌（若为3费，本回合不可使用）。",
		"subtype": "effect",
		"effect_id": "grave_summon",
		"effect_target": "self"
	},
	{
		"id": "grave_finale",
		"base_id": "grave_finale",
		"name": "骸潮",
		"type": "效果牌",
		"cost": 3,
		"faction": "归骸",
		"description": "对目标造成 2 点伤害。\n【共鸣】可归葬 2 张牌将伤害改为 5 点。\n【深度共鸣】若已归葬：结算后从弃牌区取 1 张费用 ≤2 的归骸牌加入手牌。",
		"subtype": "effect",
		"effect_id": "grave_finale",
		"effect_target": "opponent"
	},
	{
		"id": "hunt_crossbow",
		"base_id": "hunt_crossbow",
		"name": "追猎弩",
		"type": "装备牌",
		"cost": 1,
		"faction": "围猎",
		"description": "【共鸣】攻击手牌不多于你的目标时：本次 ATK +2。",
		"subtype": "equipment",
		"attack": 1,
		"defense": 0,
		"ability_id": "hunt_crossbow",
		"limit_key": "hunt_crossbow"
	},
	{
		"id": "hunt_flag",
		"base_id": "hunt_flag",
		"name": "封锁旗",
		"type": "装备牌",
		"cost": 2,
		"faction": "围猎",
		"description": "【共鸣·每轮限1次】当你的围猎效果牌使对手弃手牌后：可将 1 张手牌置底，抽 1 张。",
		"subtype": "equipment",
		"attack": 1,
		"defense": 1,
		"ability_id": "hunt_flag",
		"limit_key": "hunt_flag"
	},
	{
		"id": "hunt_probe",
		"base_id": "hunt_probe",
		"name": "试探",
		"type": "效果牌",
		"cost": 1,
		"faction": "围猎",
		"description": "对目标造成 1 点伤害。\n【共鸣】结算后若目标手牌少于你，抽 1 张。",
		"subtype": "effect",
		"effect_id": "hunt_probe",
		"effect_target": "opponent"
	},
	{
		"id": "hunt_retreat",
		"base_id": "hunt_retreat",
		"name": "逼退",
		"type": "效果牌",
		"cost": 1,
		"faction": "围猎",
		"description": "目标选择：弃 1 张手牌，或受到 1 点伤害。\n【共鸣】若目标选择承伤，改为受到 2 点。",
		"subtype": "effect",
		"effect_id": "hunt_retreat",
		"effect_target": "opponent"
	},
	{
		"id": "hunt_cutoff",
		"base_id": "hunt_cutoff",
		"name": "断援",
		"type": "效果牌",
		"cost": 2,
		"faction": "围猎",
		"description": "选择一名对手，将弃牌区 1 张牌置底。\n【共鸣】若该牌与该对手主装备同体系，其弃 1 张手牌。",
		"subtype": "effect",
		"effect_id": "hunt_cutoff",
		"effect_target": "opponent"
	},
	{
		"id": "hunt_blockade",
		"base_id": "hunt_blockade",
		"name": "封锁补给",
		"type": "效果牌",
		"cost": 2,
		"faction": "围猎",
		"description": "目标下个准备阶段抽牌数减为 1 张。\n【共鸣】若打出时目标手牌多于你，其弃 1 张手牌。",
		"subtype": "effect",
		"effect_id": "hunt_blockade",
		"effect_target": "opponent"
	},
	{
		"id": "hunt_finale",
		"base_id": "hunt_finale",
		"name": "合围",
		"type": "效果牌",
		"cost": 3,
		"faction": "围猎",
		"description": "对目标造成 2 点伤害。\n【共鸣】若目标手牌不多于你，伤害改为 4 点。\n【深度共鸣】若目标缓冲此伤害达 2 张手牌，其额外弃 1 张手牌。",
		"subtype": "effect",
		"effect_id": "hunt_finale",
		"effect_target": "opponent"
	},
	{
		"id": "neutral_sword",
		"base_id": "neutral_sword",
		"name": "短剑",
		"type": "装备牌",
		"cost": 0,
		"faction": "",
		"description": "无特殊效果。",
		"subtype": "equipment",
		"attack": 1,
		"defense": 0,
		"ability_id": "neutral_sword",
		"limit_key": "neutral_sword"
	},
	{
		"id": "neutral_shield",
		"base_id": "neutral_shield",
		"name": "木盾",
		"type": "装备牌",
		"cost": 1,
		"faction": "",
		"description": "无特殊效果。",
		"subtype": "equipment",
		"attack": 0,
		"defense": 2,
		"ability_id": "neutral_shield",
		"limit_key": "neutral_shield"
	},
	{
		"id": "neutral_meditate",
		"base_id": "neutral_meditate",
		"name": "冥想",
		"type": "效果牌",
		"cost": 1,
		"faction": "",
		"description": "抽 1 张，随后可将 1 张手牌置底再抽 1 张。",
		"subtype": "effect",
		"effect_id": "neutral_meditate",
		"effect_target": "self"
	},
	{
		"id": "neutral_aid",
		"base_id": "neutral_aid",
		"name": "急救",
		"type": "效果牌",
		"cost": 1,
		"faction": "",
		"description": "弃置自己 1 张缓冲牌（不扣真血）。",
		"subtype": "effect",
		"effect_id": "neutral_aid",
		"effect_target": "self"
	},
	{
		"id": "neutral_disarm",
		"base_id": "neutral_disarm",
		"name": "缴械",
		"type": "效果牌",
		"cost": 2,
		"faction": "",
		"description": "将一名对手的主装备移入其手牌。",
		"subtype": "effect",
		"effect_id": "neutral_disarm",
		"effect_target": "opponent"
	},
	{
		"id": "neutral_dismantle",
		"base_id": "neutral_dismantle",
		"name": "拆解阵式",
		"type": "效果牌",
		"cost": 2,
		"faction": "",
		"description": "指定对手缓冲区 1 张牌，由其选择移入手牌或弃牌区（不扣真血）。",
		"subtype": "effect",
		"effect_id": "neutral_dismantle",
		"effect_target": "opponent"
	},
	{
		"id": "forge_counter",
		"base_id": "forge_counter",
		"name": "交刃反制",
		"type": "效果牌",
		"cost": 1,
		"faction": "铸锋",
		"description": "【响应：对你的攻击】本次减伤 1。\n【共鸣】改为减伤 3；若你未因此次攻击损失真血，对攻击者造成 1 点伤害。",
		"subtype": "counter",
		"effect_id": "forge_counter",
		"effect_target": "self",
		"response_window": "attack"
	},
	{
		"id": "echo_counter",
		"base_id": "echo_counter",
		"name": "回声折返",
		"type": "效果牌",
		"cost": 1,
		"faction": "回响",
		"description": "【响应：对你的伤害行动】本次减伤 1。\n【共鸣】改为减伤 2，并可立即将自己 1 张回响缓冲牌移入手牌（可用于随后缓冲）。",
		"subtype": "counter",
		"effect_id": "echo_counter",
		"effect_target": "self",
		"response_window": "damage"
	},
	{
		"id": "blood_counter",
		"base_id": "blood_counter",
		"name": "血誓反噬",
		"type": "效果牌",
		"cost": 1,
		"faction": "血契",
		"description": "【响应：对你的伤害行动】本次减伤 1。\n【共鸣】可支付 1 真血改为减伤 2；来源行动结算后，对攻击者造成 2 点伤害。",
		"subtype": "counter",
		"effect_id": "blood_counter",
		"effect_target": "self",
		"response_window": "damage"
	},
	{
		"id": "star_counter",
		"base_id": "star_counter",
		"name": "命轨偏折",
		"type": "效果牌",
		"cost": 1,
		"faction": "星序",
		"description": "【响应：指向你或你的装备/缓冲的效果牌】检视 2，可取 1 张星序牌加入手牌。\n【共鸣】若该效果含伤害，本次减伤 2；否则取消其首次移动你装备或缓冲牌的步骤。",
		"subtype": "counter",
		"effect_id": "star_counter",
		"effect_target": "self",
		"response_window": "effect"
	},
	{
		"id": "grave_counter",
		"base_id": "grave_counter",
		"name": "骸骨替身",
		"type": "效果牌",
		"cost": 1,
		"faction": "归骸",
		"description": "【响应：对你的伤害行动】本次减伤 1。\n【共鸣】可归葬 1 张牌改为减伤 2。",
		"subtype": "counter",
		"effect_id": "grave_counter",
		"effect_target": "self",
		"response_window": "damage"
	},
	{
		"id": "hunt_counter",
		"base_id": "hunt_counter",
		"name": "反向包围",
		"type": "效果牌",
		"cost": 1,
		"faction": "围猎",
		"description": "【响应：对你的伤害行动】本次减伤 1。\n【共鸣】攻击者选择弃 1 张手牌，或使你本次减伤改为 3。",
		"subtype": "counter",
		"effect_id": "hunt_counter",
		"effect_target": "self",
		"response_window": "damage"
	}
]

static func choose_factions(player_count: int, shuffle_seed: int) -> Array[String]:
	var needed := 6 if player_count >= 4 else player_count + 1
	var candidates: Array[String] = FACTIONS.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = shuffle_seed
	var result: Array[String] = []
	while result.size() < needed and not candidates.is_empty():
		result.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	return result


static func build_shared_deck(player_count: int, shuffle_seed: int) -> Array[Dictionary]:
	var factions := choose_factions(player_count, shuffle_seed)
	var result: Array[Dictionary] = []
	for original in CARDS:
		if not str(original.faction).is_empty() and str(original.faction) not in factions:
			continue
		var copies := 1
		if not str(original.faction).is_empty():
			copies = 2
		for index in range(copies):
			var card: Dictionary = original.duplicate(true)
			card.id = "%s@%d" % [str(card.base_id), index]
			result.append(card)
	_shuffle(result, shuffle_seed ^ 0x4F1BBCDC)
	return result


static func find_card(base_id: String) -> Dictionary:
	for card in CARDS:
		if str(card.base_id) == base_id:
			return card.duplicate(true)
	return {}


static func _shuffle(cards: Array, shuffle_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = shuffle_seed
	for index in range(cards.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held: Dictionary = cards[index]
		cards[index] = cards[other]
		cards[other] = held
