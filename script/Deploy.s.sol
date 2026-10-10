// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";
import { AssetRegistry } from "../src/core/AssetRegistry.sol";
import { CreditManager } from "../src/core/CreditManager.sol";
import { ConversionEngine } from "../src/core/ConversionEngine.sol";
import { FluxToken } from "../src/token/FluxToken.sol";
import { DynamicNFT } from "../src/token/DynamicNFT.sol";
import { TraitStorage } from "../src/trait/TraitStorage.sol";
import { TraitGenerator } from "../src/trait/TraitGenerator.sol";
import { TraitRenderer } from "../src/trait/TraitRenderer.sol";
import { FrogBodyRenderer } from "../src/trait/FrogBodyRenderer.sol";
import { FrogFaceRenderer } from "../src/trait/FrogFaceRenderer.sol";
import { FrogHeadRenderer } from "../src/trait/FrogHeadRenderer.sol";
import { SyncVRFRandomProvider } from "../src/integration/SyncVRFRandomProvider.sol";
import { ChainlinkVRFRandomProvider } from "../src/integration/ChainlinkVRFRandomProvider.sol";
import { MockLiquidityAdapter } from "../src/integration/MockLiquidityAdapter.sol";
import { MockUniswapV4Migrator } from "../src/integration/MockUniswapV4Migrator.sol";
import { FluxAMMFactory } from "../src/integration/flux-amm/FluxAMMFactory.sol";
import { FluxSwapRouter } from "../src/integration/flux-amm/FluxSwapRouter.sol";
import { MockUniswapV2Migrator } from "../src/integration/flux-amm/MockUniswapV2Migrator.sol";
import { UniswapV2LiquidityAdapter } from "../src/integration/UniswapV2LiquidityAdapter.sol";
import { ILiquidityAdapter } from "../src/interfaces/ILiquidityAdapter.sol";
import { ILiquidityMigrator } from "../src/interfaces/ILiquidityMigrator.sol";
import { UniswapV4LiquidityMigrator } from "../src/integration/UniswapV4LiquidityMigrator.sol";
import { FluxAccount } from "../src/account/FluxAccount.sol";
import { BalanceEngine } from "../src/economic/BalanceEngine.sol";
import { BalanceVault } from "../src/vault/BalanceVault.sol";
import { LiquidityVault } from "../src/vault/LiquidityVault.sol";
import { ProtocolVault } from "../src/vault/ProtocolVault.sol";
import { RewardAssetRegistry } from "../src/economic/RewardAssetRegistry.sol";
import { RewardVault } from "../src/economic/RewardVault.sol";
import { GenesisVault } from "../src/economic/GenesisVault.sol";
import { RewardStrategyManager } from "../src/economic/RewardStrategyManager.sol";
import { FeeEngine } from "../src/economic/FeeEngine.sol";
import { ERC6551Registry } from "../src/account/ERC6551Registry.sol";
import { AccountManager } from "../src/account/AccountManager.sol";
import { GenesisAuction } from "../src/genesis/GenesisAuction.sol";
import {
    IFluxToken,
    IDynamicNFT,
    ITraitGenerator,
    IBalanceVault,
    IAccountManager,
    IGenesisVault,
    IRandomProvider
} from "../src/interfaces/IFlux.sol";

contract Deploy is Script {
    struct Deployment {
        AssetRegistry registry;
        CreditManager credits;
        FluxToken flux;
        DynamicNFT nft;
        ConversionEngine conversion;
        GenesisAuction auction;
        FeeEngine feeEngine;
        GenesisVault genesisVault;
        RewardVault rewardVault;
        RewardStrategyManager rewardStrategy;
        AccountManager accountManager;
        ERC6551Registry accountRegistry;
        TraitStorage traitStorage;
        TraitGenerator traitGenerator;
        FrogBodyRenderer frogBodyRenderer;
        FrogFaceRenderer frogFaceRenderer;
        FrogHeadRenderer frogHeadRenderer;
        TraitRenderer traitRenderer;
    }

    function run() external returns (Deployment memory d) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        address finalAdmin = vm.envOr("PROTOCOL_ADMIN", deployer);
        address treasury = vm.envOr("PROTOCOL_TREASURY", deployer);
        address lpLock = vm.envOr("LP_LOCK", address(0xdead));
        address uniswapRouter = vm.envOr("UNISWAP_V2_ROUTER", address(0));
        address vrfCoordinator = vm.envOr("VRF_COORDINATOR", address(0));

        vm.startBroadcast(privateKey);

        d.registry = new AssetRegistry(deployer);
        d.registry.initializeGenesis(5_000);
        d.credits = new CreditManager(deployer);
        d.flux = new FluxToken(deployer);

        TraitStorage traitStorage = new TraitStorage(deployer);
        IRandomProvider randomProvider = vrfCoordinator == address(0)
            ? IRandomProvider(address(new SyncVRFRandomProvider()))
            : IRandomProvider(address(new ChainlinkVRFRandomProvider(vrfCoordinator)));
        TraitGenerator traitGenerator = new TraitGenerator(deployer, traitStorage, randomProvider);
        FrogBodyRenderer frogBodyRenderer = new FrogBodyRenderer();
        FrogFaceRenderer frogFaceRenderer = new FrogFaceRenderer();
        FrogHeadRenderer frogHeadRenderer = new FrogHeadRenderer();
        TraitRenderer renderer =
            new TraitRenderer(traitStorage, frogBodyRenderer, frogFaceRenderer, frogHeadRenderer);
        d.traitStorage = traitStorage;
        d.traitGenerator = traitGenerator;
        d.frogBodyRenderer = frogBodyRenderer;
        d.frogFaceRenderer = frogFaceRenderer;
        d.frogHeadRenderer = frogHeadRenderer;
        d.traitRenderer = renderer;
        d.nft = new DynamicNFT(deployer, renderer);
        address accountImplementation = address(
            new FluxAccount(address(d.nft), type(uint256).max, address(0), block.chainid, address(0))
        );

        RewardAssetRegistry rewardAssets = new RewardAssetRegistry(deployer);
        rewardAssets.registerAsset(address(0), RewardAssetRegistry.AssetType.Native, address(0));
        d.rewardVault = new RewardVault(deployer);
        d.genesisVault = new GenesisVault(deployer, d.rewardVault, rewardAssets);
        d.accountRegistry = new ERC6551Registry(deployer, accountImplementation);
        d.accountManager =
            new AccountManager(deployer, d.accountRegistry, rewardAssets, address(d.nft));
        d.accountRegistry.setManager(address(d.accountManager));
        d.genesisVault.setAccountManager(d.accountManager);

        BalanceEngine balanceEngine = new BalanceEngine(deployer);
        BalanceVault balanceVault = new BalanceVault(deployer);
        LiquidityVault liquidityVault = new LiquidityVault(deployer);
        address v4Migrator = vm.envOr("UNISWAP_V4_MIGRATOR", address(0));
        bool legacyV4Mock = vm.envOr("FLUX_LEGACY_V4_MOCK", false);
        FluxAMMFactory fluxFactory;
        FluxSwapRouter fluxRouter;
        ILiquidityMigrator liquidityMigrator;
        if (v4Migrator != address(0)) {
            liquidityMigrator = ILiquidityMigrator(address(new UniswapV4LiquidityMigrator(v4Migrator)));
        } else if (legacyV4Mock) {
            liquidityMigrator = ILiquidityMigrator(address(new MockUniswapV4Migrator()));
        } else {
            fluxFactory = new FluxAMMFactory();
            liquidityMigrator = ILiquidityMigrator(address(new MockUniswapV2Migrator(fluxFactory)));
        }
        ILiquidityAdapter liquidityCompoundAdapter = uniswapRouter == address(0)
            ? ILiquidityAdapter(address(new MockLiquidityAdapter()))
            : ILiquidityAdapter(address(new UniswapV2LiquidityAdapter(uniswapRouter, lpLock)));
        ProtocolVault protocolVault = new ProtocolVault(deployer, treasury);
        d.rewardStrategy = new RewardStrategyManager(deployer, d.rewardVault, d.genesisVault);
        d.feeEngine =
            new FeeEngine(deployer, liquidityVault, d.rewardStrategy, balanceVault, protocolVault);

        if (address(fluxFactory) != address(0)) {
            uint16 swapProtocolFeeBps = uint16(vm.envOr("FLUX_SWAP_PROTOCOL_FEE_BPS", uint256(30)));
            fluxRouter = new FluxSwapRouter(fluxFactory, address(d.feeEngine), swapProtocolFeeBps);
        }

        d.conversion = new ConversionEngine(
            deployer,
            d.registry,
            d.credits,
            IFluxToken(address(d.flux)),
            IDynamicNFT(address(d.nft)),
            ITraitGenerator(address(traitGenerator)),
            balanceEngine,
            IBalanceVault(address(balanceVault)),
            IAccountManager(address(d.accountManager)),
            IGenesisVault(address(d.genesisVault)),
            address(d.feeEngine)
        );
        d.auction = new GenesisAuction(
            deployer,
            d.credits,
            IFluxToken(address(d.flux)),
            liquidityMigrator,
            liquidityVault
        );

        d.registry.grantRole(d.registry.CONTROLLER_ROLE(), address(d.conversion));
        d.credits.grantRole(d.credits.CONSUMER_ROLE(), address(d.conversion));
        d.credits.grantRole(d.credits.ISSUER_ROLE(), address(d.auction));
        d.flux.grantRole(d.flux.MINTER_ROLE(), address(d.conversion));
        d.flux.grantRole(d.flux.MINTER_ROLE(), address(d.auction));
        d.flux.grantRole(d.flux.BURNER_ROLE(), address(d.conversion));
        d.nft.grantRole(d.nft.MINTER_ROLE(), address(d.conversion));
        d.nft.grantRole(d.nft.BURNER_ROLE(), address(d.conversion));
        traitStorage.grantRole(traitStorage.GENERATOR_ROLE(), address(traitGenerator));
        traitGenerator.grantRole(traitGenerator.CALLER_ROLE(), address(d.conversion));
        d.genesisVault.grantRole(d.genesisVault.CONTROLLER_ROLE(), address(d.conversion));
        d.genesisVault.grantRole(d.genesisVault.DEPOSITOR_ROLE(), address(d.rewardStrategy));
        d.rewardVault.grantRole(d.rewardVault.ACCOUNTANT_ROLE(), address(d.genesisVault));
        d.rewardStrategy.grantRole(d.rewardStrategy.EXECUTOR_ROLE(), address(d.feeEngine));
        balanceVault.grantRole(balanceVault.REWARDER_ROLE(), address(d.conversion));
        d.accountManager.grantRole(d.accountManager.SETTLEMENT_ROLE(), address(d.conversion));
        liquidityVault.grantRole(liquidityVault.GENESIS_REGISTRAR_ROLE(), address(d.auction));

        if (finalAdmin != deployer) {
            _handoff(
                d,
                finalAdmin,
                deployer,
                traitStorage,
                traitGenerator,
                rewardAssets,
                balanceEngine,
                balanceVault,
                liquidityVault,
                protocolVault
            );
        }
        vm.stopBroadcast();

        _writeDeployment(
            d,
            traitStorage,
            traitGenerator,
            rewardAssets,
            balanceEngine,
            balanceVault,
            liquidityVault,
            protocolVault,
            liquidityMigrator,
            liquidityCompoundAdapter,
            address(fluxFactory),
            address(fluxRouter)
        );
    }

    function _handoff(
        Deployment memory d,
        address finalAdmin,
        address oldAdmin,
        TraitStorage traitStorage,
        TraitGenerator traitGenerator,
        RewardAssetRegistry rewardAssets,
        BalanceEngine balanceEngine,
        BalanceVault balanceVault,
        LiquidityVault liquidityVault,
        ProtocolVault protocolVault
    ) internal {
        d.registry.grantRole(0, finalAdmin);
        d.credits.grantRole(0, finalAdmin);
        d.flux.grantRole(0, finalAdmin);
        d.nft.grantRole(0, finalAdmin);
        traitStorage.grantRole(0, finalAdmin);
        traitGenerator.grantRole(0, finalAdmin);
        rewardAssets.grantRole(0, finalAdmin);
        d.rewardVault.grantRole(0, finalAdmin);
        d.genesisVault.grantRole(0, finalAdmin);
        balanceEngine.grantRole(0, finalAdmin);
        balanceVault.grantRole(0, finalAdmin);
        liquidityVault.grantRole(0, finalAdmin);
        protocolVault.grantRole(0, finalAdmin);
        d.rewardStrategy.grantRole(0, finalAdmin);
        d.feeEngine.grantRole(0, finalAdmin);
        d.accountManager.grantRole(0, finalAdmin);
        d.conversion.grantRole(0, finalAdmin);
        d.auction.grantRole(0, finalAdmin);
        d.accountRegistry.transferAdmin(finalAdmin);

        d.registry.renounceRole(0, oldAdmin);
        d.credits.renounceRole(0, oldAdmin);
        d.flux.renounceRole(0, oldAdmin);
        d.nft.renounceRole(0, oldAdmin);
        traitStorage.renounceRole(0, oldAdmin);
        traitGenerator.renounceRole(0, oldAdmin);
        rewardAssets.renounceRole(0, oldAdmin);
        d.rewardVault.renounceRole(0, oldAdmin);
        d.genesisVault.renounceRole(0, oldAdmin);
        balanceEngine.renounceRole(0, oldAdmin);
        balanceVault.renounceRole(0, oldAdmin);
        liquidityVault.renounceRole(0, oldAdmin);
        protocolVault.renounceRole(0, oldAdmin);
        d.rewardStrategy.renounceRole(0, oldAdmin);
        d.feeEngine.renounceRole(0, oldAdmin);
        d.accountManager.renounceRole(0, oldAdmin);
        d.conversion.renounceRole(0, oldAdmin);
        d.auction.renounceRole(0, oldAdmin);
    }

    function _writeDeployment(
        Deployment memory d,
        TraitStorage traitStorage,
        TraitGenerator traitGenerator,
        RewardAssetRegistry rewardAssets,
        BalanceEngine balanceEngine,
        BalanceVault balanceVault,
        LiquidityVault liquidityVault,
        ProtocolVault protocolVault,
        ILiquidityMigrator liquidityMigrator,
        ILiquidityAdapter liquidityCompoundAdapter,
        address fluxFactory,
        address fluxRouter
    ) internal {
        string memory key = "deployment";
        vm.serializeAddress(key, "AssetRegistry", address(d.registry));
        vm.serializeAddress(key, "CreditManager", address(d.credits));
        vm.serializeAddress(key, "FluxToken", address(d.flux));
        vm.serializeAddress(key, "DynamicNFT", address(d.nft));
        vm.serializeAddress(key, "TraitStorage", address(traitStorage));
        vm.serializeAddress(key, "TraitGenerator", address(traitGenerator));
        vm.serializeAddress(key, "FrogBodyRenderer", address(d.frogBodyRenderer));
        vm.serializeAddress(key, "FrogFaceRenderer", address(d.frogFaceRenderer));
        vm.serializeAddress(key, "FrogHeadRenderer", address(d.frogHeadRenderer));
        vm.serializeAddress(key, "TraitRenderer", address(d.traitRenderer));
        vm.serializeAddress(key, "RewardAssetRegistry", address(rewardAssets));
        vm.serializeAddress(key, "RewardVault", address(d.rewardVault));
        vm.serializeAddress(key, "GenesisVault", address(d.genesisVault));
        vm.serializeAddress(key, "RewardStrategyManager", address(d.rewardStrategy));
        vm.serializeAddress(key, "BalanceEngine", address(balanceEngine));
        vm.serializeAddress(key, "BalanceVault", address(balanceVault));
        vm.serializeAddress(key, "LiquidityVault", address(liquidityVault));
        vm.serializeAddress(key, "LiquidityMigrator", address(liquidityMigrator));
        vm.serializeAddress(key, "LiquidityCompoundAdapter", address(liquidityCompoundAdapter));
        vm.serializeAddress(key, "FluxAMMFactory", fluxFactory);
        vm.serializeAddress(key, "FluxSwapRouter", fluxRouter);
        vm.serializeAddress(key, "ProtocolVault", address(protocolVault));
        vm.serializeAddress(key, "FeeEngine", address(d.feeEngine));
        vm.serializeAddress(key, "ERC6551Registry", address(d.accountRegistry));
        vm.serializeAddress(key, "AccountManager", address(d.accountManager));
        vm.serializeAddress(key, "ConversionEngine", address(d.conversion));
        string memory json = vm.serializeAddress(key, "GenesisAuction", address(d.auction));
        vm.writeJson(json, string.concat("deployments/", vm.toString(block.chainid), ".json"));
    }
}
