// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ILiquidityAdapter } from "../interfaces/ILiquidityAdapter.sol";
import {
    IERC20Uniswap,
    IUniswapV2Factory,
    IUniswapV2Pair,
    IUniswapV2Router02
} from "../interfaces/IUniswapV2.sol";

/// @notice Creates FLUX/WETH liquidity on Uniswap V2 and permanently locks LP tokens.
contract UniswapV2LiquidityAdapter is ILiquidityAdapter {
    IUniswapV2Router02 public immutable router;
    address public immutable lpLock;

    error InvalidRouter();
    error PoolInitializationFailed();

    event LiquidityLocked(address indexed pair, address indexed lock, uint256 liquidity);

    constructor(address router_, address lpLock_) {
        if (router_ == address(0) || lpLock_ == address(0)) revert InvalidRouter();
        router = IUniswapV2Router02(router_);
        lpLock = lpLock_;
    }

    function initializePool(
        address token,
        uint256 tokenAmount,
        uint256 minLiquidity,
        bytes calldata
    ) external payable returns (uint256 positionId) {
        IERC20Uniswap(token).transferFrom(msg.sender, address(this), tokenAmount);
        IERC20Uniswap(token).approve(address(router), tokenAmount);

        (, , uint256 liquidity) = router.addLiquidityETH{ value: msg.value }(
            token, tokenAmount, tokenAmount, msg.value, lpLock, block.timestamp + 1 hours
        );
        if (liquidity < minLiquidity) revert PoolInitializationFailed();

        positionId = uint256(uint160(_pairFor(token)));
        emit LiquidityLocked(_pairFor(token), lpLock, liquidity);
    }

    function compound(uint256 positionId, uint256 minLiquidity, bytes calldata data)
        external
        payable
        returns (uint256 liquidityAdded)
    {
        address pair = address(uint160(positionId));
        if (pair == address(0)) revert PoolInitializationFailed();

        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        address token = pairContract.token0() == router.WETH()
            ? pairContract.token1()
            : pairContract.token0();
        uint256 tokenAmount = data.length == 0 ? 0 : abi.decode(data, (uint256));

        if (tokenAmount != 0) {
            IERC20Uniswap(token).transferFrom(msg.sender, address(this), tokenAmount);
            IERC20Uniswap(token).approve(address(router), tokenAmount);
        }

        (, , liquidityAdded) = router.addLiquidityETH{ value: msg.value }(
            token, tokenAmount, 0, 0, lpLock, block.timestamp + 1 hours
        );
        if (liquidityAdded < minLiquidity) revert PoolInitializationFailed();
    }

    function _pairFor(address token) internal view returns (address pair) {
        pair = IUniswapV2Factory(router.factory()).getPair(token, router.WETH());
    }
}
