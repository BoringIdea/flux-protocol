// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ILiquidityAdapter } from "../interfaces/ILiquidityAdapter.sol";

contract MockLiquidityAdapter is ILiquidityAdapter {
    uint256 public nextPositionId = 1;
    mapping(uint256 => uint256) public liquidity;

    event PoolInitialized(
        uint256 indexed positionId, address token, uint256 tokenAmount, uint256 ethAmount
    );

    function initializePool(
        address token,
        uint256 tokenAmount,
        uint256 minLiquidity,
        bytes calldata
    ) external payable returns (uint256 positionId) {
        uint256 minted = tokenAmount < msg.value ? tokenAmount : msg.value;
        require(minted >= minLiquidity);
        positionId = nextPositionId++;
        liquidity[positionId] = minted;
        emit PoolInitialized(positionId, token, tokenAmount, msg.value);
    }

    function compound(uint256 positionId, uint256 minLiquidity, bytes calldata)
        external
        payable
        returns (uint256 liquidityAdded)
    {
        liquidityAdded = msg.value;
        require(liquidityAdded >= minLiquidity && positionId != 0);
        liquidity[positionId] += liquidityAdded;
    }
}
