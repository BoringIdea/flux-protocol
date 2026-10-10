// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";
import { ConversionEngine } from "../src/core/ConversionEngine.sol";
import { GenesisVault } from "../src/economic/GenesisVault.sol";
import { FeeEngine } from "../src/economic/FeeEngine.sol";

contract MaterializeGenesisNFT is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        ConversionEngine engine = ConversionEngine(payable(vm.envAddress("CONVERSION_ENGINE")));
        vm.broadcast(key);
        engine.materializeGenesisNFT(vm.envUint("ASSET_ID"), vm.envUint("TRAIT_SEED"));
    }
}

contract MaterializeFT is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        ConversionEngine engine = ConversionEngine(payable(vm.envAddress("CONVERSION_ENGINE")));
        vm.broadcast(key);
        engine.materializeFT(vm.envUint("ASSET_ID"));
    }
}

contract ConvertNFTToFT is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        ConversionEngine engine = ConversionEngine(payable(vm.envAddress("CONVERSION_ENGINE")));
        uint256 fee = engine.preview(false).fee;
        vm.broadcast(key);
        engine.nftToFT{ value: fee }(vm.envUint("TOKEN_ID"));
    }
}

contract ConvertFTToNFT is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        ConversionEngine engine = ConversionEngine(payable(vm.envAddress("CONVERSION_ENGINE")));
        uint256 fee = engine.preview(true).fee;
        vm.broadcast(key);
        engine.ftToNFT{ value: fee }(vm.envUint("TRAIT_SEED"));
    }
}

contract ClaimGenesisRewards is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        GenesisVault vault = GenesisVault(vm.envAddress("GENESIS_VAULT"));
        vm.broadcast(key);
        vault.claimAllRegistered(vm.envUint("TOKEN_ID"));
    }
}

contract DistributeFees is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        FeeEngine engine = FeeEngine(payable(vm.envAddress("FEE_ENGINE")));
        vm.broadcast(key);
        engine.distribute();
    }
}
