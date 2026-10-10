# Flux Protocol

> **Hackathon public repo:** core contracts and Foundry scripts only (no frontend or subgraph indexer). Full product lives in the private/main repository.

中文：[Readme.zh.md](./Readme.zh.md)

Flux Protocol is a dual-form asset system: each Asset Unit can exist as an NFT (ERC-721) or as FT (ERC-20). The protocol caps supply at **10,000 Asset Units**:

```text
1 Asset Unit = 1 NFT = 10,000 FLUX
```

Genesis distributes **5,000 Credits** via a CCA-style uniform clearing auction; the other **5,000** units seed FLUX/ETH liquidity. Genesis NFTs carry a permanent protocol fee share and hold claimed rewards in ERC-6551-style Token Bound Accounts (TBAs). On Genesis NFT burn, the protocol atomically settles pending rewards, sweeps registered TBA assets, burns the NFT, mints 10,000 FLUX, and destroys Genesis rights forever.

> This codebase is an engineering baseline **without third-party audit**. Production should use Chainlink VRF and a real Uniswap V2 router; local/test defaults use SyncVRF and mock liquidity adapters.

## Core modules

```text
GenesisAuction / CreditManager
               ↓
          AssetRegistry
               ↓
   FluxToken ⇄ ConversionEngine ⇄ DynamicNFT
               │                     │
               │                 Trait Engine
               │                     │
               └──────────── ERC-6551 TBA

FeeEngine
├── LiquidityVault
├── RewardStrategyManager → RewardVault → GenesisVault → TBA
├── BalanceVault
└── ProtocolVault
```

- `AssetRegistry` — single source of asset state; lazy derivation for initial credit/FT ranges.
- `ConversionEngine` — sole entry for credit, NFT, and FT transitions.
- `DynamicNFT` — one ERC-721 collection for Genesis and normal frogs; metadata/SVG fully on-chain.
- `FluxToken` — ERC-20 with Permit; only authorized modules mint/burn.
- `TraitStorage` / `Generator` / `Renderer` — traits, randomness, on-chain metadata; SVG split across modules for bytecode limits.
- `ERC6551Registry` / `FluxAccount` / `AccountManager` — deterministic TBAs, owner execution, burn settlement.
- `RewardAssetRegistry` / `RewardVault` / `GenesisVault` — registered reward assets, liabilities, pull-based multi-asset accounting.
- `RewardStrategyManager` — pluggable strategies; **HoldETHStrategy** shipped today.
- `BalanceEngine` / `BalanceVault` — dynamic fees/rewards targeting ~30–40% FT and ~60–70% NFT.
- `GenesisAuction` — budget + max-price bids, on-chain CCA clearing, pro-rata credit, LP bootstrap.

Documentation:

- [Whitepaper](docs/whitepaper.md)
- [Architecture specification](docs/architecture-specification.md)
- [Smart contract technical specification](docs/technical-specification.md)

Networks & deployment:

- [Multi-chain testnet config](docs/networks.md)
- [Flux Hackathon AMM (swappable mock V2)](docs/flux-hackathon-amm.md)

## Requirements

- Foundry
- Solidity 0.8.26
- OpenZeppelin Contracts 5.4.0
- forge-std 1.9.7

```bash
forge install
forge build
forge test
```

## Tests & coverage

Unit, integration, 512-run fuzz round-trips, and invariant tests. Core invariants include:

- Asset Unit count always **10,000**.
- `flux.totalSupply / 10_000` equals FT units.
- Genesis rights cannot reappear via NFT/FT round-trips.
- RewardVault balances cover booked liabilities.
- Genesis burn settles registered assets before NFT destruction.

```bash
forge test -vv
```

```bash
forge coverage --report summary \
  --skip script \
  --no-match-coverage '(test|script|src/integration/MockLiquidityAdapter.sol)'
```

Recent core coverage (excluding tests, scripts, MockLiquidityAdapter):

- Lines: **≥99.5%**
- Functions: **100%**
- **63** tests (unit + integration + fuzz + invariants)

## On-chain pixel frogs

48×48 SVG frogs with eight trait layers (no IPFS). Genesis mint and FT→NFT re-roll traits from mixed entropy (asset id, token id, user seed, chain id, block data, random provider). Traits are fixed on-chain until burn releases them for re-roll.

> On-chain pseudo-randomness is fine for visuals; validators/ordering can bias block variables. High-value rarity should use Chainlink VRF or commit–reveal on mainnet.

## Local deploy

```bash
cp .env.example .env
source .env
anvil
```

```bash
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network local --broadcast
```

Testnets (Monad / BSC / HyperEVM): see [`docs/networks.md`](docs/networks.md), e.g.:

```bash
source .env
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast
```

Addresses go to `deployments/<chain-id>.json` (local, not committed by default). Set `PROTOCOL_ADMIN` and `PROTOCOL_TREASURY` to Safe + Timelock in production.

## Genesis auction

```bash
forge script script/StartAuction.s.sol:StartAuction --rpc-url "$RPC_URL" --broadcast
forge script script/AuctionActions.s.sol:BidAuction --rpc-url "$RPC_URL" --broadcast
forge script script/AuctionActions.s.sol:FinalizeAuction --rpc-url "$RPC_URL" --broadcast
forge script script/AuctionActions.s.sol:ClaimAuctionCredit --rpc-url "$RPC_URL" --broadcast
```

`finalize()` computes clearing price, pro-rata credits, and bootstraps FLUX/ETH LP atomically.

## Protocol actions

```bash
forge script script/ProtocolActions.s.sol:MaterializeGenesisNFT --rpc-url "$RPC_URL" --broadcast
forge script script/ProtocolActions.s.sol:MaterializeFT --rpc-url "$RPC_URL" --broadcast
forge script script/ProtocolActions.s.sol:ConvertNFTToFT --rpc-url "$RPC_URL" --broadcast
forge script script/ProtocolActions.s.sol:ConvertFTToNFT --rpc-url "$RPC_URL" --broadcast
forge script script/ProtocolActions.s.sol:ClaimGenesisRewards --rpc-url "$RPC_URL" --broadcast
forge script script/ProtocolActions.s.sol:DistributeFees --rpc-url "$RPC_URL" --broadcast
```

See [.env.example](.env.example) for script variables.

## Pre-production checklist

1. Configure `VRF_COORDINATOR` + Chainlink VRF (or `SyncVRFRandomProvider` on testnets).
2. Configure `UNISWAP_V2_ROUTER` + `LP_LOCK`; verify permanent LP lock via `UniswapV2LiquidityAdapter`.
3. Audit/fuzz CCA clearing and pro-rata allocation.
4. Configure reward strategies: oracles, max slippage, deadlines, asset allowlists, emergency pause.
5. Audit TBA execution, malicious reward tokens, reentrancy, transfers, burn settlement.
6. Fork-test WETH, router, Permit, ERC-6551 on target chains.
7. Hand admin roles to Safe Multisig + Timelock.

## License

MIT
