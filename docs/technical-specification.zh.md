# Flux Protocol Smart Contract Technical Specification

English: [technical-specification.md](./technical-specification.md)

## 1. Project Goal

实现 Flux Protocol：一个支持 NFT（ERC-721）与 FT（ERC-20）双向转换，并为 NFT 提供 ERC-6551 Token Bound Account 和多资产奖励能力的协议。

协议要求：

- 固定 Asset 总量。
- Genesis Auction（CCA）。
- Genesis NFT。
- ERC-20 流动性。
- 动态手续费。
- Fee Engine。
- 四层 Vault。
- Trait Engine。
- ERC-6551 Registry 与 Token Bound Account。
- Reward Strategy、Reward Vault 与 Reward Asset Registry。
- Genesis NFT 原子化 Burn Settlement。
- 使用 Foundry 开发。
- 使用 OpenZeppelin 合约库。

技术栈：

- **Solidity**：`>=0.8.26`
- **Framework**：Foundry

---

## 2. Repository Structure

```text
src/
├── core/
│   ├── AssetRegistry.sol
│   ├── GenesisAuction.sol
│   ├── CreditManager.sol
│   ├── DynamicNFT.sol
│   ├── FluxToken.sol
│   └── ConversionEngine.sol
├── account/
│   ├── FluxAccount.sol
│   ├── AccountManager.sol
│   └── IERC6551Account.sol
├── fee/
│   ├── FeeEngine.sol
│   ├── LiquidityVault.sol
│   ├── GenesisVault.sol
│   ├── RewardVault.sol
│   ├── RewardAssetRegistry.sol
│   ├── RewardStrategyManager.sol
│   ├── BalanceVault.sol
│   └── ProtocolVault.sol
├── strategy/
│   ├── IRewardStrategy.sol
│   ├── HoldETHStrategy.sol
│   ├── BuyFluxStrategy.sol
│   └── BuyERC20Strategy.sol
├── trait/
│   ├── TraitStorage.sol
│   ├── TraitGenerator.sol
│   └── TraitRenderer.sol
├── math/
│   ├── FeeCurve.sol
│   └── RewardCurve.sol
├── interfaces/
└── libraries/
script/
test/
deploy/
```

---

## 3. Core Contracts

### GenesisAuction

GenesisAuction 负责 Genesis Auction，功能包括：

- 创建 Auction。
- 接收 ETH。
- 处理 CCA Bid。
- 完成 Price Discovery。
- Finalize Auction。
- 分发 Credit。
- 初始化 LP。

状态定义：

```solidity
enum AuctionState {
    Pending,
    Active,
    Finished
}
```

主要接口：

```solidity
createAuction()
bid()
cancelBid()
settle()
claimCredit()
initializeLP()
```

### CreditManager

CreditManager 负责管理 Genesis Credit。Credit 不可再次发行；Genesis 完成以后，其总量固定为 `5,000`。

接口：

```solidity
claimNFT()
claimFT()
burnCredit()
```

### DynamicNFT

DynamicNFT 是统一的 ERC-721 Collection，同时承载 Genesis NFT 与普通 NFT。两者通过 `genesis` 标记区分，包含 Trait、Metadata、Random Mint 和 ERC-6551 Account 地址查询。

```solidity
struct NFTData {
    bool genesis;
    bool alive;
    uint256 traitSeed;
}
```

接口：

```solidity
mint()
burn()
tokenURI()
traits()
reroll()
isGenesis()
account(uint256 tokenId)
```

所有 NFT 都支持 ERC-6551，但只有 Genesis NFT 参与协议奖励。Genesis NFT Burn 后，Genesis Right 永久消失，重新 Mint 也不会恢复。

### ERC6551Registry / FluxAccount

ERC6551Registry 根据 NFT 合约、tokenId、Chain ID、Salt 和 Account Implementation 确定性创建 TBA。FluxAccount 验证当前 NFT Owner，并允许其管理账户资产。Mint 时不强制部署账户；首次 Claim 或使用时再创建。

主要接口：

```solidity
account(address nft, uint256 tokenId)
createAccount(address nft, uint256 tokenId)
execute(address target, uint256 value, bytes calldata data)
```

### AccountManager

AccountManager 是协议操作 TBA 的受控入口，负责 Claim、Sweep 和 Genesis Burn Settlement。它只能自动处理 RewardAssetRegistry 中登记的资产。

```solidity
ensureAccount(uint256 tokenId)
claimToAccount(uint256 tokenId, address rewardAsset)
sweepRegisteredAssets(uint256 tokenId, address recipient)
settleBeforeBurn(uint256 tokenId, address recipient)
```

### FluxToken

FluxToken 是 ERC-20，固定兑换规则为：

```text
1 NFT = 10,000 FLUX
```

FluxToken 继承 `ERC20Permit`，不包含 Votes / Snapshot 扩展。

### ConversionEngine

ConversionEngine 是协议最核心的模块，负责 `NFT ⇄ FT` 转换。

接口：

```solidity
nftToFT()
ftToNFT()
previewFee()
previewReward()
currentRatio()
```

ConversionEngine 必须保证 Asset 总量守恒。

Genesis NFT 的 `nftToFT()` 必须按以下顺序原子化执行：

1. 锁定 Burn 发起时的 NFT Owner。
2. 结算该 tokenId 尚未 Claim 的已归属奖励。
3. 通过 AccountManager 将 TBA 中所有登记资产 Sweep 给该 Owner。
4. 确认登记资产结算完成。
5. Burn NFT 并归还 Trait。
6. Mint 10,000 FLUX 给 Owner。
7. 永久销毁 Genesis Right，并减少 `activeGenesisSupply`。
8. 更新 AssetRegistry 并 Emit event。

任一步失败都必须 Revert 整个交易。未登记资产不在自动结算范围内，协议不得将其视为已经清空。

---

## 4. Genesis Flow

初始化 `10,000 Asset Units`，拆分为：

```text
10,000 Asset Units
├── 5,000 → Credit Auction
└── 5,000 → LP Reserve
```

LP Reserve 自动 Mint `50,000,000 FLUX`。Auction 结束后，使用 Auction ETH 和 `50,000,000 FLUX` 创建 Uniswap LP：

```text
Auction ETH + 50,000,000 FLUX → Uniswap LP
```

LP 永久锁定，Auction 用户获得 Credit。

---

## 5. Asset State Machine

```text
Credit
  ↓
Genesis NFT
  ↓
FLUX
  ↓
Random NFT
  ↓
FLUX
  ↓
Random NFT
```

Genesis NFT 被 Burn 前必须执行 TBA Settlement；Burn 后将永久失去 Genesis Right。普通 NFT 也可以拥有 TBA，但不参与 Genesis 奖励。

---

## 6. Trait Engine

Trait 不直接写在代码中，而是保存在 Storage 中并随机生成，包括：

```text
Background
Body
Eyes
Hair
Accessory
```

Trait Generator 支持 Weighted Random，并提供以下接口：

```solidity
generate()
reroll()
randomSeed()
```

Trait 随机数通过 `IRandomProvider` 注入；部署时可选用 `ChainlinkVRFRandomProvider`、`SyncVRFRandomProvider` 或 `MockRandomProvider`。

---

## 7. Fee Engine

协议的所有手续费统一进入 Fee Engine，来源包括：

1. Swap Fee。
2. Marketplace Fee。
3. NFT / FT Conversion Fee。

Fee Engine 负责统一分发这些收入。Genesis 分配先进入 Reward Strategy，而不是直接向 Holder 钱包推送 ETH：

```text
Fee Engine
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

---

## 8. Vaults

Fee 分配至四个 Vault：

```text
Fee
├── Liquidity Vault
├── Reward Strategy / Genesis Accounting
├── Balance Vault
└── Protocol Vault
```

各 Vault 的分配百分比允许由 Governance 修改。

### Liquidity Vault

Liquidity Vault 用于持续增加 FLUX/ETH LP。

接口：

```solidity
addLiquidity()
pendingLiquidity()
```

### Genesis Vault

Genesis Vault 为 Genesis NFT 提供多资产永久现金流。Genesis NFT 被 Burn 后将永久失去未来收益，收益按当前有效 Genesis NFT 数量平均分配。系统使用 `accRewardPerShare + rewardDebt` 实现 Pull-based Accounting，不允许在收入发生时遍历全部 NFT。

接口：

```solidity
deposit(address rewardAsset, uint256 amount)
claim(uint256 tokenId, address rewardAsset)
claimAllRegistered(uint256 tokenId)
pending(uint256 tokenId, address rewardAsset)
```

Claim 的接收地址必须是 tokenId 对应的 TBA。Genesis NFT 转让后，未来收益权与 TBA 控制权一并转移。

### Reward Vault

Reward Vault 持有尚未 Claim 的奖励资产，并保证每种资产的余额不低于已记账负债。

```solidity
depositFromStrategy(address rewardAsset, uint256 amount)
payToAccount(uint256 tokenId, address rewardAsset, uint256 amount)
available(address rewardAsset)
liability(address rewardAsset)
```

### Reward Strategy Manager

Reward Strategy Manager 通过白名单 Adapter 将输入资产转换为 Reward Asset。当前实现包含 `HoldETHStrategy`；其他策略通过 `IRewardStrategy` 与 Adapter 扩展接入。

```solidity
executeStrategy(bytes32 strategyId, uint256 amountIn, uint256 minAmountOut)
setStrategy(bytes32 strategyId, address adapter)
pauseStrategy(bytes32 strategyId)
```

所有 Strategy 必须检查最大滑点、最小输出、Deadline、输入/输出资产白名单和调用权限。不可拆分 NFT 不使用普通按份额会计，必须由独立的抽取、拍卖或 NFT Vault Strategy 处理。

### Reward Asset Registry

Reward Asset Registry 保存协议支持的奖励资产以及 Burn Settlement 所需的枚举信息。

```solidity
registerAsset(address asset, AssetType assetType, address settlementAdapter)
disableAsset(address asset)
isRegistered(address asset)
registeredAssets()
```

自动 Claim 与 Burn Settlement 仅覆盖 RewardAssetRegistry 登记的 Native ETH/WETH 与 ERC-20。用户自行转入 TBA 的未登记资产由用户自行管理。

### Balance Vault

Balance Vault 负责协议平衡，目标比例为：

```text
NFT：60%～70%
FT： 30%～40%
```

Reward 根据 Treasury 余额动态计算，不得超发。

接口：

```solidity
reward()
dailyBudget()
remainingBudget()
currentTarget()
```

### Protocol Vault

Protocol Vault 用于接收协议收入，主要用于协议维护，并支持 MultiSig。

接口：

```solidity
withdraw()
setRecipient()
```

---

## 9. Dynamic Balance Engine

Dynamic Balance Engine 负责维护 NFT/FT 比例，目标区间为：

```text
NFT：60%～70%
FT： 30%～40%
```

协议维护 Neutral Zone，例如 FT 占 30%～40% 时，双向转换均采用低费率。超过该区间后，动态提高对应方向的转换成本。

---

## 10. Fee Curve

Fee Curve 采用连续函数，不使用阶梯函数。

接口：

```solidity
calculateFee()
calculateReward()
```

输入：

```text
Current FT Ratio
Current Treasury
Target Ratio
```

输出：

```text
Fee
Reward
```

Fee Curve 支持未来升级。

---

## 11. Metadata

NFT Metadata 完全上链，SVG 在链上生成，并支持 Trait Renderer。

---

## 12. Security

- 所有状态变更采用 Checks-Effects-Interactions 模式。
- 使用 ReentrancyGuard。
- ERC-20 支持 Permit。
- ERC-721 使用 ERC721A（如适用）或 OpenZeppelin ERC721。
- 权限控制使用 AccessControl。
- 暂停机制使用 Pausable。
- FluxAccount 必须验证 NFT 当前 Owner，防止旧 Owner 在转让后继续执行。
- AccountManager 只允许 ConversionEngine 和 GenesisVault 调用受控结算接口。
- Burn Settlement 必须防重入，并在外部转账前锁定 Owner 与结算状态。
- Reward Strategy 必须使用资产白名单、滑点保护、Deadline 和最小输出检查。
- 核心合约以非可升级部署为主。

---

## 13. Events

必须包含以下事件：

```solidity
AuctionCreated
BidPlaced
AuctionFinalized
CreditClaimed
GenesisMinted
NFTMinted
NFTBurned
FTMinted
FTBurned
RewardClaimed
RewardAssetRegistered
RewardStrategyExecuted
TokenBoundAccountCreated
AccountAssetSwept
GenesisBurnSettled
LiquidityAdded
FeeDistributed
```

---

## 14. Testing

Foundry 测试覆盖率要求高于 95%，测试范围包括：

- Genesis。
- CCA。
- Random Trait。
- NFT Burn。
- NFT Mint。
- FT Mint。
- FT Burn。
- Fee。
- Vault。
- Reward。
- ERC-6551 Account 权限与确定性地址。
- 多 Reward Asset Accounting。
- Claim 到 TBA。
- Genesis Burn 原子化 Settlement。
- Reward Strategy 滑点和恶意 Adapter。
- LP。

Invariant Test 必须保证 Asset 总量永远为 `10,000`，并覆盖以下附加不变量：

- Burn 后 Genesis Right 永远不可恢复。
- Burn Settlement 后，所有登记资产已经转给 Burn 发起时的 Owner。
- RewardVault 的资产余额始终覆盖对应会计负债。
- Reward Strategy 不得输出未登记资产。
- 收入分配与 Claim 不得随 NFT 总量执行无界循环。

Fuzz Test 应覆盖转换、连续 Burn、连续 Mint 和连续 Swap，并始终保证 Supply 正确。

---

## 15. Deployment

使用 Foundry Script，并按照以下顺序部署：

```text
Vaults
  ↓
ERC-20
  ↓
ERC-721
  ↓
ERC-6551 Registry / Account
  ↓
Trait Engine
  ↓
Reward Asset Registry / Vaults
  ↓
Reward Strategies
  ↓
Fee Engine
  ↓
Conversion Engine
  ↓
Genesis Auction
  ↓
Initialize
```

---

## 16. Development Rules

1. 所有核心参数必须通过 Config 管理，不得 Hardcode。
2. 所有比例必须支持 Governance 修改。
3. 所有数学运算统一由 Math Library 处理。
4. 所有随机数统一由 Trait Generator 处理。
5. 所有 Fee 统一由 Fee Engine 处理。
6. 所有资产转换统一由 Conversion Engine 处理。
7. 任何模块都不得直接修改 ERC-20、ERC-721 或 Supply，只能通过 Conversion Engine 统一管理。
8. Reward 分发必须采用 Pull-based Accounting，禁止向全部 NFT 批量推送资产。
9. Reward Strategy 必须通过 Adapter 接入，不得把外部 Swap 逻辑写进 FeeEngine 或 ConversionEngine。
10. TBA 自动结算只能遍历 RewardAssetRegistry，不得假设能够枚举任意 Token。
11. Genesis NFT Burn 必须在同一交易内完成 Pending Reward 结算、登记资产 Sweep、NFT Burn、FLUX Mint 和 Genesis Right 销毁。
12. 不可拆分 NFT 奖励必须使用独立 Strategy，不得按 ERC-20 会计逻辑分配。

