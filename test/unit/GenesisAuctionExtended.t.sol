// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { GenesisAuction } from "../../src/genesis/GenesisAuction.sol";
import { CreditManager } from "../../src/core/CreditManager.sol";
import { FluxToken } from "../../src/token/FluxToken.sol";
import { IFluxToken } from "../../src/interfaces/IFlux.sol";
import { MockUniswapV4Migrator } from "../../src/integration/MockUniswapV4Migrator.sol";
import { LiquidityVault } from "../../src/vault/LiquidityVault.sol";
import { ILiquidityMigrator } from "../../src/interfaces/ILiquidityMigrator.sol";
import { CCAAllocator } from "../../src/genesis/CCAAllocator.sol";
import { FailingReceiver } from "../mocks/MockUniswap.sol";
import { GenesisAuctionClaimHelper } from "../helpers/GenesisAuctionClaimHelper.sol";

contract FailingLiquidityMigrator {
    function bootstrapPool(address, uint256, uint256, bytes calldata)
        external
        payable
        returns (bytes32)
    {
        return bytes32(0);
    }
}

contract GenesisAuctionExtendedTest is GenesisAuctionClaimHelper {
    GenesisAuction internal auction;
    CreditManager internal credits;
    FluxToken internal flux;
    LiquidityVault internal liquidityVault;
    MockUniswapV4Migrator internal liquidityMigrator;
    address internal alice = makeAddr("alice");

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
        vm.deal(alice, 20_000 ether);
    }

    function testBidderEnumerationAndEmptyPreview() public {
        assertEq(auction.clearingPricePreview(), 0);
        assertEq(auction.bidderCount(), 0);
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 1 days));
        vm.prank(alice);
        auction.bid{ value: 10_000 ether }(2 ether);
        assertEq(auction.bidderCount(), 1);
        assertEq(auction.bidderAt(0), alice);
    }

    function testClaimValidationAndDoubleClaim() public {
        _finalizeSingleBidder();
        claimAllCredits(auction, alice);
        vm.prank(alice);
        vm.expectRevert(GenesisAuction.NothingToClaim.selector);
        auction.claimCredit();
    }

    function testClaimCreditBatchAcrossFullAllocation() public {
        _finalizeSingleBidder();
        (,, uint256 allocated,,, uint256 creditsClaimed, bool claimed) = auction.bids(alice);
        assertEq(allocated, 5_000);
        assertEq(creditsClaimed, 0);
        assertFalse(claimed);

        vm.startPrank(alice);
        uint256 totalIssued;
        while (!claimed) {
            uint256 batch = auction.claimCreditBatch(200);
            totalIssued += batch;
            (,,,,, creditsClaimed, claimed) = auction.bids(alice);
        }
        vm.stopPrank();

        assertEq(totalIssued, 5_000);
        assertEq(credits.balanceOf(alice), 5_000);
    }

    function testClaimCreditBatchZeroReverts() public {
        _finalizeSingleBidder();
        vm.prank(alice);
        vm.expectRevert(GenesisAuction.InvalidBatchSize.selector);
        auction.claimCreditBatch(0);
    }

    function testFinalizeValidationStates() public {
        vm.expectRevert(GenesisAuction.InvalidState.selector);
        auction.finalize();
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 1 days));
        vm.expectRevert(GenesisAuction.InvalidState.selector);
        auction.finalize();
    }

    function testBidOutsideWindowAndLowerMaxPrice() public {
        auction.createAuction(uint64(block.timestamp + 100), uint64(block.timestamp + 1 days));
        vm.prank(alice);
        vm.expectRevert(GenesisAuction.InvalidState.selector);
        auction.bid{ value: 1 ether }(1 ether);
        vm.warp(block.timestamp + 100);
        vm.prank(alice);
        auction.bid{ value: 1 ether }(2 ether);
        vm.prank(alice);
        vm.expectRevert(GenesisAuction.InvalidBid.selector);
        auction.bid{ value: 1 ether }(1 ether);
    }

    function testLiquidityBootstrapFailure() public {
        FailingLiquidityMigrator failing = new FailingLiquidityMigrator();
        GenesisAuction broken = new GenesisAuction(
            address(this), credits, IFluxToken(address(flux)), ILiquidityMigrator(address(failing)), liquidityVault
        );
        flux.grantRole(flux.MINTER_ROLE(), address(broken));
        broken.grantRole(broken.DEFAULT_ADMIN_ROLE(), address(this));
        liquidityVault.grantRole(liquidityVault.GENESIS_REGISTRAR_ROLE(), address(broken));
        broken.createAuction(uint64(block.timestamp), uint64(block.timestamp + 1 days));
        vm.prank(alice);
        broken.bid{ value: 10_000 ether }(2 ether);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(GenesisAuction.LiquidityBootstrapFailed.selector);
        broken.finalize();
    }

    function testClaimRefundTransferFailure() public {
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 1 days));
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        auction.bid{ value: 50 ether }(0.01 ether);
        FailingBidder failing = new FailingBidder(auction);
        vm.deal(address(failing), 50 ether);
        failing.bid{ value: 50 ether }();
        vm.warp(block.timestamp + 1 days);
        auction.finalize();
        vm.expectRevert(GenesisAuction.TransferFailed.selector);
        failing.claim();
    }

    function testLosingBidGetsFullRefundOnClaim() public {
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 1 days));
        vm.prank(alice);
        auction.bid{ value: 10_000 ether }(2 ether);
        address loser = makeAddr("loser");
        vm.deal(loser, 1 ether);
        vm.prank(loser);
        auction.bid{ value: 1 ether }(0.5 ether);
        vm.warp(block.timestamp + 1 days);
        auction.finalize();
        uint256 before = loser.balance;
        vm.prank(loser);
        assertEq(auction.claimCredit(), 0);
        assertEq(loser.balance, before + 1 ether);
    }

    function _finalizeSingleBidder() internal {
        auction.createAuction(uint64(block.timestamp), uint64(block.timestamp + 1 days));
        vm.prank(alice);
        auction.bid{ value: 10_000 ether }(2 ether);
        vm.warp(block.timestamp + 1 days);
        auction.finalize();
    }
}

contract LiquidityVaultTest is Test {
    function testDoubleGenesisRegistrationReverts() public {
        LiquidityVault vault = new LiquidityVault(address(this));
        vault.grantRole(vault.GENESIS_REGISTRAR_ROLE(), address(this));
        vault.registerGenesisPosition(makeAddr("pos"));
        vm.expectRevert();
        vault.registerGenesisPosition(makeAddr("pos2"));
    }
}

contract FailingBidder {
    GenesisAuction public immutable auction;

    constructor(GenesisAuction auction_) {
        auction = auction_;
    }

    function bid() external payable {
        auction.bid{ value: msg.value }(0.01 ether);
    }

    function claim() external {
        for (;;) {
            (,,,,,, bool claimed) = auction.bids(address(this));
            if (claimed) break;
            auction.claimCreditBatch(auction.DEFAULT_CLAIM_BATCH());
        }
    }

    receive() external payable {
        revert();
    }
}
