// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { TestBase } from "../TestBase.sol";
import { GenesisAuction } from "../../src/genesis/GenesisAuction.sol";
import { CreditManager } from "../../src/core/CreditManager.sol";
import { FluxToken } from "../../src/token/FluxToken.sol";
import { IFluxToken } from "../../src/interfaces/IFlux.sol";
import { MockUniswapV4Migrator } from "../../src/integration/MockUniswapV4Migrator.sol";
import { LiquidityVault } from "../../src/vault/LiquidityVault.sol";
import { CCAAllocator } from "../../src/genesis/CCAAllocator.sol";
import { GenesisAuctionClaimHelper } from "../helpers/GenesisAuctionClaimHelper.sol";

contract GenesisAuctionTest is GenesisAuctionClaimHelper {
    GenesisAuction internal auction;
    CreditManager internal credits;
    FluxToken internal flux;
    LiquidityVault internal liquidityVault;
    MockUniswapV4Migrator internal liquidityMigrator;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public {
        credits = new CreditManager(address(this));
        flux = new FluxToken(address(this));
        liquidityVault = new LiquidityVault(address(this));
        liquidityMigrator = new MockUniswapV4Migrator();
        auction = new GenesisAuction(
            address(this), credits, IFluxToken(address(flux)), liquidityMigrator, liquidityVault
        );
        credits.grantRole(credits.ISSUER_ROLE(), address(auction));
        flux.grantRole(flux.MINTER_ROLE(), address(auction));
        liquidityVault.grantRole(liquidityVault.GENESIS_REGISTRAR_ROLE(), address(auction));
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
    }

    function testAuctionBidFinalizeClaimAndLiquidity() public {
        auction.createAuction(uint64(block.timestamp + 1), uint64(block.timestamp + 1 days));
        vm.warp(block.timestamp + 1);
        vm.deal(alice, 10_000 ether);
        vm.prank(alice);
        auction.bid{ value: 10_000 ether }(2 ether);
        vm.warp(block.timestamp + 1 days);
        assertEq(auction.clearingPricePreview(), 2 ether);
        auction.finalize();
        assertEq(auction.clearingPrice(), 2 ether);
        assertTrue(liquidityVault.genesisPositionRegistered());
        assertNotEq(auction.genesisPositionId(), bytes32(0));
        claimAllCredits(auction, alice);
        assertEq(credits.balanceOf(alice), 5_000);
        assertEq(alice.balance, 0);
    }

    function testProRataAllocationIsOrderIndependent() public {
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 1 days));
        vm.prank(alice);
        auction.bid{ value: 50 ether }(0.01 ether);
        vm.prank(bob);
        auction.bid{ value: 50 ether }(0.01 ether);
        vm.warp(block.timestamp + 1 days);
        auction.finalize();

        claimAllCredits(auction, bob);
        claimAllCredits(auction, alice);
        assertEq(credits.balanceOf(alice) + credits.balanceOf(bob), 5_000);
        assertEq(credits.balanceOf(alice), 2_500);
        assertEq(credits.balanceOf(bob), 2_500);
    }

    function testCancelAndLosingBidRefund() public {
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 1 days));
        vm.prank(alice);
        auction.bid{ value: 2 ether }(1 ether);
        vm.prank(alice);
        auction.cancelBid();
        assertEq(alice.balance, 100 ether);

        vm.prank(bob);
        auction.bid{ value: 3 ether }(0.5 ether);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(CCAAllocator.NoEligibleBids.selector);
        auction.finalize();
    }

    function testBidUpdateAndValidation() public {
        vm.expectRevert();
        auction.createAuction(uint64(block.timestamp - 1), uint64(block.timestamp));
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 1 days));
        vm.expectRevert();
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 1 days));
        vm.prank(alice);
        vm.expectRevert();
        auction.bid{ value: 0 }(1 ether);
        vm.prank(alice);
        auction.bid{ value: 1 ether }(1 ether);
        vm.prank(alice);
        auction.bid{ value: 1 ether }(2 ether);
        (uint128 budget,,,,,,) = auction.bids(alice);
        assertEq(budget, 2 ether);
        vm.expectRevert();
        auction.finalize();
    }

    function testCCAAllocatorLibrary() public pure {
        CCAAllocator.BidInput[] memory bids = new CCAAllocator.BidInput[](2);
        bids[0] = CCAAllocator.BidInput(10 ether, 2 ether);
        bids[1] = CCAAllocator.BidInput(10 ether, 2 ether);
        uint256 clearing = CCAAllocator.computeClearingPrice(bids, 5);
        assertEq(clearing, 2 ether);
        CCAAllocator.BidOutput[] memory outputs = CCAAllocator.allocate(bids, 5, clearing);
        assertEq(outputs[0].credits + outputs[1].credits, 5);
        assertEq(outputs[0].credits, 3);
        assertEq(outputs[1].credits, 2);
    }
}
