# 脚本职责

`main.tscn` 是唯一游戏入口，挂载 `scripts/game_controller.gd`。控制器负责模块组装、开局与返回大厅、交互行动路由、规则状态到界面的同步，不再实现另一套伤害、洗牌或回合规则。

| 脚本 | 职责 |
| --- | --- |
| `lobby_controller.gd` | 大厅控件、创建与加入房间、名单显示 |
| `game_session.gd` | 新版行动提交、房主验证、客户端按序重放 |
| `board_view.gd` | 卡牌节点、装备显示、对手面板、缓冲区、弃牌、日志与悬停详情 |
| `card_interaction.gd` | 拖拽落点与目标识别，返回交互意图 |
| `choice_panel.gd` | 规则选择与效果分支弹窗，发出行动信号 |
| `combat_presenter.gd` | 战斗事件队列、受击反馈、中心提示与播放状态 |
| `combat_feedback.gd` / `combat_audio.gd` | 攻击、命中、格挡、缓冲、治疗及回合提示；本地合成并缓存音效 |
| `table_surface.gd` | 桌面主题、当前行动玩家高亮、音效开关及本机偏好保存 |
| `end_turn_button.gd` | 原生结束回合按钮的削角铜框、可行动呼吸光与悬停／按下状态 |
| `resonance_link.gd` | 实际公开共鸣贡献牌的铜铭牌、连线与深度共鸣光点 |
| `ai_turn_runner.gd` | 新版 AI 行动间隔与待选事件调度 |

规则统一由 `card_rules.gd` 与 `card_effects.gd` 结算，网络传输由 `network_session.gd` 处理。AI 只通过 `ai_controller.gd` 的 `choose_rules_action` 读取规则状态并选择行动；评分与出牌偏好不因清理改变。

筹划也走同一行动流：`plan` 支付费用并设置公开计划，`cancel_plan` 撤案；规则层记录每个玩家的计划位、筹划次数和己方回合到期时间。准备阶段抽牌队列完成后自动兑现，伤害计划通过 `plan_target` 待选事件决定合法目标，再复用效果反击、伤害与弃牌结算。共鸣和定局沙漏在兑现时锁定；AI 分别评估设置计划和到期目标，不保存设置时的目标。控制器显示双方公开计划，并提供立即使用／筹划和撤案入口。

行动流为：玩家交互（出牌/装备/攻击/整备/点击牌堆公共抽牌）或 AI 决策 → `GameSession` → `CardRules` → 状态同步 → 视图刷新与动画播放。整备与公共抽牌（1费抽2）在规则层严格互斥，每回合二选一限执行一次。联机时先送房主验证，房主只执行一次，客户端按广播序号重放。动画播放期间暂停玩家操作和 AI，回到大厅后停止 AI 调度。

视图模块通过明确的控件引用和显示参数工作，不持有整个 `GameController`。缓冲、洗回、反击和其他待选事件均使用 `ChoicePanel` 提交 `choose` 行动，不再保留旧缓冲弹窗或洗牌拖放分支。旧原型入口与重复结算脚本已移除；测试通过现有规则或会话入口验证行为。

相关验证：`rules_ui_test.gd`、`prepare_drop_test.gd`、`rules_online_test.gd`、`controller_modules_test.gd` 和 `card_playtest.gd`（均在 `tests/`）。
