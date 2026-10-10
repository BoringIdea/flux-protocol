# Flux Protocol Whitepaper

English: [whitepaper.md](./whitepaper.md)

> Draft v2

## 1. Vision

传统 NFT（ERC-721）最大的限制不是资产本身，而是缺乏流动性。ERC-20 已经形成了完整的 DeFi 基础设施，包括：

- DEX
- AMM
- LP
- Lending
- Leverage
- Perpetual
- Tax Token
- Yield Farming

而 NFT 仍然主要停留在收藏、挂单交易和拍卖等场景。因此，Flux Protocol 希望创造一种新的资产标准，使数字资产能够在 NFT（收藏态）与 FT（流动态）之间自由切换，让 NFT 真正进入 DeFi。Flux 代表资产在不同形态之间持续流动和变化；协议品牌独立于具体 NFT IP，从而可以在未来支持更多 Collection。

---

## 2. Core Asset Model

整个协议固定存在 `10,000 Asset Units`，每一个 Asset Unit 都对应一个唯一资产。Asset 可以处于三种状态：

```text
Credit
  ↓
NFT
  ↓
FT（10,000 FLUX）
```

三者之间的换算关系为：

```text
1 Asset Unit = 1 NFT = 10,000 FLUX
```

协议保证 NFT 与 FT 在任何时刻都可以双向转换。

---

## 3. NFT Model

NFT 并不是固定编号资产，其价值来源于 Trait 组合，例如：

```text
Hair
Eyes
Background
Accessory
Body
```

当 NFT 被 Burn 时，将转换为 `10,000 FLUX`：

```text
NFT → 10,000 FLUX
```

再次转换时，将通过 Random Mint 生成新的 NFT：

```text
10,000 FLUX → Random Mint → 新的 NFT
```

新的 NFT 将重新生成 Trait。因此，NFT 的价值完全由市场决定，协议无需人为决定“某个 NFT 可以兑换多少 ERC-20”。

---

## 4. Genesis

Genesis 的目标只有两个：

1. 完成公平发行（Distribution）。
2. 完成 LP 建立（Liquidity Bootstrap）。

Genesis 完成之后，协议正式开始运行。

---

## 5. Genesis Launch

协议采用 Continuous Clearing Auction（CCA）作为 Genesis。Genesis 共拥有 `10,000 Asset Units`，按 50/50 分配：

```text
10,000 Units
├── 5,000 Units → CCA Auction
└── 5,000 Units → LP Reserve
```

Auction 出售 `5,000 Credit`；LP Reserve 转换成 `50,000,000 FLUX`。Auction 募集 ETH 后，协议自动建立 Uniswap LP：

```text
50,000,000 FLUX + Auction ETH → Uniswap LP
```

LP 永久锁定。Genesis 完成时，协议已经拥有初始价格、初始 LP 和 ERC-20 流动性，Auction 用户获得 `5,000 Credit`。

---

## 6. Credit

Credit 是 Genesis 阶段存在的临时资产，代表尚未 Materialize 的 Asset。Credit 可以选择转换成 Genesis NFT 或 `10,000 FLUX`：

```text
Credit → Genesis NFT
Credit → 10,000 FLUX
```

Credit 全部完成转换以后，协议仅保留 NFT 与 FT 两种状态。

---

## 7. Genesis NFT

Genesis NFT 是协议最重要的资产，拥有永久协议权益。它不再只是“带有现金流的 NFT”，而是：

> **Identity + Trait + ERC-6551 Wallet + Genesis fee share + Reward Asset Portfolio**

整个 NFT Collection 都支持 ERC-6551 Token Bound Account（TBA），但只有 Genesis NFT 自动获得协议手续费分成权。TBA 地址由 NFT 身份确定，可按需创建，无需在 Mint 时预部署。TBA 可以持有 ETH、FLUX、Reward Asset Registry 登记的 ERC-20 奖励资产；NFT 转让时，其 TBA 的经济控制权也随 NFT 一起转移。

Genesis NFT 可以转换成 `10,000 FLUX`，但一旦 Burn，Genesis 身份及未来手续费分成权将永久消失；以后重新 Mint 的 NFT 不会重新获得 Genesis 权益。Burn 必须执行原子化结算：

```text
读取 NFT 对应的 TBA
  ↓
将协议登记的资产清算给当前 Holder
  ↓
确认结算完成
  ↓
Burn Genesis NFT
  ↓
Mint 10,000 FLUX 给 Holder
  ↓
永久销毁 Genesis Right
```

自动结算范围由 Reward Asset Registry 定义。协议无法枚举用户自行转入的任意资产，因此非登记资产需要由用户自行管理；登记资产以 Native ETH/WETH 与 ERC-20 为主。

因此，Genesis NFT 具有天然稀缺性。Genesis NFT Holder 将永久分享协议的部分手续费收入。Genesis NFT 既代表协议最早的参与者，也是协议第一批 Founders。

---

## 8. Continuous Clearing Auction (CCA)

Genesis 使用 CCA 完成价格发现。CCA 并不是按投入资金比例分配 Credit；每一个参与者需要提交：

- **Budget**：愿意投入的 ETH。
- **Max Price**：能够接受的最高成交价格。

拍卖期间，协议持续计算 Clearing Price（统一清算价格）。满足条件的 Bid 成交；当价格超过用户的最高价格时，该 Bid 自动退出。最终，所有成交用户均按照统一价格成交。

CCA 的优势包括：

- 无 Gas War
- 无抢跑
- 无尾盘狙击
- 公平价格发现
- 可直接初始化 LP

Genesis Auction 完成以后，该价格直接作为 FLUX/ETH LP 的初始价格。

---

## 9. Protocol Lifecycle

Genesis 阶段：

```text
CCA Auction
  ↓
Price Discovery
  ↓
LP Initialization
  ↓
Credit Distribution
  ↓
Protocol Live
```

协议上线后：

```text
Credit → Genesis NFT → FT → NFT → FT
```

---

## 10. NFT / FT Conversion

NFT 与 FT 的转换关系如下：

```text
NFT → 10,000 FLUX
10,000 FLUX → Random NFT
```

协议始终保证 Asset 总量保持恒定。

---

## 11. Target Balance

协议既不追求全部 NFT，也不追求全部 FT，而是希望长期保持以下目标比例：

```text
NFT：60%～70%
FT： 30%～40%
```

NFT 负责收藏价值，FT 负责 DeFi 流动性。协议通过动态经济机制，使系统围绕目标区间长期波动。

---

## 12. Dynamic Fee Engine

协议采用双向动态费率，目标不是鼓励某一种资产，而是维持 NFT/FT 的动态平衡：

- 当 FT 高于目标时，鼓励 `FT → NFT`。
- 当 NFT 高于目标时，鼓励 `NFT → FT`。
- 在中性区内，双方均可低成本转换。
- 偏离越大，转换费用越高。

Balance Engine 以连续函数计算 Fee/Reward，而不是固定阶梯。

---

## 13. Fee Sources

协议共有三种手续费来源：

1. **ERC-20 Swap Fee**：来自 Uniswap 等 AMM。
2. **NFT Marketplace Fee**：来自 NFT 二级市场，例如 OpenSea 等支持版税或协议费的平台。
3. **NFT / FT Conversion Fee**：来自协议内部转换，包括动态 Mint Fee。

---

## 14. Fee Engine

所有手续费统一进入 Fee Engine，随后自动分配至四个 Vault：

```text
Fee
├── Liquidity Vault
├── Reward Strategy / Genesis Accounting
├── Balance Vault
└── Protocol Vault
```

### Liquidity Vault

Liquidity Vault 用于持续增加 FLUX/ETH LP 深度。协议运行越久，LP 越深，流动性越稳定。

### Genesis Vault

Genesis NFT Holder 永久分享协议现金流。Genesis NFT Burn 后将永久失去未来收益权，剩余 Genesis NFT 会自动分享更多现金流。已经领取到 TBA 的资产属于该 NFT；尚未领取但已经归属的奖励，需要在 Burn Settlement 中一并结算。

Genesis Vault 不再直接向所有 Holder 推送 ETH。它采用 Pull-based Accounting，通过 `accRewardPerShare + rewardDebt` 按奖励资产记录每个 Genesis NFT 的应得份额。Holder 主动 Claim 时，Reward Vault 才将资产转入该 NFT 对应的 ERC-6551 TBA，从而避免随 NFT 数量增长而产生大规模循环转账。

```text
Fee Engine
  ↓
Reward Strategy
  ↓
Reward Asset
  ↓
Reward Vault + Genesis Accounting
  ↓
Holder Claim
  ↓
ERC-6551 TBA
```

### Balance Vault

Balance Vault 负责协议自动调节，目标是长期保持 NFT 占 60%～70%、FT 占 30%～40%。Vault 不固定发放奖励，奖励完全根据当前 Treasury 余额以及 NFT/FT 的偏离程度动态计算。

Treasury 越大，奖励越高；Treasury 越小，奖励自动下降。这样可以让 Treasury 持续运行，不会因长期补贴而耗尽。Balance Vault 可根据市场状态鼓励 `NFT → FT` 或 `FT → NFT`，形成协议自动稳定器。

### Protocol Vault

Protocol Vault 作为协议长期收入，主要用于：

- 开发
- Audit
- 基础设施
- Indexer
- 前端
- 运营
这可以保证协议得到持续维护。

### Reward Strategy Engine

Genesis 收益通过可插拔 Reward Strategy 转换为目标 Reward Asset，核心 NFT/FT 转换逻辑不依赖具体买入资产。

```text
RewardStrategyManager
├── HoldETHStrategy（已实现）
└── IRewardStrategy 扩展（如 BuyFlux、BuyERC20 等）
```

可拆分资产使用按份额记账与 Claim；不可拆分 NFT 不直接平均分割，而通过独立 Strategy（抽取、拍卖或 NFT Vault 等）处理。

### Reward Asset Registry

Reward Asset Registry 管理协议允许分发和自动清算的奖励资产。Registry 为 Claim、Accounting 和 Burn Settlement 提供有限、可枚举的资产集合，防止系统尝试扫描 TBA 中未知的任意 Token。

---

## 15. Economic Flywheel

```text
CCA Auction
  ↓
Price Discovery
  ↓
FLUX / ETH LP
  ↓
ERC-20 Trading
  ↓
Protocol Fee
  ↓
Fee Engine
  ├── Liquidity Vault → 更深 LP → 更稳定价格
  ├── Reward Strategy → Reward Vault → ERC-6551 TBA
  └── Balance Vault → Dynamic Incentive → NFT / FT Balance
                                              ↓
                                          更多交易
                                              ↓
                                           更多 Fee
                                              ↓
                                         协议持续增长
```

协议由此形成完整的经济闭环。

---

## 16. Core Innovations

相比传统 NFT，本协议的主要创新包括：

- Asset 双形态（NFT / FT）
- Credit 状态（Genesis）
- Trait Random Re-Mint
- CCA Fair Launch
- 50/50 Genesis Distribution
- Protocol-Owned Liquidity Bootstrap
- Genesis NFT 永久现金流权益
- ERC-6551 Token Bound Account
- Reward Asset Portfolio
- 可插拔 Reward Strategy Engine
- Reward Asset Registry 与原子化 Burn Settlement
- Pull-based 多资产奖励记账
- 双向动态费率
- 自动平衡引擎（Balance Engine）
- 四层 Vault 收益分配模型

