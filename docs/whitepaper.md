# Flux Protocol Whitepaper

中文：[whitepaper.zh.md](./whitepaper.zh.md)

> Draft v2

## 1. Vision

The main limitation of traditional NFTs (ERC-721) is not the asset itself but lack of liquidity. ERC-20 already has full DeFi infrastructure, including:

- DEX
- AMM
- LP
- Lending
- Leverage
- Perpetual
- Tax Token
- Yield Farming

NFTs remain largely in collecting, listing, and auction use cases. Flux Protocol aims to create a new asset standard so digital assets can switch freely between NFT (collectible) and FT (liquid) forms, bringing NFTs into DeFi. Flux represents continuous flow and transformation across forms; the protocol brand is independent of any single NFT IP so more collections can be supported over time.

---

## 2. Core Asset Model

The protocol fixes `10,000 Asset Units`; each unit maps to one unique asset. An asset can be in three states:

```text
Credit
  ↓
NFT
  ↓
FT（10,000 FLUX）
```

Conversion relationships:

```text
1 Asset Unit = 1 NFT = 10,000 FLUX
```

The protocol guarantees bidirectional NFT ↔ FT conversion at all times.

---

## 3. NFT Model

NFTs are not fixed serial assets; value comes from Trait combinations, for example:

```text
Hair
Eyes
Background
Accessory
Body
```

When an NFT is burned, it converts to `10,000 FLUX`:

```text
NFT → 10,000 FLUX
```

Converting back uses random mint for a new NFT:

```text
10,000 FLUX → Random Mint → new NFT
```

The new NFT rolls fresh Traits. NFT value is entirely market-driven; the protocol does not set “how much ERC-20 one NFT is worth.”

---

## 4. Genesis

Genesis has two goals:

1. Fair distribution.
2. Liquidity bootstrap.

After Genesis, the protocol runs in steady state.

---

## 5. Genesis Launch

Genesis uses Continuous Clearing Auction (CCA). Genesis has `10,000 Asset Units`, split 50/50:

```text
10,000 Units
├── 5,000 Units → CCA Auction
└── 5,000 Units → LP Reserve
```

The auction sells `5,000 Credit`; LP Reserve converts to `50,000,000 FLUX`. After ETH is raised, the protocol creates Uniswap LP:

```text
50,000,000 FLUX + Auction ETH → Uniswap LP
```

LP is permanently locked. At Genesis completion, the protocol has initial price, initial LP, and ERC-20 liquidity; auction participants receive `5,000 Credit`.

---

## 6. Credit

Credit is a temporary Genesis-phase asset representing not-yet-materialized Asset Units. Credit can become Genesis NFT or `10,000 FLUX`:

```text
Credit → Genesis NFT
Credit → 10,000 FLUX
```

After all Credit is converted, only NFT and FT states remain.

---

## 7. Genesis NFT

Genesis NFT is the protocol’s flagship asset with permanent protocol rights. It is not merely “NFT with cash flow” but:

> **Identity + Trait + ERC-6551 Wallet + Genesis fee share + Reward Asset Portfolio**

The full collection supports ERC-6551 Token Bound Accounts (TBA), but only Genesis NFTs automatically receive protocol fee share. TBA address is determined by NFT identity, created on demand without pre-deploy at mint. TBA can hold ETH, FLUX, and ERC-20 rewards registered in Reward Asset Registry; on NFT transfer, economic control of the TBA moves with the NFT.

Genesis NFT can convert to `10,000 FLUX`, but once burned, Genesis identity and future fee share are gone forever; re-minted NFTs never regain Genesis rights. Burn requires atomic settlement:

```text
Read NFT’s TBA
  ↓
Settle protocol-registered assets to current holder
  ↓
Confirm settlement complete
  ↓
Burn Genesis NFT
  ↓
Mint 10,000 FLUX to holder
  ↓
Permanently destroy Genesis Right
```

Auto-settlement scope is defined by Reward Asset Registry. The protocol cannot enumerate arbitrary user-deposited assets; non-registered assets are user-managed; registered assets are mainly native ETH/WETH and ERC-20.

Thus Genesis NFTs are naturally scarce. Holders permanently share part of protocol fees. Genesis NFTs represent earliest participants and the first founders of the protocol.

---

## 8. Continuous Clearing Auction (CCA)

Genesis uses CCA for price discovery. CCA does not allocate Credit by capital share; each participant submits:

- **Budget**: ETH willing to spend.
- **Max Price**: highest acceptable clearing price.

During the auction, the protocol continuously computes clearing price (uniform price). Eligible bids fill; when price exceeds a user’s max, that bid exits. All filled users trade at the same final price.

CCA advantages:

- No gas war
- No frontrunning
- No last-block sniping
- Fair price discovery
- Direct LP initialization

After Genesis auction, that price becomes the initial FLUX/ETH LP price.

---

## 9. Protocol Lifecycle

Genesis phase:

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

After launch:

```text
Credit → Genesis NFT → FT → NFT → FT
```

---

## 10. NFT / FT Conversion

Conversion relationships:

```text
NFT → 10,000 FLUX
10,000 FLUX → Random NFT
```

Total asset supply stays constant.

---

## 11. Target Balance

The protocol neither targets all NFT nor all FT, but long-term ratio:

```text
NFT: 60%–70%
FT:  30%–40%
```

NFTs carry collectible value; FTs carry DeFi liquidity. Dynamic economics keep the system oscillating around this band.

---

## 12. Dynamic Fee Engine

The protocol uses bidirectional dynamic fees to maintain NFT/FT balance, not to favor one side:

- When FT is above target, encourage `FT → NFT`.
- When NFT is above target, encourage `NFT → FT`.
- In the neutral zone, both directions convert cheaply.
- Larger deviation, higher conversion cost.

Balance Engine computes fee/reward with continuous functions, not fixed steps.

---

## 13. Fee Sources

Three fee sources:

1. **ERC-20 Swap Fee**: from Uniswap and other AMMs.
2. **NFT Marketplace Fee**: from secondary markets (OpenSea etc. supporting royalty or protocol fee).
3. **NFT / FT Conversion Fee**: from in-protocol conversion, including dynamic mint fees.

---

## 14. Fee Engine

All fees enter Fee Engine, then auto-split to four vaults:

```text
Fee
├── Liquidity Vault
├── Reward Strategy / Genesis Accounting
├── Balance Vault
└── Protocol Vault
```

### Liquidity Vault

Liquidity Vault deepens FLUX/ETH LP over time. Longer runtime yields deeper LP and more stable liquidity.

### Genesis Vault

Genesis NFT holders permanently share protocol cash flow. After burn, future yield is lost; remaining Genesis NFTs share more. Assets already claimed to TBA belong to that NFT; unclaimed but vested rewards must settle in burn settlement.

Genesis Vault no longer pushes ETH to all holders. It uses pull-based accounting with `accRewardPerShare + rewardDebt` per reward asset. Holders claim actively; Reward Vault then sends assets to that NFT’s ERC-6551 TBA, avoiding large loop transfers as NFT count grows.

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

Balance Vault auto-regulates toward NFT 60%–70% and FT 30%–40%. Rewards are not fixed; they depend on treasury balance and NFT/FT deviation.

Larger treasury, higher rewards; smaller treasury, rewards shrink automatically. Treasury can run sustainably without exhausting subsidies. Balance Vault can encourage `NFT → FT` or `FT → NFT` as a stabilizer.

### Protocol Vault

Protocol Vault is long-term protocol revenue for:

- Development
- Audit
- Infrastructure
- Indexer
- Frontend
- Operations

This supports ongoing maintenance.

### Reward Strategy Engine

Genesis revenue converts to target reward assets via pluggable Reward Strategy; core NFT/FT conversion does not depend on which asset is bought.

```text
RewardStrategyManager
├── HoldETHStrategy (implemented)
└── IRewardStrategy extensions (e.g. BuyFlux, BuyERC20)
```

Fungible assets use per-share accounting and claim; non-fungible NFTs are not split evenly but handled via separate strategies (draw, auction, NFT vault, etc.).

### Reward Asset Registry

Reward Asset Registry governs assets the protocol may distribute and auto-settle. It provides a finite enumerable set for claim, accounting, and burn settlement, avoiding scans for unknown tokens in TBA.

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
  ├── Liquidity Vault → deeper LP → stabler price
  ├── Reward Strategy → Reward Vault → ERC-6551 TBA
  └── Balance Vault → Dynamic Incentive → NFT / FT Balance
                                              ↓
                                          more trading
                                              ↓
                                           more fees
                                              ↓
                                         sustained growth
```

The protocol forms a complete economic loop.

---

## 16. Core Innovations

Compared with traditional NFTs, main innovations:

- Dual-form assets (NFT / FT)
- Credit state (Genesis)
- Trait random re-mint
- CCA fair launch
- 50/50 Genesis distribution
- Protocol-owned liquidity bootstrap
- Genesis NFT permanent cash-flow rights
- ERC-6551 Token Bound Account
- Reward asset portfolio
- Pluggable Reward Strategy Engine
- Reward Asset Registry and atomic burn settlement
- Pull-based multi-asset reward accounting
- Bidirectional dynamic fees
- Auto-balance engine (Balance Engine)
- Four-layer vault revenue model
