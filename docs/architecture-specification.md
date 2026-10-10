# Flux Protocol Architecture Specification

## 1. Architecture Goal

本架构描述 Flux Protocol 的模块划分与职责边界（Foundry + Solidity）。

核心目标：

- 明确每个合约的职责。
- 防止模块之间重复修改状态。
- 保证 Asset 总量守恒。
- 保证 Genesis、NFT、FT、Fee、Vault 各模块解耦。
- 尽量减少可升级性与跨模块复杂度。

核心设计原则：

> Asset 状态变化必须集中处理，资金分配与奖励会计必须集中处理，随机 Trait 必须集中处理，Token Bound Account 的执行与结算必须经过受控模块。

---

## 2. High-Level Architecture

整体架构由核心资产层以及 Token Bound Account、Reward Strategy 等扩展层组成：

```text
┌──────────────────────────────┐
│        Genesis Layer         │
│  CCA Auction / Credit        │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│         Asset Layer          │
│ AssetRegistry / State Model  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│      Representation Layer    │
│     FLUX ERC20 / NFT ERC721   │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│   Token Bound Account Layer  │
│ ERC-6551 Registry / Account  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│      Conversion Engine       │
│ NFT ⇄ FT / Credit Materialize│
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│        Economic Layer        │
│ Fee Engine / Balance Engine  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│          Vault Layer         │
│ LP / Reward / Balance / Dev  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│        Reward Layer          │
│ Strategy / Registry / Claim  │
└──────────────────────────────┘
```

Trait Engine 为 NFT Layer 提供随机 Trait 和 Metadata。

---

## 3. Core Contracts

### 3.1 AssetRegistry

AssetRegistry 是整个协议的真实状态源。它不负责 ERC-20 或 ERC-721 转账，只负责记录：

```solidity
enum AssetState {
    Uninitialized,
    Credit,
    GenesisNFT,
    NFT,
    FT
}
```

推荐维护以下数据结构：

```solidity
struct AssetData {
    AssetState state;
    bool genesis;
    uint256 tokenId;
}
```

Asset Unit 总量为：

```solidity
uint256 public constant MAX_ASSETS = 10_000;
```

必须保证：

```text
Credit Units + Genesis NFT Units + Normal NFT Units + FT Equivalent Units = 10,000
```

其中：

```text
FT Equivalent Units = FLUX.totalSupply() / 10_000e18
```

AssetRegistry 只允许 `ConversionEngine` 和 `GenesisAuction` 修改状态。任何 NFT/FT 合约都不得自行修改 AssetRegistry。

---

## 4. Genesis Layer

### 4.1 GenesisAuction

GenesisAuction 负责整个协议的启动。Genesis 固定包含 `10,000 Asset Units`，拆分为：

```text
5,000 CCA Credits
5,000 LP Reserve
```

GenesisAuction 负责：

- 初始化 CCA。
- 接收 ETH Bid。
- 记录 Max Price。
- 计算清算结果。
- Finalize Auction。
- 发放 Credit。
- 将 5,000 LP Asset Units 转换成 50,000,000 FLUX。
- 创建 Uniswap LP。
- 将 LP Position 移交 LiquidityVault。

GenesisAuction 完成后永久失效，其状态定义如下：

```solidity
enum GenesisState {
    Pending,
    Active,
    Finalized
}
```

Finalized 后，所有 Genesis 写操作永久关闭：

```solidity
require(state == GenesisState.Finalized);
```

### 4.2 CreditManager

Credit 以内部账本记录，不作为自由流通的 ERC-20。Credit 表示 Genesis 阶段尚未具现化的 Asset Unit 权利，不会在协议中长期作为第三种可交易资产存在。

```solidity
mapping(address => uint256) creditBalance;
```

CreditManager 只支持：

```solidity
creditBalance(address)
materializeToGenesisNFT(uint256 amount)
materializeToFT(uint256 amount)
```

Credit 使用后永久销毁。

---

## 5. Representation Layer

### 5.1 FluxToken

FluxToken 为标准 ERC-20，继承 `ERC20` 与 `ERC20Permit`，不包含 Votes / Snapshot 扩展。仅 ConversionEngine、GenesisAuction 及授权模块可调用 `mint()` / `burn()`，用户不能自行 Mint。

核心常量：

```solidity
uint256 public constant UNIT = 10_000e18;
```

理论最大供应量为 `100_000_000e18`，但实际 `totalSupply` 会动态变化。

### 5.2 DynamicNFT

协议使用统一的 ERC-721 合约。Genesis NFT 与普通 NFT 通过 metadata flag 区分：

```solidity
struct NFTData {
    bool genesis;
    bool alive;
    uint256 traitSeed;
}
```

相比 GenesisNFT.sol 与 DynamicNFT.sol 两套 ERC-721，统一合约具有以下优势：

- OpenSea Collection 统一。
- Marketplace 统一。
- tokenId 空间统一。
- 避免重复 ERC-721 逻辑。

Genesis NFT 使用 `genesis = true`，普通重新生成的 NFT 使用 `genesis = false`。Genesis NFT Burn 后，Genesis Right 永久消失；以后重新 Mint 只能生成普通 NFT。

整个 Collection 都支持 ERC-6551，但只有 Genesis NFT 自动获得协议手续费权。NFT Mint 时不要求立即部署 TBA；账户地址通过 ERC6551Registry 确定性计算，并在首次 Claim 或主动使用时创建。

### 5.3 ERC-6551 Account Layer

每个 NFT 对应一个 Token Bound Account（TBA），使 NFT 能够持有 ETH、ERC-20 及 RewardAssetRegistry 登记的奖励资产。该层包含：

- **ERC6551Registry**：确定性创建和计算 TBA 地址。
- **FluxAccount**：TBA 的账户实现，验证 NFT Owner 的执行权限。
- **AccountManager**：封装账户创建、Claim、Sweep 和 Burn Settlement。
- **RewardAssetRegistry**：保存协议可分发、可自动清算的有限资产集合。

TBA 的控制权随 NFT 所有权变化。协议只能自动枚举和清算 RewardAssetRegistry 中登记的资产；用户自行转入的未登记资产由用户负责在 Burn 前处理。

Genesis NFT 的价值结构为：

```text
Identity + Trait + TBA Assets + Genesis fee share
```

---

## 6. Trait Layer

### 6.1 TraitGenerator

TraitGenerator 的职责包括：

- 接收随机种子。
- 生成 Trait。
- 验证 Trait 权重。
- 输出 TraitData。

例如：

```solidity
struct TraitData {
    uint16 background;
    uint16 body;
    uint16 eyes;
    uint16 hair;
    uint16 accessory;
}
```

随机数通过 `IRandomProvider` 注入：主网目标为 `ChainlinkVRFRandomProvider`；测试网与本地可使用 `SyncVRFRandomProvider` 或 `MockRandomProvider`。TraitGenerator 不负责 Mint NFT，只负责生成 Trait 并写入 TraitStorage。

### 6.2 TraitStorage

TraitStorage 负责：

- Trait 类型。
- Trait 权重。
- Trait 最大供应量。
- Trait 当前供应量。
- Trait 组合约束。

例如：

```solidity
mapping(uint256 => uint256) traitMaxSupply;
mapping(uint256 => uint256) traitCirculating;
```

Trait 与 Asset ID 绑定存储。NFT Burn 时 TraitStorage 释放该 Asset 的 Trait 占用；再次 Mint 时为同一 Asset 重新 roll Trait，在协议规则内完成 Trait 空间的循环利用。

### 6.3 TraitRenderer

TraitRenderer 只负责实现：

```solidity
tokenURI(tokenId)
```

它根据 TraitData 输出 JSON Metadata、Base64 SVG 和 Attributes，不应保存业务状态。

---

## 7. Conversion Engine

ConversionEngine 是整个协议最重要的合约，所有状态转换都必须经过它。支持以下四条路径：

```text
Credit → Genesis NFT
Credit → FLUX
NFT → FLUX
FLUX → NFT
```

### 7.1 Credit → Genesis NFT

接口：

```solidity
materializeGenesisNFT(uint256 amount)
```

流程：

1. Burn Credit。
2. 从 AssetRegistry 分配 Asset Unit。
3. 调用 TraitGenerator。
4. Mint Genesis NFT。
5. 标记 `genesis = true`。
6. 更新 AssetRegistry。
7. Emit event。

### 7.2 Credit → FT

接口：

```solidity
materializeFT(uint256 amount)
```

流程：

1. Burn Credit。
2. 每个 Credit Mint 10,000 FLUX。
3. 将 AssetRegistry 状态从 Credit 更新为 FT。
4. Emit event。

### 7.3 NFT → FT

接口：

```solidity
nftToFT(uint256 tokenId)
```

流程：

1. 检查 Owner。
2. 读取当前 NFT/FT Ratio。
3. 由 BalanceEngine 计算 Fee/Reward。
4. 处理 Fee。
5. 如果是 Genesis NFT，先结算尚未 Claim 的已归属奖励。
6. 通过 AccountManager 将 TBA 中登记的 ETH/ERC-20 资产原子化 Sweep 给当前 Owner。
7. 确认登记资产结算完成。
8. Burn NFT，并将 Trait 返回 TraitPool。
9. Mint 10,000 FLUX。
10. 如果是 Genesis NFT，永久销毁 Genesis Right，减少 `activeGenesisSupply`，并停止后续收益权。
11. 将 AssetRegistry 状态从 NFT 更新为 FT。
12. 如果存在 Balance Reward，由 BalanceVault 支付奖励。
13. Emit event。

ConversionEngine 不得尝试扫描 TBA 中的任意 Token。Burn Settlement 仅遍历 RewardAssetRegistry；未登记资产的管理责任属于用户。

### 7.4 FT → NFT

接口：

```solidity
ftToNFT()
```

流程：

1. 检查用户余额是否不低于 10,000 FLUX。
2. 由 BalanceEngine 计算 Fee/Reward。
3. Burn 10,000 FLUX。
4. 处理 Fee。
5. 从 TraitPool 抽取 Trait。
6. Mint 普通 NFT。
7. 将 AssetRegistry 状态从 FT 更新为 NFT。
8. 如果存在 Reward，由 BalanceVault 支付奖励。
9. Emit event。

> FT → NFT 永远只能生成普通 NFT；Genesis NFT 永远不能重新生成。

---

## 8. Balance Engine

BalanceEngine 不持有资金，只负责数学计算。

输入：

```solidity
currentFTUnits
currentNFTUnits
balanceVaultBalance
direction
```

输出：

```solidity
struct Quote {
    uint256 fee;
    uint256 reward;
}
```

目标中性区为 FT 占 30%～40%、NFT 占 60%～70%。具体逻辑如下：

### FT > 40%

鼓励 `FT → NFT`：

```text
FT → NFT fee = 0
FT → NFT reward > 0
NFT → FT fee > 0
```

### FT = 30%～40%

处于中性区：

```text
fee ≈ 0
reward = 0
```

### FT < 30%

鼓励 `NFT → FT`：

```text
NFT → FT fee = 0
NFT → FT reward > 0
FT → NFT fee > 0
```

---

## 9. Reward Budget Model

BalanceVault 奖励不能无限释放。每日预算按 Vault 余额比例封顶：

```solidity
dailyBudget = balanceVaultBalance * dailyReleaseBps / 10_000;
```

例如，当 `dailyReleaseBps = 10` 时，每天最多释放 BalanceVault 的 0.1%。奖励函数为：

```text
Reward Weight = Deviation × Direction Weight
```

例如，FT Target Center 为 35%，FT 当前占比为 50%，则 Deviation 为 15%。偏差越大，奖励权重越高，但当天总奖励不能超过 `dailyBudget`。

以一天为一个 Epoch，并记录：

```solidity
epochBudget
epochSpent
```

---

## 10. Fee Engine

所有 Fee 都进入 FeeEngine，来源包括：

1. Conversion Fee。
2. Uniswap LP Fee。
3. NFT Marketplace Royalty / Protocol Fee。

Marketplace Fee 不一定能够强制执行。ERC-721 Royalty 使用 ERC-2981，但 OpenSea 等市场是否执行 Royalty 取决于 Marketplace。因此，在架构上 Marketplace Fee 只能作为可选收入来源，不能作为维持协议稳定性的必要收入。

---

## 11. Fee Distribution

FeeEngine 将收入分配至四个 Vault：

```text
Liquidity Vault
Reward Strategy / Genesis Accounting
Balance Vault
Protocol Vault
```

Genesis 分配不直接循环转账给 NFT Holder。FeeEngine 将该部分资金交给 RewardStrategyManager；策略执行后，目标资产进入 RewardVault，并由 GenesisVault 更新多资产奖励会计。

```text
FeeEngine
  ↓
RewardStrategyManager
  ↓
Reward Asset
  ↓
RewardVault
  ↓
GenesisVault Accounting
  ↓
Claim → ERC-6551 TBA
```

分配比例使用以下结构保存：

```solidity
struct FeeSplit {
    uint16 liquidityBps;
    uint16 genesisBps;
    uint16 balanceBps;
    uint16 protocolBps;
}
```

所有比例之和必须等于 `10,000 BPS`。默认分配为：

```text
Liquidity  30%
Genesis    25%
Balance    25%
Protocol   20%
```

这些参数必须可配置。

---

## 12. Liquidity Vault

LiquidityVault 负责：

- 持有 Genesis Uniswap LP Position。
- 收取 LP Fees。
- 将一部分新 Fee 继续添加到 FLUX/ETH LP。
- 防止项目方提走核心 LP。

Genesis LP Position 永久锁定，后续新增 LP 允许自动 Compound。LiquidityVault 只允许 FeeEngine 和 Authorized LP Manager 调用。

---

## 13. Genesis Vault

GenesisVault 负责 Genesis NFT 的多资产手续费分成，采用 Pull-based Accounting，不在收入发生时遍历全部 NFT。记账采用类似 MasterChef 的 `accRewardPerShare` 模式：

```solidity
mapping(address rewardAsset => uint256) public accRewardPerGenesis;
mapping(uint256 tokenId => mapping(address rewardAsset => uint256)) public rewardDebt;
```

有效 Genesis NFT 数量记录为 `activeGenesisSupply`。如果 Genesis NFT 被 Burn，则执行：

```text
activeGenesisSupply -= 1
```

后续 Fee 只由剩余 Genesis NFT 分享。Genesis 权益随 NFT 所有权转移；NFT 转让后，新 Owner 获得后续收益。Holder 调用 `claim(tokenId, rewardAsset)` 时，RewardVault 将奖励转入该 tokenId 对应的 TBA。

### 13.1 RewardStrategyManager

RewardStrategyManager 通过白名单 Adapter 将 ETH/WETH 等输入资产转换为目标 Reward Asset。当前实现包含 `HoldETHStrategy`；其他策略通过 `IRewardStrategy` 扩展。每个 Strategy 必须配置允许的输入/输出资产、最大滑点、路由与执行权限。

不可拆分 NFT 不进入普通 `accRewardPerShare` 会计，应通过独立的抽取、拍卖或 NFT Vault 策略处理。

### 13.2 RewardVault and RewardAssetRegistry

RewardVault 统一持有尚未 Claim 的奖励资产，只允许 GenesisVault、受控 Strategy 和 AccountManager 调用。RewardAssetRegistry 保存协议支持的奖励资产、资产类型、启用状态及 Settlement Adapter，并为以下操作提供可枚举边界：

- 多资产奖励会计。
- Claim 到 ERC-6551 TBA。
- Genesis NFT Burn 前的自动结算。
- 紧急停用有风险的 Reward Asset。

---

## 14. Protocol Vault

ProtocolVault 用于接收开发者收益，只允许 Multisig 提取，并支持 Timelock。它不允许修改 Asset Supply。Admin 与 Treasury 采用 `Safe Multisig + Timelock`。

---

## 15. External Integrations

### Uniswap

Genesis Finalize 通过 `ILiquidityMigrator` 创建 FLUX/ETH 流动性（可配置 Uniswap v4 Migrator、Flux Hackathon AMM / V2 风格 Migrator，或测试用 Mock）。Runtime 交易与协议费经 `FluxSwapRouter` 等集成模块进入 FeeEngine；LiquidityVault 的 LP 复投由 `ILiquidityAdapter` 对接链上 Router 或 Mock Adapter。

### Chainlink VRF

Trait Randomness 需要抽象接口 `IRandomProvider`，并提供以下实现：

```text
ChainlinkVRFProvider
MockRandomProvider
```

---

## 16. Access Control

协议定义以下角色：

```solidity
DEFAULT_ADMIN_ROLE
AUCTION_ROLE
CONVERSION_ROLE
FEE_MANAGER_ROLE
TRAIT_MANAGER_ROLE
REWARD_MANAGER_ROLE
STRATEGY_EXECUTOR_ROLE
ACCOUNT_MANAGER_ROLE
PAUSER_ROLE
```

正式部署时，Admin 应使用 Timelock，而不是 EOA。

---

## 17. Emergency Control

Pausable 必须支持分别暂停以下模块：

- Auction
- Conversion
- Random Mint
- Fee Distribution
- Reward Strategy
- Reward Claim
- TBA Burn Settlement

Pause 按模块独立控制，避免单一全局 Pause 锁死全部功能：

```solidity
mapping(bytes32 => bool) pausedModule;
```

---

## 18. Invariants

Foundry Invariant Test 必须覆盖以下不变量：

1. Asset 总量永远为 `10,000`。
2. 以下等式始终成立：

   ```text
   NFT Units + Credit Units + FLUX totalSupply / 10,000 = 10,000
   ```

3. Genesis NFT Burn 后，永远无法再次创建 Genesis Right。
4. FLUX 只能通过 Genesis LP、`Credit → FT` 和 `NFT → FT` 产生。
5. 普通 NFT 只能通过 `FT → NFT` 产生。
6. 所有 FeeSplit 之和必须为 100%。
7. BalanceVault 单个 Epoch 的奖励必须满足 `reward <= epochBudget`。
8. Genesis NFT Burn 完成后，对应 Genesis Right 永远不可恢复，且该 tokenId 不再参与后续奖励累计。
9. Burn Settlement 完成时，RewardAssetRegistry 中所有登记资产的 TBA 余额必须已转给 Burn 发起时的 NFT Owner。
10. RewardVault 的已记账负债不得超过其对应 Reward Asset 的可用余额。
11. 单次 Reward Strategy 执行不得输出未在 RewardAssetRegistry 登记的资产。

---

## 19. Foundry Project Structure

```text
src/
├── core/
│   ├── AssetRegistry.sol
│   ├── ConversionEngine.sol
│   └── CreditManager.sol
├── token/
│   ├── FluxToken.sol
│   └── DynamicNFT.sol
├── account/
│   ├── FluxAccount.sol
│   ├── AccountManager.sol
│   └── IERC6551Account.sol
├── genesis/
│   └── GenesisAuction.sol
├── trait/
│   ├── TraitStorage.sol
│   ├── TraitGenerator.sol
│   ├── TraitRenderer.sol
│   └── IRandomProvider.sol
├── economic/
│   ├── FeeEngine.sol
│   ├── BalanceEngine.sol
│   ├── FeeCurve.sol
│   ├── GenesisVault.sol
│   ├── RewardVault.sol
│   ├── RewardAssetRegistry.sol
│   └── RewardStrategyManager.sol
├── strategy/
│   ├── IRewardStrategy.sol
│   ├── HoldETHStrategy.sol
│   ├── BuyFluxStrategy.sol
│   └── BuyERC20Strategy.sol
├── vault/
│   ├── LiquidityVault.sol
│   ├── BalanceVault.sol
│   └── ProtocolVault.sol
├── integration/
│   ├── UniswapAdapter.sol
│   └── ChainlinkVRFProvider.sol
└── interfaces/
```

测试目录：

```text
test/
├── unit/
├── integration/
├── fuzz/
└── invariant/
```

脚本目录：

```text
script/
├── Deploy.s.sol
├── StartAuction.s.sol
├── FinalizeAuction.s.sol
└── ConfigureProtocol.s.sol
```

---

## 20. Implementation Constraints

实现时必须遵循以下规则：

1. 不允许在多个合约中重复维护 Asset Supply。
2. AssetRegistry 是状态唯一来源。
3. ConversionEngine 是 Asset 状态转换的唯一入口。
4. Token 合约只能接受授权 Mint/Burn。
5. FeeEngine 是 Fee 分发的唯一入口。
6. BalanceEngine 不持有资金，只负责计算。
7. Vault 不允许直接 Mint/Burn NFT 或 FLUX。
8. Trait 模块不能修改经济状态。
9. External Integration 必须通过 Adapter。
10. 所有核心参数必须使用 BPS。
11. 不允许使用浮点数。
12. 必须优先使用 Custom Error。
13. 所有 External Call 遵循 CEI。
14. 所有 ETH Transfer 使用 `call`，不使用 `transfer`。
15. Foundry Tests 必须先编写核心 Invariant，再编写完整功能测试。
16. 核心合约以非可升级部署为主。
17. Governance 权限收敛到必要模块；Admin 使用 Multisig + Timelock。
18. Genesis Finalize 后，Auction 合约不可重新启动。
19. Reward 分发必须采用 Pull-based Accounting，不允许按 NFT 总量执行循环转账。
20. TBA Burn Settlement 只能遍历 RewardAssetRegistry 中登记的资产。
21. 未登记的 TBA 资产不得被协议静默销毁或视为已结算。
22. Reward Strategy 必须通过 Adapter 隔离，并执行白名单、滑点和最小输出检查。
23. Genesis NFT Burn 必须在同一交易中完成已归属奖励结算、登记资产 Sweep、NFT Burn、FLUX Mint 和 Genesis Right 销毁。

---

## 21. Final Architecture Principle

整个协议可以归纳为：

```text
AssetRegistry    决定资产是什么
ConversionEngine 决定资产如何改变状态
TraitEngine      决定 NFT 长什么样
AccountManager   决定 TBA 如何创建、执行和结算
BalanceEngine    决定什么时候应该鼓励哪种状态
FeeEngine        决定资金流向哪里
RewardStrategy   决定 Genesis 收益转换成什么资产
GenesisVault     决定多资产奖励如何记账
Vaults           负责真正持有资产和收益
```

任何新功能都必须遵循以上边界。如果一个新模块既修改 Asset 状态，又分配资金，还生成 Trait，则说明模块职责设计错误，应重新拆分。
