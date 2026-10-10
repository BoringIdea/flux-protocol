# Flux Hackathon AMM (mock Uniswap V2 style)

> When `UNISWAP_V4_MIGRATOR` is unset and `FLUX_LEGACY_V4_MOCK` is not `true`, `Deploy.s.sol` deploys a simple **real-swap** AMM for testnets and hackathon demos.

中文：[flux-hackathon-amm.zh.md](./flux-hackathon-amm.zh.md)

---

## Components

| Contract | Role |
|----------|------|
| `FluxAMMFactory` | One `FluxNativePair` per FLUX (ERC-20) |
| `FluxNativePair` | Native coin + token constant-product pool (0.3% fee), `addLiquidity` / swap |
| `MockUniswapV2Migrator` | `ILiquidityMigrator`; seeds liquidity on Genesis `finalize()` |
| `FluxSwapRouter` | User entry: swap + **protocol fee** (default 30 bps) to `FeeEngine`, analogous to a Uniswap v4 hook |
| `FeeEngine` | Receives router / conversion fees; `distribute()` splits to Liquidity / Genesis / Balance / Protocol |

Deployment writes to `deployments/<chainId>.json`:

- `FluxAMMFactory`
- `FluxSwapRouter`
- `LiquidityMigrator` → `MockUniswapV2Migrator`
- `LiquidityVault.genesisPosition` → **pair address** (unlike v4 mock bytes32 placeholder; reserves visible on-chain)

---

## Demo flow

1. Deploy → StartAuction → bid → **finalize** (pool created; FLUX + raised ETH added)
2. Swap via `cast` or scripts on the router:

```bash
# Set FLUX_SWAP_ROUTER, FluxToken in .env from deployments JSON

forge script script/SwapActions.s.sol:SwapETHForFlux \
  --rpc-url monad_testnet --broadcast

forge script script/SwapActions.s.sol:SwapFluxForETH \
  --rpc-url monad_testnet --broadcast
```

3. Protocol fees from swaps land in `FeeEngine` (same economic path as mainnet **hook → FeeEngine**; here the router collects):

```bash
cast balance $FEE_ENGINE --rpc-url monad_testnet
cast send $FEE_ENGINE "distribute()" --rpc-url monad_testnet --private-key $PK
```

Set `FLUX_SWAP_PROTOCOL_FEE_BPS` at deploy time (default `30` = 0.3%). Router constructor: `(factory, feeEngine, bps)`.

4. In-protocol **NFT ↔ FT** conversion still uses `ConversionEngine` (conversion fees also go to `FeeEngine`).

---

## vs production Uniswap

- **Native ETH/BNB/MON + single ERC-20** only; no WETH wrapper layer
- No LP ERC-20; Genesis liquidity locked in the pair (`LiquidityVault` registers the pair as core position; no `compound` into that address)
- Not official Uniswap contracts; do not mix with mainnet Pancake/Uniswap liquidity
- For official v4: set `UNISWAP_V4_MIGRATOR`; for legacy no-swap mock: `FLUX_LEGACY_V4_MOCK=true`

---

## References

- Tests: `test/unit/FluxAMM.t.sol`
- Source: `src/integration/flux-amm/`
