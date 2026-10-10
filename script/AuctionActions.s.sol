// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";
import { GenesisAuction } from "../src/genesis/GenesisAuction.sol";

contract BidAuction is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        GenesisAuction auction = GenesisAuction(vm.envAddress("GENESIS_AUCTION"));
        uint128 maxPrice = uint128(vm.envUint("MAX_PRICE"));
        uint256 budget = vm.envUint("BID_BUDGET");
        vm.broadcast(key);
        auction.bid{ value: budget }(maxPrice);
    }
}

contract FinalizeAuction is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        GenesisAuction auction = GenesisAuction(vm.envAddress("GENESIS_AUCTION"));
        vm.broadcast(key);
        auction.finalize();
    }
}

contract ClaimAuctionCredit is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        GenesisAuction auction = GenesisAuction(vm.envAddress("GENESIS_AUCTION"));
        vm.broadcast(key);
        auction.claimCredit();
    }
}

contract ClaimAuctionCreditBatch is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        GenesisAuction auction = GenesisAuction(vm.envAddress("GENESIS_AUCTION"));
        uint256 maxCredits = vm.envOr("CLAIM_BATCH_SIZE", uint256(200));
        vm.broadcast(key);
        auction.claimCreditBatch(maxCredits);
    }
}

contract ClaimAuctionCreditAll is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        GenesisAuction auction = GenesisAuction(vm.envAddress("GENESIS_AUCTION"));
        address bidder = vm.addr(key);
        vm.startBroadcast(key);
        for (;;) {
            (,,,,,, bool claimed) = auction.bids(bidder);
            if (claimed) break;
            auction.claimCreditBatch(200);
        }
        vm.stopBroadcast();
    }
}
