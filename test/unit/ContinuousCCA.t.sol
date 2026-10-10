// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { GenesisAuction } from "../../src/genesis/GenesisAuction.sol";
import { CreditManager } from "../../src/core/CreditManager.sol";
import { FluxToken } from "../../src/token/FluxToken.sol";
import { IFluxToken } from "../../src/interfaces/IFlux.sol";
import { MockUniswapV4Migrator } from "../../src/integration/MockUniswapV4Migrator.sol";
import { LiquidityVault } from "../../src/vault/LiquidityVault.sol";
import { GenesisAuctionClaimHelper } from "../helpers/GenesisAuctionClaimHelper.sol";

/// @notice Scheme C: MPS continuous release allocates credits before finalize.
contract ContinuousCCATest is GenesisAuctionClaimHelper {
    GenesisAuction internal auction;
    CreditManager internal credits;
    FluxToken internal flux;
    LiquidityVault internal liquidityVault;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        credits = new CreditManager(address(this));
        flux = new FluxToken(address(this));
        liquidityVault = new LiquidityVault(address(this));
        auction = new GenesisAuction(
            address(this), credits, IFluxToken(address(flux)), new MockUniswapV4Migrator(), liquidityVault
        );
        credits.grantRole(credits.ISSUER_ROLE(), address(auction));
        flux.grantRole(flux.MINTER_ROLE(), address(auction));
        liquidityVault.grantRole(liquidityVault.GENESIS_REGISTRAR_ROLE(), address(auction));
        vm.deal(alice, 20_000 ether);
        vm.deal(bob, 20_000 ether);
    }

    function testCreditsReleaseOverTimeBeforeFinalize() public {
        uint64 start = uint64(block.timestamp);
        uint64 end = uint64(block.timestamp + 2 days);
        auction.createAuction(start, end);

        vm.warp(start);
        vm.prank(alice);
        auction.bid{ value: 10_000 ether }(2 ether);
        assertEq(auction.totalCreditsAllocated(), 0);

        vm.warp(start + 1 days);
        auction.checkpoint();
        assertGt(auction.totalCreditsAllocated(), 0);
        assertLt(auction.totalCreditsAllocated(), 5_000);

        vm.warp(end);
        auction.finalize();
        assertEq(auction.totalCreditsAllocated(), 5_000);
    }

    function testMidAuctionBidJoinsRemainingRelease() public {
        uint64 start = uint64(block.timestamp);
        uint64 end = uint64(block.timestamp + 2 days);
        auction.createAuction(start, end);

        vm.warp(start);
        vm.prank(alice);
        auction.bid{ value: 10_000 ether }(2 ether);

        vm.warp(start + 1 days);
        vm.prank(bob);
        auction.bid{ value: 10_000 ether }(2 ether);

        vm.warp(end);
        auction.finalize();

        claimAllCredits(auction, alice);
        claimAllCredits(auction, bob);
        uint256 aliceCredits = credits.balanceOf(alice);
        uint256 bobCredits = credits.balanceOf(bob);
        assertEq(aliceCredits + bobCredits, 5_000);
        assertGt(aliceCredits, bobCredits);
    }
}
