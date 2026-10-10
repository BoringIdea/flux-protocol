// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";
import { FluxSwapRouter } from "../src/integration/flux-amm/FluxSwapRouter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Demo swaps on Flux hackathon AMM (deploy with default migrator — see deployments/*.json).
contract SwapETHForFlux is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        FluxSwapRouter router = FluxSwapRouter(payable(vm.envAddress("FLUX_SWAP_ROUTER")));
        address flux = vm.envAddress("FluxToken");
        uint256 minOut = vm.envOr("MIN_TOKEN_OUT", uint256(0));
        uint256 ethIn = vm.envOr("SWAP_ETH_IN", uint256(0.01 ether));
        vm.broadcast(key);
        router.swapExactETHForTokens{ value: ethIn }(minOut, flux, vm.addr(key));
    }
}

contract SwapFluxForETH is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        FluxSwapRouter router = FluxSwapRouter(payable(vm.envAddress("FLUX_SWAP_ROUTER")));
        address flux = vm.envAddress("FluxToken");
        uint256 amountIn = vm.envUint("SWAP_TOKEN_IN");
        uint256 minEth = vm.envOr("MIN_ETH_OUT", uint256(0));
        vm.startBroadcast(key);
        IERC20(flux).approve(address(router), amountIn);
        router.swapExactTokensForETH(amountIn, minEth, flux, vm.addr(key));
        vm.stopBroadcast();
    }
}
