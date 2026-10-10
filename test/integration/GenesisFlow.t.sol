// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { AssetRegistry } from "../../src/core/AssetRegistry.sol";
import { CreditManager } from "../../src/core/CreditManager.sol";
import { ConversionEngine } from "../../src/core/ConversionEngine.sol";
import { FluxToken } from "../../src/token/FluxToken.sol";
import { DynamicNFT } from "../../src/token/DynamicNFT.sol";
import { TraitStorage } from "../../src/trait/TraitStorage.sol";
import { TraitGenerator } from "../../src/trait/TraitGenerator.sol";
import { TraitRenderer } from "../../src/trait/TraitRenderer.sol";
import { FrogBodyRenderer } from "../../src/trait/FrogBodyRenderer.sol";
import { FrogFaceRenderer } from "../../src/trait/FrogFaceRenderer.sol";
import { FrogHeadRenderer } from "../../src/trait/FrogHeadRenderer.sol";
import { SyncVRFRandomProvider } from "../../src/integration/SyncVRFRandomProvider.sol";
import { MockUniswapV4Migrator } from "../../src/integration/MockUniswapV4Migrator.sol";
import { GenesisAuction } from "../../src/genesis/GenesisAuction.sol";
import { GenesisAuctionClaimHelper } from "../helpers/GenesisAuctionClaimHelper.sol";
import { LiquidityVault } from "../../src/vault/LiquidityVault.sol";
import { BalanceEngine } from "../../src/economic/BalanceEngine.sol";
import { BalanceVault } from "../../src/vault/BalanceVault.sol";
import { ProtocolVault } from "../../src/vault/ProtocolVault.sol";
import { RewardAssetRegistry } from "../../src/economic/RewardAssetRegistry.sol";
import { RewardVault } from "../../src/economic/RewardVault.sol";
import { GenesisVault } from "../../src/economic/GenesisVault.sol";
import { RewardStrategyManager } from "../../src/economic/RewardStrategyManager.sol";
import { FeeEngine } from "../../src/economic/FeeEngine.sol";
import { ERC6551Registry } from "../../src/account/ERC6551Registry.sol";
import { FluxAccount } from "../../src/account/FluxAccount.sol";
import { AccountManager } from "../../src/account/AccountManager.sol";
import {
    IFluxToken,
    IDynamicNFT,
    ITraitGenerator,
    IBalanceVault,
    IAccountManager,
    IGenesisVault
} from "../../src/interfaces/IFlux.sol";

/// @notice End-to-end: CCA auction -> credit claim -> genesis NFT -> fee distribute -> claim reward.
contract GenesisFlowIntegrationTest is GenesisAuctionClaimHelper {
    address internal admin = makeAddr("admin");
    address internal bidder = makeAddr("bidder");
    address internal treasury = makeAddr("treasury");

    AssetRegistry internal registry;
    CreditManager internal credits;
    FluxToken internal flux;
    DynamicNFT internal nft;
    ConversionEngine internal conversion;
    GenesisAuction internal auction;
    GenesisVault internal genesisVault;
    FeeEngine internal feeEngine;
    AccountManager internal accountManager;
    BalanceVault internal balanceVault;
    LiquidityVault internal liquidityVault;

    function setUp() public {
        vm.startPrank(admin);
        registry = new AssetRegistry(admin);
        registry.initializeGenesis(5_000);
        credits = new CreditManager(admin);
        flux = new FluxToken(admin);

        TraitStorage traitStorage = new TraitStorage(admin);
        SyncVRFRandomProvider random = new SyncVRFRandomProvider();
        TraitGenerator traitGenerator = new TraitGenerator(admin, traitStorage, random);
        TraitRenderer renderer = new TraitRenderer(
            traitStorage,
            new FrogBodyRenderer(),
            new FrogFaceRenderer(),
            new FrogHeadRenderer()
        );
        nft = new DynamicNFT(admin, renderer);

        RewardAssetRegistry rewardAssets = new RewardAssetRegistry(admin);
        rewardAssets.registerAsset(address(0), RewardAssetRegistry.AssetType.Native, address(0));
        RewardVault rewardVault = new RewardVault(admin);
        genesisVault = new GenesisVault(admin, rewardVault, rewardAssets);

        ERC6551Registry accountRegistry = new ERC6551Registry(
            admin,
            address(new FluxAccount(address(nft), 0, address(0), block.chainid, address(0)))
        );
        accountManager =
            new AccountManager(admin, accountRegistry, rewardAssets, address(nft));
        accountRegistry.setManager(address(accountManager));
        genesisVault.setAccountManager(accountManager);

        BalanceEngine balanceEngine = new BalanceEngine(admin);
        balanceVault = new BalanceVault(admin);
        liquidityVault = new LiquidityVault(admin);
        RewardStrategyManager rewardStrategy = new RewardStrategyManager(admin, rewardVault, genesisVault);
        ProtocolVault protocolVault = new ProtocolVault(admin, treasury);
        feeEngine = new FeeEngine(admin, liquidityVault, rewardStrategy, balanceVault, protocolVault);

        conversion = new ConversionEngine(
            admin,
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

        auction = new GenesisAuction(
            admin,
            credits,
            IFluxToken(address(flux)),
            new MockUniswapV4Migrator(),
            liquidityVault
        );

        registry.grantRole(registry.CONTROLLER_ROLE(), address(conversion));
        credits.grantRole(credits.CONSUMER_ROLE(), address(conversion));
        credits.grantRole(credits.ISSUER_ROLE(), address(auction));
        flux.grantRole(flux.MINTER_ROLE(), address(conversion));
        flux.grantRole(flux.MINTER_ROLE(), address(auction));
        flux.grantRole(flux.BURNER_ROLE(), address(conversion));
        nft.grantRole(nft.MINTER_ROLE(), address(conversion));
        nft.grantRole(nft.BURNER_ROLE(), address(conversion));
        traitStorage.grantRole(traitStorage.GENERATOR_ROLE(), address(traitGenerator));
        traitGenerator.grantRole(traitGenerator.CALLER_ROLE(), address(conversion));
        genesisVault.grantRole(genesisVault.CONTROLLER_ROLE(), address(conversion));
        genesisVault.grantRole(genesisVault.DEPOSITOR_ROLE(), address(rewardStrategy));
        rewardVault.grantRole(rewardVault.ACCOUNTANT_ROLE(), address(genesisVault));
        rewardStrategy.grantRole(rewardStrategy.EXECUTOR_ROLE(), address(feeEngine));
        balanceVault.grantRole(balanceVault.REWARDER_ROLE(), address(conversion));
        accountManager.grantRole(accountManager.SETTLEMENT_ROLE(), address(conversion));
        liquidityVault.grantRole(liquidityVault.GENESIS_REGISTRAR_ROLE(), address(auction));
        vm.stopPrank();

        vm.deal(bidder, 20_000 ether);
    }

    function testFullGenesisToRewardFlow() public {
        vm.startPrank(admin);
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 3 days));
        vm.stopPrank();

        vm.prank(bidder);
        auction.bid{ value: 10_000 ether }(2 ether);
        vm.warp(block.timestamp + 3 days);

        vm.prank(admin);
        auction.finalize();

        claimAllCredits(auction, bidder);
        assertEq(credits.balanceOf(bidder), 5_000);

        vm.startPrank(bidder);
        uint256 tokenId = conversion.materializeGenesisNFT(1, 12345);
        assertTrue(nft.isGenesis(tokenId));
        assertEq(genesisVault.activeGenesisSupply(), 1);
        vm.stopPrank();

        vm.deal(address(feeEngine), 10 ether);
        vm.prank(admin);
        feeEngine.distribute();

        assertGt(genesisVault.pending(tokenId, address(0)), 0);
        vm.prank(bidder);
        genesisVault.claimAllRegistered(tokenId);
        address tba = accountManager.account(tokenId);
        assertGt(tba.balance, 0);
        assertTrue(liquidityVault.genesisPositionRegistered());
    }

    function testAuctionCreditMaterializeFTPath() public {
        vm.prank(admin);
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 1 days));
        vm.prank(bidder);
        auction.bid{ value: 10_000 ether }(2 ether);
        vm.warp(block.timestamp + 1 days);
        vm.prank(admin);
        auction.finalize();
        claimAllCredits(auction, bidder);

        vm.prank(bidder);
        conversion.materializeFT(2);
        assertEq(flux.balanceOf(bidder), 10_000 ether);
        assertEq(registry.stateCount(AssetRegistry.AssetState.Credit), 4_999);
    }
}
