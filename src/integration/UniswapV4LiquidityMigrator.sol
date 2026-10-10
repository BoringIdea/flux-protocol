// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ILiquidityMigrator } from "../interfaces/ILiquidityMigrator.sol";

/// @notice Production migrator hook for Uniswap v4 Liquidity Launchpad integration.
/// @dev `externalMigrator` should be an LBPStrategy / launcher contract that accepts
///      FLUX + ETH and performs v4 `migrate()`. Until wired on a target chain, deploy
///      `MockUniswapV4Migrator` for tests and staging.
interface IExternalLiquidityMigrator {
    function migrateGenesisPool(address token, uint256 tokenAmount, bytes calldata poolConfig)
        external
        payable
        returns (bytes32 positionId);
}

contract UniswapV4LiquidityMigrator is ILiquidityMigrator {
    using SafeERC20 for IERC20;

    IExternalLiquidityMigrator public immutable externalMigrator;

    error MigratorNotConfigured();
    error BootstrapFailed();

    event PoolBootstrapped(bytes32 indexed positionId, address token, uint256 tokenAmount, uint256 ethAmount);

    constructor(address externalMigrator_) {
        if (externalMigrator_ == address(0)) revert MigratorNotConfigured();
        externalMigrator = IExternalLiquidityMigrator(externalMigrator_);
    }

    function bootstrapPool(
        address token,
        uint256 tokenAmount,
        uint256 minLiquidity,
        bytes calldata data
    ) external payable returns (bytes32 positionId) {
        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        IERC20(token).forceApprove(address(externalMigrator), tokenAmount);
        positionId = externalMigrator.migrateGenesisPool{ value: msg.value }(token, tokenAmount, data);
        if (positionId == bytes32(0)) revert BootstrapFailed();
        minLiquidity;
        emit PoolBootstrapped(positionId, token, tokenAmount, msg.value);
    }
}
