# Flux Protocol

> **黑客松公开仓库**：核心合约与 Foundry 脚本（不含前端与子图索引器）。完整产品见私有/主仓库。

Flux Protocol 是一种 NFT/FT 双形态资产协议。每个 Asset Unit 可以在 NFT（ERC-721）与 FT（ERC-20）之间转换，协议总量固定为 10,000 Asset Units：

```text
1 Asset Unit = 1 NFT = 10,000 FLUX
```

Genesis 通过 CCA 风格的统一价格拍卖发行 5,000 Credit，另外 5,000 Asset Units 用于初始化 FLUX/ETH 流动性。Genesis NFT 具有永久手续费分成权，并通过 ERC-6551 风格的 Token Bound Account（TBA）持有已领取奖励。Genesis NFT Burn 时，协议会在同一交易中结算 Pending Reward、清算已登记的 TBA 资产、Burn NFT、Mint 10,000 FLUX，并永久销毁 Genesis Right。

> 当前实现是协议工程基线，尚未经过第三方安全审计。生产环境应配置 Chainlink VRF Coordinator 与 Uniswap V2 Router；本地默认使用 SyncVRF 与 Mock Liquidity Adapter。

## 核心模块

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

- `AssetRegistry`：Asset 状态唯一来源；初始 Credit/FT 区间采用惰性推导，只为发生转换的 Asset 写 Storage。
- `ConversionEngine`：Credit、NFT 和 FT 状态转换的唯一入口。
- `DynamicNFT`：统一承载 Genesis NFT 与普通 NFT，Metadata/SVG 完全链上生成。
- `FluxToken`：支持 Permit 的 ERC-20；只有授权模块可 Mint/Burn。
- `TraitStorage/Generator/Renderer`：Trait 存储、随机生成与链上 Metadata；SVG 由 Body、Face、Head 三个独立链上渲染模块组合，避免单合约体积超限。
- `ERC6551Registry/FluxAccount/AccountManager`：确定性 TBA、Owner 执行权限和 Burn Settlement。
- `RewardAssetRegistry/RewardVault/GenesisVault`：登记奖励资产、资产负债托管和 Pull-based 多资产会计。
- `RewardStrategyManager`：可插拔奖励策略入口；当前提供 Hold ETH 基础策略。
- `BalanceEngine/BalanceVault`：围绕 FT 30%～40%、NFT 60%～70% 的目标区间计算动态 Fee/Reward。
- `GenesisAuction`：Budget + Max Price Bid、链上 CCA 清算、按比例公平分配、Credit Claim 和 LP Bootstrap。

详细设计见：

- [白皮书](docs/whitepaper.md)
- [架构规范](docs/architecture-specification.md)
- [合约技术规范](docs/technical-specification.md)

网络与部署：

- [多链测试网配置](docs/networks.md)
- [Flux Hackathon AMM（可交易 Mock V2）](docs/flux-hackathon-amm.md)

## 环境要求

- Foundry
- Solidity 0.8.26
- OpenZeppelin Contracts 5.4.0
- forge-std 1.9.7

安装 Foundry 后执行：

```bash
forge install
forge build
forge test
```

## 测试与覆盖率

测试包括单元测试、跨模块集成测试、512-run Fuzz round-trip 和状态不变量测试。核心不变量包括：

- Asset Unit 总量始终为 10,000。
- `flux.totalSupply / 10,000` 始终等于 FT Units。
- Genesis Right 不会通过 NFT/FT round-trip 重新产生。
- RewardVault 的资产余额覆盖已记账负债。
- Genesis Burn 先结算登记资产，再销毁 NFT。

运行测试：

```bash
forge test -vv
```

运行覆盖率（不统计测试、脚本和独立 Mock Liquidity Adapter）：

```bash
forge coverage --report summary \
  --skip script \
  --no-match-coverage '(test|script|src/integration/MockLiquidityAdapter.sol)'
```

当前核心合约覆盖率（不含测试、脚本与 MockLiquidityAdapter）：

- Lines：**99.5%** 以上
- Functions：**100%**
- 测试：**63** 项（单元 + 集成 + fuzz + 不变量）

## 全链上像素青蛙

NFT 使用 48×48 像素 SVG，不依赖 IPFS、中心化服务器或外部图片。合约会组合 8 类 Trait：12 种背景色、14 种背景场景、12 种身体颜色、6 种皮肤纹理、16 种眼睛/眼镜、16 种嘴型/嘴部道具、18 种帽子/发型和 6 种附加装饰。Genesis NFT 还会显示专属左上角标记。

Genesis Mint 和 FT 转回 NFT 时会重新生成 Trait。随机种子混合 Asset ID、即将 Mint 的 Token ID、用户 Seed、接收者、Chain ID、当前区块号、`prevrandao`、上一块区块哈希、随机数 Provider 输出和合约地址。生成后的 Trait 固化在链上，NFT 转为 FT 时释放，未来再次转回 NFT 会按新 Token ID 和新区块重新抽取。

> 当前随机方案属于链上伪随机，适合视觉组合，但验证者和交易排序者可能影响区块变量。若稀有 Trait 具有显著经济价值，主网应使用 Chainlink VRF 或 Commit-Reveal，并将 `MockRandomProvider` 替换为正式适配器。

## 本地部署

复制环境变量模板：

```bash
cp .env.example .env
source .env
```

启动本地节点：

```bash
anvil
```

使用 Anvil 账户私钥部署（本地）：

```bash
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network local --broadcast
```

目标测试网（Monad / BSC / HyperEVM）见 [`docs/networks.md`](docs/networks.md)，例如：

```bash
source .env
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast
```

等价于 `forge script ... --rpc-url monad --broadcast`（RPC 来自 `.env`）。

部署地址会写入 `deployments/<chain-id>.json`（本地文件，默认不提交仓库）。`PROTOCOL_ADMIN` 和 `PROTOCOL_TREASURY` 应在正式环境设置为 Safe Multisig/Timelock，而不是个人 EOA。如果设置了不同于部署者的 `PROTOCOL_ADMIN`，部署脚本会授予新管理员权限并撤销部署者的默认管理员权限。

## Genesis Auction 操作

创建 Auction：

```bash
forge script script/StartAuction.s.sol:StartAuction --rpc-url "$RPC_URL" --broadcast
```

提交 Bid：

```bash
forge script script/AuctionActions.s.sol:BidAuction --rpc-url "$RPC_URL" --broadcast
```

结束后自动链上清算并初始化 LP：

```bash
forge script script/AuctionActions.s.sol:FinalizeAuction --rpc-url "$RPC_URL" --broadcast
```

`finalize()` 会根据全部 Bid 计算 Clearing Price、按比例分配 Credit，并原子化 bootstrap FLUX/ETH LP。

领取 Credit：

```bash
forge script script/AuctionActions.s.sol:ClaimAuctionCredit --rpc-url "$RPC_URL" --broadcast
```

Claim 顺序不再影响 Credit 分配；超额认购时采用 pro-rata 公平分配。

## 协议交互

将 Credit 具现化为 Genesis NFT：

```bash
forge script script/ProtocolActions.s.sol:MaterializeGenesisNFT --rpc-url "$RPC_URL" --broadcast
```

将 Credit 具现化为 FT：

```bash
forge script script/ProtocolActions.s.sol:MaterializeFT --rpc-url "$RPC_URL" --broadcast
```

NFT/FT 转换：

```bash
forge script script/ProtocolActions.s.sol:ConvertNFTToFT --rpc-url "$RPC_URL" --broadcast
forge script script/ProtocolActions.s.sol:ConvertFTToNFT --rpc-url "$RPC_URL" --broadcast
```

领取 Genesis Reward 到 TBA：

```bash
forge script script/ProtocolActions.s.sol:ClaimGenesisRewards --rpc-url "$RPC_URL" --broadcast
```

分配 FeeEngine 余额：

```bash
forge script script/ProtocolActions.s.sol:DistributeFees --rpc-url "$RPC_URL" --broadcast
```

各脚本需要的变量可在 [.env.example](.env.example) 中查看。

## 生产部署前检查

1. 配置 `VRF_COORDINATOR` 并接入 Chainlink VRF；本地/测试网可用 `SyncVRFRandomProvider`。
2. 配置 `UNISWAP_V2_ROUTER` 与 `LP_LOCK`，使用 `UniswapV2LiquidityAdapter` 验证 LP 永久锁定。
3. 对 CCA 清算与 pro-rata 分配做独立审计与 fuzz 测试。
4. 为 Reward Strategy 配置 Oracle、最大滑点、Deadline、资产白名单和紧急暂停。
5. 对 TBA 任意调用、恶意 Reward Token、重入、账户转让与 Burn Settlement 做独立审计。
6. 在 Fork Test 中验证目标链上的 WETH、Router、Permit 和 ERC-6551 兼容性。
7. 使用 Safe Multisig + Timelock 接管全部管理员角色。

## License

MIT
