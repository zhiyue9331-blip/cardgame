# 卡牌与牌桌美术视觉设计 (Art Direction)

## 概念图剩余细节（2026-10-02）

- 对手手牌置于装备后方，放大牌背并使用扇形展开；只读取公开数量，抽牌动画继续落至该区域。费用与反击状态放在生命下方，缓冲区采用横向标签，不遮挡中央牌堆。
- 双方当前生命使用大号红字，最大生命使用较小暖白字。行动中的对手采用头像金环提示。
- 主副装备之间增加共鸣铜铭牌，连接实际同体系不同名的副装备与缓冲牌；深度共鸣带呼吸光与流动光点，未共鸣隐藏。六张缓冲牌时自动收窄，保留筹划空间。
- 牌堆增加随数量变化的叠牌厚度，圆形数量铜徽章贴在卡牌右下；弃牌保留公开卡图、体系、费用与悬停完整说明。
- 阶段标题和结束回合按钮统一削角铜框；结束回合保留原生按钮操作，只有可行动时播放暖金呼吸光。大厅与隐藏状态停止装饰动画。
- 最新实际渲染：`output/concept-polish-2p.png`、`output/concept-polish-4p.png`、`output/concept-polish-states-4p.png`。

## 卡图优先与开放牌桌布局（2026-10-02）

- 实体手牌移除底部效果说明与羊皮纸说明区，插画铺满卡面；保留牌名、费用、体系及悬停完整说明。装备使用底部深色金属属性条。
- 剑盾图标改为银色剑刃与旧铜盾徽，属性数字统一暖白；对手装备也使用同一套图标、独立牌名条与卡框，避免属性文字覆盖插画。
- 己方装备放大为原始卡牌尺寸，手牌缩放为 1.16，缓冲牌扩大为 86×116；状态与费用移至左下，装备、缓冲与筹划排在手牌上方，整备和结束回合位于右下。
- 移除己方大黑色底板、对手信息框和头像矩形底板，保留桌面分界、角饰和交互提示。双人、四人与十张手牌实际渲染已检查。
- 预览：`output/art-layout-2p.png`、`output/art-layout-4p.png`、`output/art-layout-many-hover-4p.png`。

## 整备与筹划布局（2026-10-02）

- 依照 `output/concept-reference.png`，整备移至右下方、结束回合上方，采用削角旧铜铭牌；保留弃牌整备、首轮限制、费用与公共行动互斥提示。
- 筹划位紧邻缓冲区右侧，透明镶铜托盘展示完整实体卡牌，空位复用统一空槽贴图；沙漏和“下回合兑现”显示等待状态，撤案保留独立按钮。
- 可直接把合法伏谋效果牌拖入筹划位，拖牌时高亮该位置；头像分支入口继续可用。
- 手牌区域收窄，为右下操作区预留空间；1280×720 双人、四人实际渲染与较多手牌检查通过。预览：`output/prepare-planning-2p.png`、`output/prepare-planning-4p.png`。


### 共鸣、费用点与空位（2026-10-02）

- `resonance-seal.png`：灰银镂空星盘。未共鸣保持无彩色；铸锋橙铜、回响青蓝、血契赤红、星序紫、归骸冰灰蓝、围猎青绿、伏谋琥珀金。玩家与对手均读取实际共鸣状态。深度共鸣叠加呼吸光、旋转弧环与七颗流动星屑；装饰不接收鼠标输入。
- `cost-pip-gem.png`：黄铜镶嵌琥珀晶石。常显三槽，亮石为剩余费用，暗石为已消耗；额外费用继续显示。
- `empty-card-slot.png`：哑光铜角与暗石星盘底板。装备空位分别叠加剑／盾暗刻，缓冲区展示四个位置，实牌逐位替换空位。

三张贴图均使用内置 imagegen，参考 `output/concept-reference.png`，透明背景，线性 mipmap 缩小采样。完整生成提示词见 `assets/ui/status-art-prompts.md`。


## 对手手牌与统一卡背（2026-10-02）

- 新素材 `assets/ui/astral-card-back.png` 使用内置 imagegen 生成：暗色皮革、哑光黄铜边角与星盘，外部透明，牌内不透明；启用 mipmap 缩小采样。
- 对手手牌数量下方显示扇形牌背，只接收数量，增减时复用已有节点；零手牌时牌背全部移除。双人和四人共用布局。
- `CardBack` 统一对手手牌与隐藏抽牌动画的外观；公共牌堆使用同一贴图，抽牌动画落点改为对手手牌区域。
- 实际渲染预览：`output/opponent-hands-2p.png`、`output/opponent-hands-4p.png`。

最终生成提示词：

> Use case: stylized-concept. Asset type: production game texture for one universal playing CARD BACK. Create a single portrait rectangular dark fantasy tabletop card back, exact 3:4 silhouette, straight-on orthographic, no perspective. Fill almost the full portrait canvas with the card and just 2 percent transparent padding around it. Opaque charcoal-black aged leather face with dark desaturated bronze thin inset border, very small matte brass corner tabs with quiet rivets. Center a readable antique bronze astronomical astrolabe / eight-point compass rose with two engraved concentric rings and simple long cardinal points. Elegant geometric symmetry under 180 degree rotation. Wide uncluttered dark margins; restrained etched bronze lines. Subtle soft diffuse material shading, no glitter or grain, no bright metal reflections, no bloom or luminous parts. Match realistic candlelit dark fantasy physical card game art, muted dark brown and antique gold. Beautiful but understated, recognizable even at 50 pixels wide. No text, no letters, no numbers, no faction symbols, no illustration scene, no extra cards, no deck, no table, no props, no cast shadow outside the card. Entire exterior is genuine transparent alpha, card interior remains fully opaque. Deliver a clean finished reusable single card back PNG.

## 1. 牌桌与环境氛围
- **暗石牌桌背景 (`assets/ui/astral-table.png`)**：
  - 核心对局背景采用乌木外缘与暗青石板材质，四角点缀温润蜡烛暖光，中央辅以低对比度的同心天球蚀刻线与微雕星盘刻线，保持视觉低调沉稳，衬托前景卡牌。
- **全局色调与光影**：
  - 强调暗黑奇幻实体桌游质感（Dark Fantasy Tabletop）。
  - 按钮与高亮采用温润的古金（Antique Gold）、琥珀橙（Warm Amber）及克制的阵营光辉，避免无节制全屏高光与纯色块面板。
  - 结束回合按钮配以金铜光晕与悬停脉冲呼吸感。

## 2. 实体卡牌视觉系统
- **卡框 (`assets/ui/antique-card-frame.png`)**：
  - 采用简洁、克制的哑光旧铜细边卡框，四角带有金属加固卡扣与细小铆钉。长边使用连续柔和的低对比明暗，去除细碎金属亮斑，仅在四角保留少量柔和高光。
  - 中心为全透明镂空区域，自然露出原卡牌画作与衬底。
  - 统一接入应用到所有卡牌实体形态：
    - `DraggableCard`（手牌、己方主副装备槽、战场动画飞牌展示）；
    - `CardThumbnail`（三选一、候选检视、卡牌弹窗缩略图）；
    - `BufferCardChip`（缓冲槽位实体小卡）。
  - 移除原 `_draw` 中的简陋程序画线角饰，仅保留交互时的平滑金芒与光晕，装饰层 `mouse_filter = IGNORE` 不影响拖拽和交互。
- **费用罗盘徽章 (`assets/ui/compass-cost-badge.png`)**：
  - 左上方采用黄铜罗盘纹理的圆形费用徽标。
  - 罗盘中心为空心黑色盘面，上层动态叠印 `cost_label` 费用数字。
  - 尺寸契合逻辑像素（手牌 36×36，缩略图 24×24），数字层级高于罗盘纹理，完整兼容动态减费绿字高亮与实时更新。
  - 卡框和费用罗盘启用 mipmap，并在装饰贴图节点使用线性 mipmap 采样，降低缩小与旋转时的细节闪烁；文字节点保持原有采样设置。
- **羊皮纸文字区**：
  - 牌名条（上方）与效果/属性框（下方）采用微黄羊皮纸质感，文字使用深色古典墨水色调（`#140f0b`），保证在中文字体下极高易读性与实体印刷品厚度感。
- **装备牌与属性**：
  - 主副装备卡底部同样带有羊皮纸属性框与武器/护甲矢量标识，数值清晰明确。

## 3. 对手与界面层级
- **对手信息面板**：
  - 摒弃矩形软件窗口底板，采用无缝透光牌桌融入式布局。
  - 阵营标徽采用克制星芒图标（`✵`），真血数字附带阵营暗红光晕，保持战场整体沉浸感。
- **布局自适应**：
  - 严格适配 1280×720 分辨率双人与四人局，确保关键文字、装备槽、筹划区、缓冲栏与扇形手牌均不发生遮挡。

## 4. 生成素材与最终提示词

### 哑光化修正（2026-10-02）

使用内置 imagegen 对已有卡框做材质编辑，保持透明区域与四角扣件。以下提示词替代初版卡框的高光材质要求；游戏内装饰贴图启用线性 mipmap 缩小采样。

> Use case: precise-object-edit. This is a production card-frame texture overlay for a game and the target already has the correct clean rectangular frame and small corner fittings. Preserve its exact portrait proportions, position, width, inner transparent opening, four small triangular corner tabs and four rivets. Change only metal finish and raster cleanliness. The current frame is too shiny, covered in tiny bright speckles and high-frequency metallic scratches that create visual glitter when scaled down to 100 pixels wide. Replace ALL metal surfaces with smooth MATTE aged bronze in dark desaturated brown, muted old brass accents. Use broad extremely gentle diffuse shading and very subdued soft bevel highlights, with tiny restrained soft highlights on the four corner fittings only. No glitter, sparkle, grain, freckles, fine noisy scratches, thin white lines, chrome reflections, golden glow, bright specular edges or oversharpening. Long sides must read as continuous quiet dark bronze strips with soft stable low-contrast edging. No bright inner border. Handcrafted slightly worn physical metal material but visually clean, calm and low contrast. No added details or ornaments. Strong simple silhouette designed specifically for downsampling and legibility at thumbnail sizes. Everything inside and outside the existing frame remains truly transparent alpha; do not add any background, card artwork, text, numbers or other UI. Deliver only the subtle matte bronze frame on transparency.

两件素材使用内置 imagegen 生成，透明背景保留。卡框以概念图为风格参考，并按用户反馈去除大面积雕花；费用数字由游戏实时叠加，不烘焙进图片。最终素材为 `assets/ui/antique-card-frame.png` 和 `assets/ui/compass-cost-badge.png`。

卡框最终编辑提示词（输入图 1 为初版卡框，输入图 2 为 `output/concept-reference.png`）：

> Use case: precise-object-edit. Asset type: transparent production game card border overlay, portrait 3:4. Image 1 is the existing overdecorated frame to REPLACE completely. Image 2 is the user's target card-table concept, STYLE REFERENCE ONLY, specifically look closely at the small clean metal card corners on its playing cards. Redesign Image 1 into a SIMPLE QUIET physical playing-card border matching Image 2. One thin worn dark bronze/antique brass rectangular border, only about 1.5 percent image width thick. Slight beveled edges, fine realistic metal texture, understated candle highlights, little scuffs. At each of the FOUR corners, a tiny handsome low-profile folded brass corner tab with one small dark rivet, about 5-6 percent of total card width: minimal angular corner fittings with a single delicate engraved line. The corner detail must be small and clean, not ornate. NO leaves, curls, florals, gems, compass roses, sunbursts, points, scrollwork, heavy gold, elaborate filigree, bright glow or heavy shadow. Keep 96 percent of center genuinely transparent alpha and completely empty, no parchment inside, no art, no text, no numbers. Outside also true transparent alpha. Entire rectangular border fits within canvas with 2 percent transparent padding. Retain the feeling of an old physically crafted elegant game card, not a flat vector line drawing, but restrained and simple. Nothing from the full table screenshot should appear except its restrained antique card corner aesthetic.

费用罗盘提示词：

> Use case: stylized-concept. Asset type: production transparent PNG UI icon for card mana/energy COST, square image. Create one exquisitely crafted circular astronomical COMPASS MEDALLION in antique dark gold and brass, directly front-facing orthographic. Luxurious fantasy tabletop card game style: layered beveled concentric gold rings, finely engraved tiny tick marks, small brass studs, ornate four cardinal and four diagonal compass points that project subtly around outer ring. Strong readable silhouette, hand-painted photoreal material and candle-lit beveled highlights, rich aged gold and ebony enamel recesses. CENTER: leave a very large clean plain nearly-black round enamel disk occupying at least 48 percent of total medallion diameter, entirely blank for the game to overlay a large live white cost number. The compass rose points decorate the outer ring only and do NOT obstruct the central blank disk. Medallion occupies 90 percent of square canvas. Entire exterior genuinely transparent alpha with clean contours. No text, letters, digits, number, runes, logos, map, background scene, square backing plate, cartoon, wireframe, flat vector outline. One centered medallion only. Crisp and beautiful readable at 36 pixels, avoid overly thin invisible fine detail.
