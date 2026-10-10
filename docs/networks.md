# Target networks

Planned **testnets** (switch via config without changing contract code):

| CLI `--network` | Chain ID | Native gas | Foundry `--rpc-url` | Deployment JSON |
|-----------------|----------|------------|---------------------|-----------------|
| `monad` | 10143 | MON | `monad` | `deployments/10143.json` |
| `bsc` | 97 | BNB | `bsc` | `deployments/97.json` |
| `hyperliquid` | 998 | HYPE | `hyperliquid` | `deployments/998.json` |
| `local` | 31337* | ETH | `local` | `deployments/<chainId>.json` |

\* Anvil’s default chain id is often 31337; use the live `block.chainid`.

中文：[networks.zh.md](./networks.zh.md)

## Config files

| File | Purpose |
|------|---------|
| [`config/networks.json`](../config/networks.json) | Network metadata, default network, BSC `--legacy`, etc. |
| [`.env`](../.env.example) | `PRIVATE_KEY`, per-chain RPC URLs |
| `deployments/<chainId>.json` | Forge deployment output (local; not committed by default) |

Environment variables:

- `FLUX_NETWORK` / `DEPLOY_CHAIN` — default `monad` when `flux-forge.sh` omits `--network`
- `MONAD_TESTNET_RPC_URL`
- `BSC_TESTNET_RPC_URL`
- `HYPERLIQUID_TESTNET_RPC_URL`

## Foundry scripts

Recommended wrapper (supports `--network`):

```bash
chmod +x script/flux-forge.sh

# Deploy
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast

# BSC testnet (script adds --legacy)
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network bsc --broadcast

# HyperEVM testnet
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network hyperliquid --broadcast
```

Or use Foundry RPC aliases (after `source .env`):

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url monad --broadcast
forge script script/Deploy.s.sol:Deploy --rpc-url bsc --broadcast --legacy
forge script script/Deploy.s.sol:Deploy --rpc-url hyperliquid --broadcast
```

## Chain notes

- [flux-hackathon-amm.md](./flux-hackathon-amm.md) — swappable mock AMM (recommended on Monad testnet)
- **Monad testnet:** chain ID **10143**, RPC `https://testnet-rpc.monad.xyz`, faucet [faucet.monad.xyz](https://faucet.monad.xyz)
- **HyperEVM:** RPC `https://rpc.hyperliquid-testnet.xyz/evm`, chain ID **998**

## Multi-chain branches (pre-submit checklist)

This repo switches chains via **config**; per-chain branches should only change env and deployment artifacts:

| Change on branch only | Notes |
|------------------------|-------|
| `config/networks.json` → `defaultNetwork` | e.g. `bsc` / `hyperliquid` |
| `deployments/<chainId>.json` | Contract addresses (Forge output) |
| Root `.env` (not committed) | `FLUX_NETWORK`, RPC URLs |
