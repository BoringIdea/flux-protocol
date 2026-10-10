// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { FluxToken } from "../../src/token/FluxToken.sol";
import { FluxAMMFactory } from "../../src/integration/flux-amm/FluxAMMFactory.sol";
import { FluxSwapRouter } from "../../src/integration/flux-amm/FluxSwapRouter.sol";
import { FluxNativePair } from "../../src/integration/flux-amm/FluxNativePair.sol";
import { MockUniswapV2Migrator } from "../../src/integration/flux-amm/MockUniswapV2Migrator.sol";
import { GenesisAuction } from "../../src/genesis/GenesisAuction.sol";
import { CreditManager } from "../../src/core/CreditManager.sol";
import { LiquidityVault } from "../../src/vault/LiquidityVault.sol";
import { BalanceVault } from "../../src/vault/BalanceVault.sol";
import { ProtocolVault } from "../../src/vault/ProtocolVault.sol";
import { RewardStrategyManager } from "../../src/economic/RewardStrategyManager.sol";
import { RewardVault } from "../../src/economic/RewardVault.sol";
import { GenesisVault } from "../../src/economic/GenesisVault.sol";
import { RewardAssetRegistry } from "../../src/economic/RewardAssetRegistry.sol";
import { FeeEngine } from "../../src/economic/FeeEngine.sol";
import { IFluxToken } from "../../src/interfaces/IFlux.sol";

contract FluxAMMTest is Test {
    address internal admin = makeAddr("admin");
    address internal trader = makeAddr("trader");
    address internal treasury = makeAddr("treasury");

    FluxToken internal flux;
    FluxAMMFactory internal factory;
    FluxSwapRouter internal router;
    MockUniswapV2Migrator internal migrator;
    FeeEngine internal feeEngine;
    LiquidityVault internal liquidityVault;

    uint16 internal constant PROTOCOL_FEE_BPS = 100; // 1%

    function setUp() public {
        vm.startPrank(admin);
        flux = new FluxToken(admin);
        flux.grantRole(flux.MINTER_ROLE(), admin);
        factory = new FluxAMMFactory();
        migrator = new MockUniswapV2Migrator(factory);

        liquidityVault = new LiquidityVault(admin);
        BalanceVault balanceVault = new BalanceVault(admin);
        ProtocolVault protocolVault = new ProtocolVault(admin, treasury);
        RewardVault rewardVault = new RewardVault(admin);
        RewardAssetRegistry rewardAssets = new RewardAssetRegistry(admin);
        rewardAssets.registerAsset(address(0), RewardAssetRegistry.AssetType.Native, address(0));
        GenesisVault genesisVault = new GenesisVault(admin, rewardVault, rewardAssets);
        RewardStrategyManager rewardStrategy =
            new RewardStrategyManager(admin, rewardVault, genesisVault);
        feeEngine = new FeeEngine(admin, liquidityVault, rewardStrategy, balanceVault, protocolVault);
        rewardStrategy.grantRole(rewardStrategy.EXECUTOR_ROLE(), address(feeEngine));
        router = new FluxSwapRouter(factory, address(feeEngine), PROTOCOL_FEE_BPS);

        vm.stopPrank();
        vm.deal(trader, 100 ether);
    }

    function testBootstrapAndSwapBothWays() public {
        uint256 tokenAmt = 1_000_000 ether;
        uint256 ethAmt = 10 ether;
        vm.deal(admin, 100 ether);
        vm.startPrank(admin);
        flux.mint(admin, tokenAmt);
        flux.approve(address(migrator), tokenAmt);
        bytes32 pos = migrator.bootstrapPool{ value: ethAmt }(address(flux), tokenAmt, 1, "");
        vm.stopPrank();

        address pairAddr = address(uint160(uint256(pos)));
        assertEq(factory.getPair(address(flux)), pairAddr);

        FluxNativePair pair = FluxNativePair(payable(pairAddr));
        assertEq(pair.reserveETH(), ethAmt);
        assertEq(pair.reserveToken(), tokenAmt);

        uint256 expectedOut = router.getAmountOutETHForToken(address(flux), 1 ether);
        vm.prank(trader);
        uint256 out = router.swapExactETHForTokens{ value: 1 ether }(expectedOut * 99 / 100, address(flux), trader);
        assertGt(out, 0);
        assertEq(flux.balanceOf(trader), out);

        uint256 expectedEth = router.getAmountOutTokenForETH(address(flux), out);
        vm.startPrank(trader);
        flux.approve(address(router), out);
        uint256 ethBack = router.swapExactTokensForETH(out, expectedEth * 99 / 100, address(flux), trader);
        vm.stopPrank();
        assertGt(ethBack, 0);
        assertLt(ethBack, 1 ether);
    }

    function testProtocolFeeSentToFeeEngineOnEthInSwap() public {
        _bootstrapPool();

        uint256 grossEth = 1 ether;
        uint256 expectedFee = grossEth * PROTOCOL_FEE_BPS / 10_000;
        assertEq(router.protocolFeeAmount(grossEth), expectedFee);

        vm.prank(trader);
        router.swapExactETHForTokens{ value: grossEth }(
            router.getAmountOutETHForToken(address(flux), grossEth) * 99 / 100, address(flux), trader
        );

        assertEq(address(feeEngine).balance, expectedFee);
    }

    function testProtocolFeeSentToFeeEngineOnTokenOutSwap() public {
        _bootstrapPool();

        vm.prank(trader);
        uint256 tokens = router.swapExactETHForTokens{ value: 1 ether }(
            router.getAmountOutETHForToken(address(flux), 1 ether) * 99 / 100, address(flux), trader
        );

        uint256 feeBefore = address(feeEngine).balance;
        vm.startPrank(trader);
        flux.approve(address(router), tokens);
        uint256 minEth = router.getAmountOutTokenForETH(address(flux), tokens) * 99 / 100;
        router.swapExactTokensForETH(tokens, minEth, address(flux), trader);
        vm.stopPrank();

        assertGt(address(feeEngine).balance, feeBefore);
    }

    function _bootstrapPool() internal {
        uint256 tokenAmt = 1_000_000 ether;
        uint256 ethAmt = 10 ether;
        vm.deal(admin, 100 ether);
        vm.startPrank(admin);
        flux.mint(admin, tokenAmt);
        flux.approve(address(migrator), tokenAmt);
        migrator.bootstrapPool{ value: ethAmt }(address(flux), tokenAmt, 1, "");
        vm.stopPrank();
    }

    function testGenesisFinalizeRegistersPair() public {
        CreditManager credits = new CreditManager(admin);
        LiquidityVault lv = new LiquidityVault(admin);
        GenesisAuction auction = new GenesisAuction(
            admin, credits, IFluxToken(address(flux)), migrator, lv
        );
        vm.startPrank(admin);
        credits.grantRole(credits.ISSUER_ROLE(), address(auction));
        flux.grantRole(flux.MINTER_ROLE(), address(auction));
        lv.grantRole(lv.GENESIS_REGISTRAR_ROLE(), address(auction));
        vm.stopPrank();

        address bidder = makeAddr("bidder");
        vm.deal(bidder, 50_000 ether);
        vm.prank(admin);
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 2 days));
        vm.prank(bidder);
        auction.bid{ value: 10_000 ether }(2 ether);
        vm.warp(block.timestamp + 2 days);
        vm.prank(admin);
        auction.finalize();

        assertTrue(lv.genesisPositionRegistered());
        address pair = lv.genesisPosition();
        assertEq(factory.getPair(address(flux)), pair);
        assertGt(FluxNativePair(payable(pair)).reserveETH(), 0);
    }
}
