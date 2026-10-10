// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { CCAAllocator } from "../../src/genesis/CCAAllocator.sol";

contract CCAAllocatorHarness {
    function computeClearingPrice(CCAAllocator.BidInput[] memory bids, uint256 creditSupply)
        external
        pure
        returns (uint256)
    {
        return CCAAllocator.computeClearingPrice(bids, creditSupply);
    }

    function allocate(CCAAllocator.BidInput[] memory bids, uint256 creditSupply, uint256 clearingPrice)
        external
        pure
        returns (CCAAllocator.BidOutput[] memory)
    {
        return CCAAllocator.allocate(bids, creditSupply, clearingPrice);
    }
}

contract CCAAllocatorTest is Test {
    CCAAllocatorHarness internal harness = new CCAAllocatorHarness();

    function testComputeClearingPriceAndProRata() public {
        CCAAllocator.BidInput[] memory bids = new CCAAllocator.BidInput[](3);
        bids[0] = CCAAllocator.BidInput(20 ether, 4 ether);
        bids[1] = CCAAllocator.BidInput(10 ether, 2 ether);
        bids[2] = CCAAllocator.BidInput(5 ether, 1 ether);

        uint256 clearing = harness.computeClearingPrice(bids, 10);
        assertEq(clearing, 2 ether);

        CCAAllocator.BidOutput[] memory outputs = harness.allocate(bids, 10, clearing);
        uint256 total;
        for (uint256 i; i < outputs.length; ++i) {
            total += outputs[i].credits;
        }
        assertEq(total, 10);
        assertEq(outputs[2].credits, 0);
        assertEq(outputs[2].refund, 5 ether);
    }

    function testNoEligibleBidsAndInvalidClearingPrice() public {
        CCAAllocator.BidInput[] memory empty = new CCAAllocator.BidInput[](0);
        vm.expectRevert(CCAAllocator.NoEligibleBids.selector);
        harness.computeClearingPrice(empty, 10);
        vm.expectRevert(CCAAllocator.InvalidClearingPrice.selector);
        harness.allocate(empty, 10, 0);
    }

    function testUndersubscribedAllocation() public {
        CCAAllocator.BidInput[] memory bids = new CCAAllocator.BidInput[](1);
        bids[0] = CCAAllocator.BidInput(10 ether, 2 ether);
        uint256 clearing = harness.computeClearingPrice(bids, 5);
        CCAAllocator.BidOutput[] memory outputs = harness.allocate(bids, 5, clearing);
        assertEq(outputs[0].credits, 5);
        assertEq(outputs[0].cost, 10 ether);
        assertEq(outputs[0].refund, 0);
    }

    function testInsufficientAggregateDemandReverts() public {
        CCAAllocator.BidInput[] memory bids = new CCAAllocator.BidInput[](1);
        bids[0] = CCAAllocator.BidInput(1 ether, 1 ether);
        vm.expectRevert(CCAAllocator.NoEligibleBids.selector);
        harness.computeClearingPrice(bids, 100);
    }
}
