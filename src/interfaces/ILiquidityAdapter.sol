// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ILiquidityAdapter {
    function initializePool(
        address token,
        uint256 tokenAmount,
        uint256 minLiquidity,
        bytes calldata data
    ) external payable returns (uint256 positionId);

    function compound(uint256 positionId, uint256 minLiquidity, bytes calldata data)
        external
        payable
        returns (uint256 liquidityAdded);
}
