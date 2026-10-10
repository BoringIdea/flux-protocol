# Flux Hackathon AMM（Mock Uniswap V2 风格）

> 在未配置 `UNISWAP_V4_MIGRATOR` 且未设置 `FLUX_LEGACY_V4_MOCK=true` 时，`Deploy.s.sol` 默认部署可 **真实 swap** 的简易 AMM，用于测试网 / 黑客松演示。

---

## 组件

| 合约 | 作用 |
|------|------|
| `FluxAMMFactory` | 每个 FLUX（ERC20）对应一个 `FluxNativePair` |
| `FluxNativePair` | 原生币 + Token 恒定乘积池（0.3% 费），`addLiquidity` / swap |
| `MockUniswapV2Migrator` | 实现 `ILiquidityMigrator`，Genesis `finalize()` 时注入初始流动性 |
| `FluxSwapRouter` | 用户入口：swap + **协议费**（默认 30 bps）转入 `FeeEngine`，类比 Uniswap v4 Hook |
| `FeeEngine` | 接收 Router / Conversion 手续费，`distribute()` 分至 Liquidity / Genesis / Balance / Protocol |

部署产物写入 `deployments/<chainId>.json`：

- `FluxAMMFactory`
- `FluxSwapRouter`
- `LiquidityMigrator` → `MockUniswapV2Migrator`
- `LiquidityVault.genesisPosition` → **Pair 地址**（与 v4 mock 的 bytes32 占位不同，可直接在浏览器查 reserves）

---

## 演示流程

1. 正常 Deploy → StartAuction → bid → **finalize**（池子创建，FLUX + 募集 ETH 入池）
2. 用 `cast` 或脚本在 Router 上 swap：

```bash
# .env 中设置 FLUX_SWAP_ROUTER、FluxToken（来自 deployments JSON）

forge script script/SwapActions.s.sol:SwapETHForFlux \
  --rpc-url monad_testnet --broadcast

forge script script/SwapActions.s.sol:SwapFluxForETH \
  --rpc-url monad_testnet --broadcast
```

3. Swap 产生的协议费进入 `FeeEngine`（与主网 v4 **Hook → FeeEngine** 路径一致；此处由 Router 代扣）：

```bash
# 查看 FeeEngine 余额后分配
cast balance $FEE_ENGINE --rpc-url monad_testnet
cast send $FEE_ENGINE "distribute()" --rpc-url monad_testnet --private-key $PK
```

部署时可设 `FLUX_SWAP_PROTOCOL_FEE_BPS`（默认 `30` = 0.3%），Router 构造参数为 `(factory, feeEngine, bps)`。

4. 协议内 **NFT ↔ FT 转换** 仍走 `ConversionEngine`（转换费同样进 `FeeEngine`）。

---

## 与正式 Uniswap 的差异

- 仅 **原生 ETH/BNB/MON + 单 ERC20**，无 WETH 包装层
- 无 LP ERC20；Genesis 流动性锁在 Pair 合约内（`LiquidityVault` 登记该 Pair 为 core position，不可 `compound` 到该地址）
- 非 Uniswap 官方合约；**不要** 与主网 Pancake/Uniswap 流动性混为一谈
- 需要官方 v4 时：设置 `UNISWAP_V4_MIGRATOR`；需要旧的无 swap mock：设置 `FLUX_LEGACY_V4_MOCK=true`

---

## 参考

- 测试：`test/unit/FluxAMM.t.sol`
- 源码：`src/integration/flux-amm/`
