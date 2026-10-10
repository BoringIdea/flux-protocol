# 目标网络配置

当前计划部署的 **测试网**（可通过配置切换，无需改合约代码）：

| CLI `--network` | Chain ID | 原生 gas | Foundry `--rpc-url` | 部署 JSON |
|-----------------|----------|----------|---------------------|-----------|
| `monad` | 10143 | MON | `monad` | `deployments/10143.json` |
| `bsc` | 97 | BNB | `bsc` | `deployments/97.json` |
| `hyperliquid` | 998 | HYPE | `hyperliquid` | `deployments/998.json` |
| `local` | 31337* | ETH | `local` | `deployments/<chainId>.json` |

\* Anvil 默认 chain id 可能为 31337，以实际 `block.chainid` 为准。

## 配置文件

| 文件 | 用途 |
|------|------|
| [`config/networks.json`](../config/networks.json) | 网络元数据、默认网络、BSC 的 `--legacy` 等 |
| [`.env`](../.env.example) | `PRIVATE_KEY`、各链 RPC URL |
| `deployments/<chainId>.json` | Forge 部署输出（本地，默认不提交） |

环境变量：

- `FLUX_NETWORK` / `DEPLOY_CHAIN` — 默认 `monad`（给 `flux-forge.sh` 省略 `--network` 时用）
- `MONAD_TESTNET_RPC_URL`
- `BSC_TESTNET_RPC_URL`
- `HYPERLIQUID_TESTNET_RPC_URL`

## Foundry 脚本

推荐包装脚本（支持 `--network`）：

```bash
chmod +x script/flux-forge.sh

# 部署
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast

# BSC 测试网（脚本会自动加 --legacy）
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network bsc --broadcast

# HyperEVM 测试网
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network hyperliquid --broadcast
```

也可直接使用 Foundry 别名（需已 `source .env`）：

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url monad --broadcast
forge script script/Deploy.s.sol:Deploy --rpc-url bsc --broadcast --legacy
forge script script/Deploy.s.sol:Deploy --rpc-url hyperliquid --broadcast
```

## 链专属说明

- [flux-hackathon-amm.md](./flux-hackathon-amm.md) — 可交易 Mock AMM（Monad 测试网推荐）
- Monad Testnet：Chain ID **10143**，RPC `https://testnet-rpc.monad.xyz`，水龙头 [faucet.monad.xyz](https://faucet.monad.xyz)
- HyperEVM：官方 RPC `https://rpc.hyperliquid-testnet.xyz/evm`，Chain ID **998**

## 多链分支（提交前核对）

同一代码库用 **配置驱动** 切换链，各链分支建议只改环境与部署产物：

| 仅在本分支改 | 说明 |
|--------------|------|
| `config/networks.json` 的 `defaultNetwork` | 如 `bsc` / `hyperliquid` |
| `deployments/<chainId>.json` | 该链合约地址（Forge 输出） |
| 根目录 `.env`（不提交） | `FLUX_NETWORK`、各链 RPC |
