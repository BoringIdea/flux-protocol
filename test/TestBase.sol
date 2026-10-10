// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
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
import { FluxAccount } from "../src/account/FluxAccount.sol";
import { AccountManager } from "../src/account/AccountManager.sol";
import {
    IFluxToken,
    IDynamicNFT,
    ITraitGenerator,
    IBalanceVault,
    IAccountManager,
    IGenesisVault
} from "../src/interfaces/IFlux.sol";

abstract contract TestBase is Test {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal treasury = makeAddr("treasury");

    AssetRegistry internal registry;
    CreditManager internal credits;
    ConversionEngine internal conversion;
    FluxToken internal flux;
    DynamicNFT internal nft;
    TraitStorage internal traitStorage;
    TraitGenerator internal traitGenerator;
    TraitRenderer internal renderer;
    SyncVRFRandomProvider internal random;
    BalanceEngine internal balanceEngine;
    BalanceVault internal balanceVault;
    LiquidityVault internal liquidityVault;
    ProtocolVault internal protocolVault;
    RewardAssetRegistry internal rewardAssets;
    RewardVault internal rewardVault;
    GenesisVault internal genesisVault;
    RewardStrategyManager internal rewardStrategy;
    FeeEngine internal feeEngine;
    ERC6551Registry internal accountRegistry;
    AccountManager internal accountManager;

    function setUp() public virtual {
        registry = new AssetRegistry(address(this));
        registry.initializeGenesis(5_000);
        credits = new CreditManager(address(this));
        flux = new FluxToken(address(this));

        traitStorage = new TraitStorage(address(this));
        random = new SyncVRFRandomProvider();
        traitGenerator = new TraitGenerator(address(this), traitStorage, random);
        renderer = new TraitRenderer(
            traitStorage, new FrogBodyRenderer(), new FrogFaceRenderer(), new FrogHeadRenderer()
        );
        nft = new DynamicNFT(address(this), renderer);

        rewardAssets = new RewardAssetRegistry(address(this));
        rewardAssets.registerAsset(address(0), RewardAssetRegistry.AssetType.Native, address(0));
        rewardVault = new RewardVault(address(this));
        genesisVault = new GenesisVault(address(this), rewardVault, rewardAssets);

        accountRegistry = new ERC6551Registry(address(this), address(0));
        accountRegistry.setImplementation(
            address(new FluxAccount(address(nft), type(uint256).max, address(0), block.chainid, address(0)))
        );
        accountManager =
            new AccountManager(address(this), accountRegistry, rewardAssets, address(nft));
        accountRegistry.setManager(address(accountManager));
        genesisVault.setAccountManager(accountManager);

        balanceEngine = new BalanceEngine(address(this));
        balanceVault = new BalanceVault(address(this));
        liquidityVault = new LiquidityVault(address(this));
        protocolVault = new ProtocolVault(address(this), treasury);
        flux.grantRole(flux.MINTER_ROLE(), address(this));
        flux.mint(address(liquidityVault), 50_000_000 ether);
        rewardStrategy = new RewardStrategyManager(address(this), rewardVault, genesisVault);
        feeEngine = new FeeEngine(
            address(this), liquidityVault, rewardStrategy, balanceVault, protocolVault
        );

        conversion = new ConversionEngine(
            address(this),
            registry,
            credits,
            IFluxToken(address(flux)),
            IDynamicNFT(address(nft)),
            ITraitGenerator(address(traitGenerator)),
            balanceEngine,
            IBalanceVault(address(balanceVault)),
            IAccountManager(address(accountManager)),
            IGenesisVault(address(genesisVault)),
            address(feeEngine)
        );

        registry.grantRole(registry.CONTROLLER_ROLE(), address(conversion));
        credits.grantRole(credits.CONSUMER_ROLE(), address(conversion));
        credits.grantRole(credits.ISSUER_ROLE(), address(this));
        flux.grantRole(flux.MINTER_ROLE(), address(conversion));
        flux.grantRole(flux.BURNER_ROLE(), address(conversion));
        nft.grantRole(nft.MINTER_ROLE(), address(conversion));
        nft.grantRole(nft.BURNER_ROLE(), address(conversion));
        traitStorage.grantRole(traitStorage.GENERATOR_ROLE(), address(traitGenerator));
        traitGenerator.grantRole(traitGenerator.CALLER_ROLE(), address(conversion));
        genesisVault.grantRole(genesisVault.CONTROLLER_ROLE(), address(conversion));
        genesisVault.grantRole(genesisVault.DEPOSITOR_ROLE(), address(rewardStrategy));
        genesisVault.grantRole(genesisVault.DEPOSITOR_ROLE(), address(this));
        rewardVault.grantRole(rewardVault.ACCOUNTANT_ROLE(), address(genesisVault));
        rewardStrategy.grantRole(rewardStrategy.EXECUTOR_ROLE(), address(feeEngine));
        rewardStrategy.grantRole(rewardStrategy.EXECUTOR_ROLE(), address(this));
        balanceVault.grantRole(balanceVault.REWARDER_ROLE(), address(conversion));
        accountManager.grantRole(accountManager.SETTLEMENT_ROLE(), address(conversion));

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(address(balanceVault), 10 ether);
    }

    function _issue(address to, uint256 assetId) internal {
        credits.issue(to, assetId);
    }

    function _mintGenesis(address to, uint256 assetId) internal returns (uint256 tokenId) {
        _issue(to, assetId);
        vm.prank(to);
        tokenId = conversion.materializeGenesisNFT(assetId, assetId * 17);
    }

    function _mintFT(address to, uint256 assetId) internal {
        _issue(to, assetId);
        vm.prank(to);
        conversion.materializeFT(assetId);
    }
}
