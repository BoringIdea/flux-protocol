// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20Uniswap } from "../../src/interfaces/IUniswapV2.sol";

contract MockUniswapV2Pair {
    address public token0;
    address public token1;

    constructor(address t0, address t1) {
        (token0, token1) = t0 < t1 ? (t0, t1) : (t1, t0);
    }
}

contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) internal _pairs;

    function getPair(address tokenA, address tokenB) external view returns (address) {
        return _pairs[tokenA][tokenB];
    }

    function setPair(address tokenA, address tokenB, address pair) external {
        _pairs[tokenA][tokenB] = pair;
        _pairs[tokenB][tokenA] = pair;
    }
}

contract MockUniswapV2Router {
    address public immutable factory;
    address public immutable WETH;
    uint256 public lastLiquidity;
    address public lastRecipient;
    uint256 public minLiquidityRevertAbove;

    constructor(address factory_, address weth_) {
        factory = factory_;
        WETH = weth_;
    }

    function setMinLiquidityRevertAbove(uint256 threshold) external {
        minLiquidityRevertAbove = threshold;
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256,
        uint256,
        address to,
        uint256
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = amountToken + amountETH;
        if (liquidity < minLiquidityRevertAbove) {
            revert("MIN_LIQ");
        }
        if (amountTokenDesired != 0) {
            IERC20Uniswap(token).transferFrom(msg.sender, address(this), amountTokenDesired);
        }
        lastLiquidity = liquidity;
        lastRecipient = to;
        return (amountToken, amountETH, liquidity);
    }
}

contract FailingReceiver {
    receive() external payable {
        revert();
    }
}
