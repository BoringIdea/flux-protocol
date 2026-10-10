// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ILiquidityMigrator } from "../interfaces/ILiquidityMigrator.sol";

/// @dev Testnet/local migrator stand-in for Uniswap v4 Liquidity Launchpad `migrate()`.
contract MockUniswapV4Migrator is ILiquidityMigrator {
    uint256 public nextPositionNonce = 1;
    mapping(bytes32 => uint256) public seededLiquidity;

    event PoolBootstrapped(
        bytes32 indexed positionId, address token, uint256 tokenAmount, uint256 ethAmount
    );

    function bootstrapPool(
        address token,
        uint256 tokenAmount,
        uint256 minLiquidity,
        bytes calldata
    ) external payable returns (bytes32 positionId) {
        uint256 minted = tokenAmount < msg.value ? tokenAmount : msg.value;
        require(minted >= minLiquidity);
        positionId = keccak256(abi.encodePacked("flux-v4-pool", nextPositionNonce++, token));
        seededLiquidity[positionId] = minted;
        emit PoolBootstrapped(positionId, token, tokenAmount, msg.value);
    }
}
