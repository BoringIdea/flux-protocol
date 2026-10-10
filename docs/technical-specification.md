# Flux Protocol Smart Contract Technical Specification

中文：[technical-specification.zh.md](./technical-specification.zh.md)

## 1. Project Goal

Implement Flux Protocol: a system supporting bidirectional conversion between NFT (ERC-721) and FT (ERC-20), with ERC-6551 Token Bound Accounts and multi-asset rewards for NFTs.

Protocol requirements:

- Fixed total asset supply.
- Genesis Auction (CCA).
- Genesis NFT.
- ERC-20 liquidity.
- Dynamic fees.
- Fee Engine.
- Four-layer vaults.
- Trait Engine.
- ERC-6551 Registry and Token Bound Account.
- Reward Strategy, Reward Vault, and Reward Asset Registry.
- Atomic Genesis NFT burn settlement.
- Developed with Foundry.
- Uses OpenZeppelin contract libraries.

Tech stack:

- **Solidity**: `>=0.8.26`
- **Framework**: Foundry

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

GenesisAuction runs the Genesis auction:

- Create auction.
- Receive ETH.
- Process CCA bids.
- Complete price discovery.
- Finalize auction.
- Distribute Credit.
- Initialize LP.

State:

```solidity
enum AuctionState {
    Pending,
    Active,
    Finished
}
```

Main interfaces:

```solidity
createAuction()
bid()
cancelBid()
settle()
claimCredit()
initializeLP()
```

### CreditManager

CreditManager manages Genesis Credit. Credit cannot be re-issued; after Genesis completes, total supply is fixed at `5,000`.

Interfaces:

```solidity
claimNFT()
claimFT()
burnCredit()
```

### DynamicNFT

DynamicNFT is the unified ERC-721 collection for Genesis and normal NFTs, distinguished by the `genesis` flag, with Trait, metadata, random mint, and ERC-6551 account address lookup.

```solidity
struct NFTData {
    bool genesis;
    bool alive;
    uint256 traitSeed;
}
```

Interfaces:

```solidity
mint()
burn()
tokenURI()
traits()
reroll()
isGenesis()
account(uint256 tokenId)
```

All NFTs support ERC-6551, but only Genesis NFTs participate in protocol rewards. After Genesis NFT burn, Genesis Right is gone permanently; re-mint does not restore it.

### ERC6551Registry / FluxAccount

ERC6551Registry deterministically creates TBAs from NFT contract, tokenId, chain ID, salt, and account implementation. FluxAccount validates the current NFT owner and lets them manage account assets. Mint does not require deploying the account; creation happens on first claim or use.

Main interfaces:

```solidity
account(address nft, uint256 tokenId)
createAccount(address nft, uint256 tokenId)
execute(address target, uint256 value, bytes calldata data)
```

### AccountManager

AccountManager is the controlled protocol entry for TBAs: claim, sweep, and Genesis burn settlement. It only auto-handles assets registered in RewardAssetRegistry.

```solidity
ensureAccount(uint256 tokenId)
claimToAccount(uint256 tokenId, address rewardAsset)
sweepRegisteredAssets(uint256 tokenId, address recipient)
settleBeforeBurn(uint256 tokenId, address recipient)
```

### FluxToken

FluxToken is ERC-20 with fixed conversion:

```text
1 NFT = 10,000 FLUX
```

FluxToken extends `ERC20Permit` without Votes / Snapshot extensions.

### ConversionEngine

ConversionEngine is the core module for `NFT ⇄ FT` conversion.

Interfaces:

```solidity
nftToFT()
ftToNFT()
previewFee()
previewReward()
currentRatio()
```

ConversionEngine must preserve total asset conservation.

Genesis NFT `nftToFT()` must execute atomically in this order:

1. Lock NFT owner at burn initiation.
2. Settle unclaimed vested rewards for that tokenId.
3. Via AccountManager, sweep all registered TBA assets to that owner.
4. Confirm registered asset settlement complete.
5. Burn NFT and return Trait.
6. Mint 10,000 FLUX to owner.
7. Permanently destroy Genesis Right and decrement `activeGenesisSupply`.
8. Update AssetRegistry and emit event.

Any step failure must revert the entire transaction. Unregistered assets are outside auto-settlement; the protocol must not treat them as cleared.

---

## 4. Genesis Flow

Initialize `10,000 Asset Units`, split as:

```text
10,000 Asset Units
├── 5,000 → Credit Auction
└── 5,000 → LP Reserve
```

LP Reserve auto-mints `50,000,000 FLUX`. After the auction, auction ETH and `50,000,000 FLUX` create Uniswap LP:

```text
Auction ETH + 50,000,000 FLUX → Uniswap LP
```

LP is permanently locked; auction participants receive Credit.

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

TBA settlement is required before Genesis NFT burn; after burn, Genesis Right is lost forever. Normal NFTs may also have TBAs but do not participate in Genesis rewards.

---

## 6. Trait Engine

Traits are not hard-coded; they live in storage and are generated randomly, including:

```text
Background
Body
Eyes
Hair
Accessory
```

Trait Generator supports weighted random with interfaces:

```solidity
generate()
reroll()
randomSeed()
```

Trait randomness is injected via `IRandomProvider`; deployment may use `ChainlinkVRFRandomProvider`, `SyncVRFRandomProvider`, or `MockRandomProvider`.

---

## 7. Fee Engine

All protocol fees enter Fee Engine from:

1. Swap fees.
2. Marketplace fees.
3. NFT / FT conversion fees.

Fee Engine distributes revenue uniformly. Genesis allocation goes to Reward Strategy first, not direct ETH push to holder wallets:

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

Fees split across four vaults:

```text
Fee
├── Liquidity Vault
├── Reward Strategy / Genesis Accounting
├── Balance Vault
└── Protocol Vault
```

Vault percentages may be changed by governance.

### Liquidity Vault

Liquidity Vault continuously adds FLUX/ETH LP.

Interfaces:

```solidity
addLiquidity()
pendingLiquidity()
```

### Genesis Vault

Genesis Vault provides permanent multi-asset cash flow for Genesis NFTs. After burn, future yield is lost forever; remaining Genesis NFTs share proportionally. Uses `accRewardPerShare + rewardDebt` pull-based accounting; no full NFT iteration on inflow.

Interfaces:

```solidity
deposit(address rewardAsset, uint256 amount)
claim(uint256 tokenId, address rewardAsset)
claimAllRegistered(uint256 tokenId)
pending(uint256 tokenId, address rewardAsset)
```

Claim recipient must be the tokenId’s TBA. After Genesis NFT transfer, future yield and TBA control move with the new owner.

### Reward Vault

Reward Vault holds unclaimed reward assets and ensures balance per asset covers booked liabilities.

```solidity
depositFromStrategy(address rewardAsset, uint256 amount)
payToAccount(uint256 tokenId, address rewardAsset, uint256 amount)
available(address rewardAsset)
liability(address rewardAsset)
```

### Reward Strategy Manager

Reward Strategy Manager converts input assets to reward assets via whitelisted adapters. Current implementation includes `HoldETHStrategy`; others extend via `IRewardStrategy` and adapters.

```solidity
executeStrategy(bytes32 strategyId, uint256 amountIn, uint256 minAmountOut)
setStrategy(bytes32 strategyId, address adapter)
pauseStrategy(bytes32 strategyId)
```

All strategies must check max slippage, min output, deadline, input/output whitelists, and caller permissions. Non-fungible NFT rewards do not use ordinary per-share accounting; they require separate draw, auction, or NFT vault strategies.

### Reward Asset Registry

Reward Asset Registry stores supported reward assets and enumeration needed for burn settlement.

```solidity
registerAsset(address asset, AssetType assetType, address settlementAdapter)
disableAsset(address asset)
isRegistered(address asset)
registeredAssets()
```

Auto claim and burn settlement only cover native ETH/WETH and ERC-20 registered in RewardAssetRegistry. Unregistered assets users send to TBA are user-managed.

### Balance Vault

Balance Vault maintains protocol balance with target ratio:

```text
NFT: 60%–70%
FT:  30%–40%
```

Rewards are computed dynamically from treasury balance and must not over-issuance.

Interfaces:

```solidity
reward()
dailyBudget()
remainingBudget()
currentTarget()
```

### Protocol Vault

Protocol Vault receives protocol revenue for maintenance, with MultiSig support.

Interfaces:

```solidity
withdraw()
setRecipient()
```

---

## 9. Dynamic Balance Engine

Dynamic Balance Engine maintains NFT/FT ratio with target band:

```text
NFT: 60%–70%
FT:  30%–40%
```

The protocol maintains a neutral zone (e.g. FT 30%–40%) with low fees both ways; outside the zone, conversion cost increases dynamically on the imbalanced direction.

---

## 10. Fee Curve

Fee Curve uses continuous functions, not step functions.

Interfaces:

```solidity
calculateFee()
calculateReward()
```

Inputs:

```text
Current FT Ratio
Current Treasury
Target Ratio
```

Outputs:

```text
Fee
Reward
```

Fee Curve supports future upgrades.

---

## 11. Metadata

NFT metadata is fully on-chain; SVG is generated on-chain with Trait Renderer support.

---

## 12. Security

- All state changes use Checks-Effects-Interactions.
- Use ReentrancyGuard.
- ERC-20 supports Permit.
- ERC-721 uses ERC721A (where applicable) or OpenZeppelin ERC721.
- AccessControl for permissions.
- Pausable for pause mechanism.
- FluxAccount must verify current NFT owner to prevent prior owner executing after transfer.
- AccountManager allows controlled settlement only from ConversionEngine and GenesisVault.
- Burn settlement must be reentrancy-safe and lock owner/settlement state before external transfers.
- Reward strategies require asset whitelist, slippage protection, deadline, and min-output checks.
- Core contracts deploy non-upgradeable by default.

---

## 13. Events

Required events:

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

Foundry test coverage target above 95%, including:

- Genesis.
- CCA.
- Random Trait.
- NFT burn.
- NFT mint.
- FT mint.
- FT burn.
- Fee.
- Vault.
- Reward.
- ERC-6551 account permissions and deterministic addresses.
- Multi reward asset accounting.
- Claim to TBA.
- Atomic Genesis burn settlement.
- Reward strategy slippage and malicious adapters.
- LP.

Invariant tests must keep total assets at `10,000` and cover:

- Genesis Right unrecoverable after burn.
- After burn settlement, all registered assets transferred to owner at burn initiation.
- RewardVault balances always cover booked liabilities per asset.
- Reward strategies must not output unregistered assets.
- Revenue distribution and claim must not unbounded-loop by total NFT count.

Fuzz tests should cover conversion, consecutive burn/mint, and consecutive swap while preserving correct supply.

---

## 15. Deployment

Use Foundry scripts in this order:

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

1. All core parameters via config, no hardcoding.
2. All ratios governable.
3. All math via math libraries.
4. All randomness via Trait Generator.
5. All fees via Fee Engine.
6. All asset conversion via Conversion Engine.
7. No module may directly mutate ERC-20, ERC-721, or supply except through Conversion Engine.
8. Reward distribution must use pull-based accounting; no batch push to all NFTs.
9. Reward strategies via adapters only; no external swap logic inside FeeEngine or ConversionEngine.
10. TBA auto-settlement may only iterate RewardAssetRegistry; do not assume arbitrary token enumeration.
11. Genesis NFT burn must complete pending reward settlement, registered sweep, NFT burn, FLUX mint, and Genesis Right destruction in one transaction.
12. Non-fungible NFT rewards need independent strategies; do not allocate like ERC-20 accounting.
