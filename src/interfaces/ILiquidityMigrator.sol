// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice Post-auction liquidity bootstrap (Scheme C: Uniswap v4 / Liquidity Launchpad migrator).
interface ILiquidityMigrator {
    /// @param data Migrator-specific pool config (v4 PoolKey, hook, tick spacing, etc.).
    function bootstrapPool(
        address token,
        uint256 tokenAmount,
        uint256 minLiquidity,
        bytes calldata data
    ) external payable returns (bytes32 positionId);
}
