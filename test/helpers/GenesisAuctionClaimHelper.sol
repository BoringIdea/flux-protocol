// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { GenesisAuction } from "../../src/genesis/GenesisAuction.sol";

abstract contract GenesisAuctionClaimHelper is Test {
    function claimAllCredits(GenesisAuction auction, address user) internal {
        vm.startPrank(user);
        for (;;) {
            (,,,,,, bool claimed) = auction.bids(user);
            if (claimed) break;
            auction.claimCreditBatch(auction.DEFAULT_CLAIM_BATCH());
        }
        vm.stopPrank();
    }
}
