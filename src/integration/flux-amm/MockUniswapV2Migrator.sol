// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ILiquidityMigrator } from "../../interfaces/ILiquidityMigrator.sol";
import { FluxAMMFactory } from "./FluxAMMFactory.sol";
import { FluxNativePair } from "./FluxNativePair.sol";

/// @notice ILiquidityMigrator that bootstraps a real FluxNativePair (x*y=k) instead of a no-op mock.
/// @dev `positionId` encodes the pair address for `LiquidityVault.registerGenesisPosition`.
contract MockUniswapV2Migrator is ILiquidityMigrator {
    using SafeERC20 for IERC20;

    FluxAMMFactory public immutable factory;

    error PoolInitializationFailed();

    event PoolBootstrapped(
        bytes32 indexed positionId, address indexed pair, address token, uint256 tokenAmount, uint256 ethAmount
    );

    constructor(FluxAMMFactory factory_) {
        factory = factory_;
    }

    function bootstrapPool(
        address token,
        uint256 tokenAmount,
        uint256 minLiquidity,
        bytes calldata
    ) external payable returns (bytes32 positionId) {
        address pairAddr = factory.getPair(token);
        if (pairAddr == address(0)) {
            pairAddr = factory.createPair(token);
        }
        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        IERC20(token).forceApprove(pairAddr, tokenAmount);
        FluxNativePair(payable(pairAddr)).addLiquidity{ value: msg.value }(tokenAmount);

        uint256 liquidity = msg.value + tokenAmount;
        if (liquidity < minLiquidity) revert PoolInitializationFailed();

        positionId = bytes32(uint256(uint160(pairAddr)));
        emit PoolBootstrapped(positionId, pairAddr, token, tokenAmount, msg.value);
    }
}
