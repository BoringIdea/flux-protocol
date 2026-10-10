# Flux Protocol Architecture Specification

中文：[architecture-specification.zh.md](./architecture-specification.zh.md)

## 1. Architecture Goal

This architecture describes Flux Protocol’s module boundaries and responsibilities (Foundry + Solidity).

Core objectives:

- Define each contract’s responsibility clearly.
- Prevent multiple modules from mutating the same state.
- Preserve conservation of total Asset supply.
- Keep Genesis, NFT, FT, Fee, and Vault modules decoupled.
- Minimize upgradeability and cross-module complexity.

Core design principle:

> Asset state changes must be handled centrally; fund allocation and reward accounting must be handled centrally; random Traits must be handled centrally; Token Bound Account execution and settlement must go through controlled modules.

---

## 2. High-Level Architecture

The overall architecture consists of the core asset layer plus extension layers such as Token Bound Account and Reward Strategy:

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

Trait Engine supplies random Traits and Metadata for the NFT Layer.

---

## 3. Core Contracts

### 3.1 AssetRegistry

AssetRegistry is the protocol’s source of truth for state. It does not perform ERC-20 or ERC-721 transfers; it only records:

```solidity
enum AssetState {
    Uninitialized,
    Credit,
    GenesisNFT,
    NFT,
    FT
}
```

Recommended data structure:

```solidity
struct AssetData {
    AssetState state;
    bool genesis;
    uint256 tokenId;
}
```

Total Asset Units:

```solidity
uint256 public constant MAX_ASSETS = 10_000;
```

The following must hold:

```text
Credit Units + Genesis NFT Units + Normal NFT Units + FT Equivalent Units = 10,000
```

Where:

```text
FT Equivalent Units = FLUX.totalSupply() / 10_000e18
```

Only `ConversionEngine` and `GenesisAuction` may mutate AssetRegistry. No NFT/FT contract may update AssetRegistry on its own.

---

## 4. Genesis Layer

### 4.1 GenesisAuction

GenesisAuction bootstraps the protocol. Genesis is fixed at `10,000 Asset Units`, split as:

```text
5,000 CCA Credits
5,000 LP Reserve
```

GenesisAuction is responsible for:

- Initializing the CCA.
- Receiving ETH bids.
- Recording max price.
- Computing clearing results.
- Finalizing the auction.
- Distributing Credit.
- Converting 5,000 LP Asset Units into 50,000,000 FLUX.
- Creating Uniswap LP.
- Transferring the LP position to LiquidityVault.

After completion, GenesisAuction is permanently disabled. Its state:

```solidity
enum GenesisState {
    Pending,
    Active,
    Finalized
}
```

After Finalized, all Genesis write paths are permanently closed:

```solidity
require(state == GenesisState.Finalized);
```

### 4.2 CreditManager

Credit is recorded in an internal ledger, not as a freely transferable ERC-20. Credit represents rights to Asset Units not yet materialized during Genesis; it must not persist long-term as a third tradable asset class in the protocol.

```solidity
mapping(address => uint256) creditBalance;
```

CreditManager only supports:

```solidity
creditBalance(address)
materializeToGenesisNFT(uint256 amount)
materializeToFT(uint256 amount)
```

Credit is permanently burned when used.

---

## 5. Representation Layer

### 5.1 FluxToken

FluxToken is a standard ERC-20 extending `ERC20` and `ERC20Permit`, without Votes / Snapshot extensions. Only ConversionEngine, GenesisAuction, and authorized modules may call `mint()` / `burn()`; users cannot mint directly.

Core constant:

```solidity
uint256 public constant UNIT = 10_000e18;
```

Theoretical max supply is `100_000_000e18`, but actual `totalSupply` varies dynamically.

### 5.2 DynamicNFT

The protocol uses a single ERC-721 contract. Genesis NFTs and normal NFTs are distinguished via a metadata flag:

```solidity
struct NFTData {
    bool genesis;
    bool alive;
    uint256 traitSeed;
}
```

Compared with separate GenesisNFT.sol and DynamicNFT.sol ERC-721 contracts, a unified contract provides:

- A single OpenSea collection.
- Unified marketplace presence.
- Unified tokenId space.
- No duplicated ERC-721 logic.

Genesis NFTs use `genesis = true`; re-minted normal NFTs use `genesis = false`. After a Genesis NFT is burned, Genesis Right is gone forever; any later mint can only produce a normal NFT.

The entire collection supports ERC-6551, but only Genesis NFTs automatically receive protocol fee share. TBA deployment is not required at mint; account addresses are computed deterministically via ERC6551Registry and created on first claim or active use.

### 5.3 ERC-6551 Account Layer

Each NFT has a Token Bound Account (TBA) so it can hold ETH, ERC-20, and reward assets registered in RewardAssetRegistry. This layer includes:

- **ERC6551Registry**: Deterministic TBA creation and address computation.
- **FluxAccount**: TBA implementation; validates execution rights of the NFT owner.
- **AccountManager**: Wraps account creation, claim, sweep, and burn settlement.
- **RewardAssetRegistry**: Stores the finite set of protocol-distributable, auto-settleable assets.

TBA control follows NFT ownership. The protocol can only enumerate and settle assets registered in RewardAssetRegistry; unregistered assets users deposit must be handled by the user before burn.

Genesis NFT value structure:

```text
Identity + Trait + TBA Assets + Genesis fee share
```

---

## 6. Trait Layer

### 6.1 TraitGenerator

TraitGenerator:

- Accepts a random seed.
- Generates Traits.
- Validates Trait weights.
- Outputs TraitData.

For example:

```solidity
struct TraitData {
    uint16 background;
    uint16 body;
    uint16 eyes;
    uint16 hair;
    uint16 accessory;
}
```

Randomness is injected via `IRandomProvider`: mainnet target is `ChainlinkVRFRandomProvider`; testnets and local environments may use `SyncVRFRandomProvider` or `MockRandomProvider`. TraitGenerator does not mint NFTs; it only generates Traits and writes TraitStorage.

### 6.2 TraitStorage

TraitStorage maintains:

- Trait types.
- Trait weights.
- Trait max supply.
- Trait current supply.
- Trait combination constraints.

For example:

```solidity
mapping(uint256 => uint256) traitMaxSupply;
mapping(uint256 => uint256) traitCirculating;
```

Traits are stored bound to Asset ID. On NFT burn, TraitStorage releases that Asset’s Trait occupancy; on re-mint, the same Asset rolls new Traits, recycling Trait space within protocol rules.

### 6.3 TraitRenderer

TraitRenderer only implements:

```solidity
tokenURI(tokenId)
```

It outputs JSON metadata, Base64 SVG, and attributes from TraitData and must not hold business state.

---

## 7. Conversion Engine

ConversionEngine is the protocol’s most critical contract; all state transitions must pass through it. Four paths are supported:

```text
Credit → Genesis NFT
Credit → FLUX
NFT → FLUX
FLUX → NFT
```

### 7.1 Credit → Genesis NFT

Interface:

```solidity
materializeGenesisNFT(uint256 amount)
```

Flow:

1. Burn Credit.
2. Allocate Asset Unit from AssetRegistry.
3. Call TraitGenerator.
4. Mint Genesis NFT.
5. Set `genesis = true`.
6. Update AssetRegistry.
7. Emit event.

### 7.2 Credit → FT

Interface:

```solidity
materializeFT(uint256 amount)
```

Flow:

1. Burn Credit.
2. Mint 10,000 FLUX per Credit.
3. Update AssetRegistry state from Credit to FT.
4. Emit event.

### 7.3 NFT → FT

Interface:

```solidity
nftToFT(uint256 tokenId)
```

Flow:

1. Check owner.
2. Read current NFT/FT ratio.
3. BalanceEngine computes fee/reward.
4. Process fee.
5. If Genesis NFT, settle unclaimed vested rewards first.
6. Via AccountManager, atomically sweep registered ETH/ERC-20 in TBA to current owner.
7. Confirm registered asset settlement complete.
8. Burn NFT and return Trait to TraitPool.
9. Mint 10,000 FLUX.
10. If Genesis NFT, permanently destroy Genesis Right, decrement `activeGenesisSupply`, and stop future fee rights.
11. Update AssetRegistry state from NFT to FT.
12. If Balance reward exists, BalanceVault pays reward.
13. Emit event.

ConversionEngine must not scan arbitrary tokens in the TBA. Burn settlement only iterates RewardAssetRegistry; unregistered assets are the user’s responsibility.

### 7.4 FT → NFT

Interface:

```solidity
ftToNFT()
```

Flow:

1. Verify user balance is at least 10,000 FLUX.
2. BalanceEngine computes fee/reward.
3. Burn 10,000 FLUX.
4. Process fee.
5. Draw Traits from TraitPool.
6. Mint normal NFT.
7. Update AssetRegistry state from FT to NFT.
8. If reward exists, BalanceVault pays reward.
9. Emit event.

> FT → NFT always mints a normal NFT only; Genesis NFT can never be re-created.

---

## 8. Balance Engine

BalanceEngine holds no funds; it only performs math.

Inputs:

```solidity
currentFTUnits
currentNFTUnits
balanceVaultBalance
direction
```

Output:

```solidity
struct Quote {
    uint256 fee;
    uint256 reward;
}
```

Target neutral zone: FT 30%–40%, NFT 60%–70%. Logic:

### FT > 40%

Encourage `FT → NFT`:

```text
FT → NFT fee = 0
FT → NFT reward > 0
NFT → FT fee > 0
```

### FT = 30%–40%

Neutral zone:

```text
fee ≈ 0
reward = 0
```

### FT < 30%

Encourage `NFT → FT`:

```text
NFT → FT fee = 0
NFT → FT reward > 0
FT → NFT fee > 0
```

---

## 9. Reward Budget Model

BalanceVault rewards cannot be released without bound. Daily budget is capped as a fraction of vault balance:

```solidity
dailyBudget = balanceVaultBalance * dailyReleaseBps / 10_000;
```

For example, when `dailyReleaseBps = 10`, at most 0.1% of BalanceVault may be released per day. Reward function:

```text
Reward Weight = Deviation × Direction Weight
```

For example, if FT target center is 35% and FT share is 50%, deviation is 15%. Larger deviation yields higher reward weight, but total rewards that day cannot exceed `dailyBudget`.

One day is one epoch, tracking:

```solidity
epochBudget
epochSpent
```

---

## 10. Fee Engine

All fees enter FeeEngine from:

1. Conversion fees.
2. Uniswap LP fees.
3. NFT marketplace royalty / protocol fees.

Marketplace fees cannot always be enforced. ERC-721 royalties use ERC-2981, but whether OpenSea and other marketplaces honor royalties depends on the marketplace. Architecturally, marketplace fees are optional revenue, not required for protocol stability.

---

## 11. Fee Distribution

FeeEngine splits revenue across four vaults:

```text
Liquidity Vault
Reward Strategy / Genesis Accounting
Balance Vault
Protocol Vault
```

Genesis allocation does not loop-transfer directly to NFT holders. FeeEngine sends that portion to RewardStrategyManager; after strategy execution, target assets enter RewardVault and GenesisVault updates multi-asset reward accounting.

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

Split ratios use:

```solidity
struct FeeSplit {
    uint16 liquidityBps;
    uint16 genesisBps;
    uint16 balanceBps;
    uint16 protocolBps;
}
```

All BPS must sum to `10,000`. Default split:

```text
Liquidity  30%
Genesis    25%
Balance    25%
Protocol   20%
```

These parameters must be configurable.

---

## 12. Liquidity Vault

LiquidityVault:

- Holds the Genesis Uniswap LP position.
- Collects LP fees.
- Adds a portion of new fees back to FLUX/ETH LP.
- Prevents withdrawal of core LP by the team.

Genesis LP position is permanently locked; later LP may auto-compound. Only FeeEngine and authorized LP Manager may call LiquidityVault.

---

## 13. Genesis Vault

GenesisVault handles multi-asset fee share for Genesis NFTs using pull-based accounting, without iterating all NFTs on each inflow. Accounting follows a MasterChef-style `accRewardPerShare` pattern:

```solidity
mapping(address rewardAsset => uint256) public accRewardPerGenesis;
mapping(uint256 tokenId => mapping(address rewardAsset => uint256)) public rewardDebt;
```

Active Genesis NFT count is `activeGenesisSupply`. When a Genesis NFT is burned:

```text
activeGenesisSupply -= 1
```

Subsequent fees are shared only among remaining Genesis NFTs. Genesis rights transfer with NFT ownership; after transfer, the new owner earns future rewards. On `claim(tokenId, rewardAsset)`, RewardVault sends rewards to that tokenId’s TBA.

### 13.1 RewardStrategyManager

RewardStrategyManager converts input assets such as ETH/WETH into target reward assets via whitelisted adapters. Current implementation includes `HoldETHStrategy`; others extend `IRewardStrategy`. Each strategy must configure allowed input/output assets, max slippage, routing, and execution permissions.

Non-fungible NFTs do not enter ordinary `accRewardPerShare` accounting; they use separate draw, auction, or NFT vault strategies.

### 13.2 RewardVault and RewardAssetRegistry

RewardVault holds unclaimed reward assets; only GenesisVault, controlled strategies, and AccountManager may call it. RewardAssetRegistry stores supported reward assets, asset types, enablement, and settlement adapters, providing enumerable bounds for:

- Multi-asset reward accounting.
- Claim to ERC-6551 TBA.
- Auto settlement before Genesis NFT burn.
- Emergency disable of risky reward assets.

---

## 14. Protocol Vault

ProtocolVault receives developer revenue; only multisig may withdraw, with timelock support. It must not modify asset supply. Admin and treasury use `Safe Multisig + Timelock`.

---

## 15. External Integrations

### Uniswap

Genesis finalize creates FLUX/ETH liquidity via `ILiquidityMigrator` (configurable Uniswap v4 Migrator, Flux Hackathon AMM / V2-style Migrator, or Mock for testing). Runtime trading and protocol fees flow through integrations such as `FluxSwapRouter` into FeeEngine; LiquidityVault LP reinvestment uses `ILiquidityAdapter` against on-chain routers or mock adapters.

### Chainlink VRF

Trait randomness requires abstract `IRandomProvider` with implementations:

```text
ChainlinkVRFProvider
MockRandomProvider
```

---

## 16. Access Control

Protocol roles:

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

In production, admin should use Timelock, not an EOA.

---

## 17. Emergency Control

Pausable must support pausing these modules independently:

- Auction
- Conversion
- Random Mint
- Fee Distribution
- Reward Strategy
- Reward Claim
- TBA Burn Settlement

Pause is per-module to avoid a single global pause locking everything:

```solidity
mapping(bytes32 => bool) pausedModule;
```

---

## 18. Invariants

Foundry invariant tests must cover:

1. Total assets always `10,000`.
2. This equation always holds:

   ```text
   NFT Units + Credit Units + FLUX totalSupply / 10,000 = 10,000
   ```

3. After Genesis NFT burn, Genesis Right can never be recreated.
4. FLUX is only created via Genesis LP, `Credit → FT`, and `NFT → FT`.
5. Normal NFTs are only created via `FT → NFT`.
6. All FeeSplit sums must equal 100%.
7. BalanceVault rewards per epoch must satisfy `reward <= epochBudget`.
8. After Genesis NFT burn completes, corresponding Genesis Right is unrecoverable and that tokenId no longer accrues rewards.
9. When burn settlement completes, all registered assets in RewardAssetRegistry must have TBA balances transferred to the NFT owner at burn initiation.
10. RewardVault booked liabilities must not exceed available balance for each reward asset.
11. A single reward strategy execution must not output assets not registered in RewardAssetRegistry.

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

Tests:

```text
test/
├── unit/
├── integration/
├── fuzz/
└── invariant/
```

Scripts:

```text
script/
├── Deploy.s.sol
├── StartAuction.s.sol
├── FinalizeAuction.s.sol
└── ConfigureProtocol.s.sol
```

---

## 20. Implementation Constraints

Implementation must follow:

1. Do not duplicate asset supply tracking across contracts.
2. AssetRegistry is the sole source of state.
3. ConversionEngine is the only entry for asset state transitions.
4. Token contracts accept mint/burn only from authorized callers.
5. FeeEngine is the only entry for fee distribution.
6. BalanceEngine holds no funds; computation only.
7. Vaults must not directly mint/burn NFT or FLUX.
8. Trait modules must not mutate economic state.
9. External integration must go through adapters.
10. All core parameters use BPS.
11. No floating point.
12. Prefer custom errors.
13. All external calls follow CEI.
14. All ETH transfers use `call`, not `transfer`.
15. Foundry tests: core invariants first, then full functional tests.
16. Core contracts deploy non-upgradeable by default.
17. Governance permissions limited to necessary modules; admin uses Multisig + Timelock.
18. After Genesis finalize, auction contract cannot restart.
19. Reward distribution must use pull-based accounting; no loop transfers by total NFT count.
20. TBA burn settlement may only iterate assets registered in RewardAssetRegistry.
21. Unregistered TBA assets must not be silently destroyed or treated as settled by the protocol.
22. Reward strategies must be isolated via adapters with whitelist, slippage, and min-output checks.
23. Genesis NFT burn must complete in one transaction: vested reward settlement, registered asset sweep, NFT burn, FLUX mint, and Genesis Right destruction.

---

## 21. Final Architecture Principle

The protocol reduces to:

```text
AssetRegistry    defines what the asset is
ConversionEngine defines how asset state changes
TraitEngine      defines how the NFT looks
AccountManager   defines TBA create, execute, and settle
BalanceEngine    defines when to encourage which state
FeeEngine        defines where funds flow
RewardStrategy   defines what Genesis revenue becomes
GenesisVault     defines multi-asset reward accounting
Vaults           hold assets and revenue
```

Any new feature must respect these boundaries. If a module both changes asset state, allocates funds, and generates Traits, its responsibilities are wrong and it should be split.
