// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IRewardStrategy } from "../interfaces/IFlux.sol";

contract HoldETHStrategy is IRewardStrategy {
    error InvalidAmount();
    error TransferFailed();

    function inputAsset() external pure returns (address) {
        return address(0);
    }

    function outputAsset() external pure returns (address) {
        return address(0);
    }

    function execute(uint256 amountIn, uint256 minAmountOut, bytes calldata)
        external
        payable
        returns (uint256 amountOut)
    {
        if (msg.value != amountIn || amountIn < minAmountOut) revert InvalidAmount();
        amountOut = amountIn;
        (bool ok,) = msg.sender.call{ value: amountOut }("");
        if (!ok) revert TransferFailed();
    }
}
