// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";
import { GenesisAuction } from "../src/genesis/GenesisAuction.sol";

contract StartAuction is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        GenesisAuction auction = GenesisAuction(vm.envAddress("GENESIS_AUCTION"));
        uint64 start = uint64(vm.envOr("AUCTION_START", block.timestamp + 2 minutes));
        uint64 duration = uint64(vm.envOr("AUCTION_DURATION", uint256(1 hours)));
        uint64 end = uint64(vm.envOr("AUCTION_END", uint256(start) + duration));
        vm.broadcast(key);
        auction.createAuction(start, end);
    }
}
