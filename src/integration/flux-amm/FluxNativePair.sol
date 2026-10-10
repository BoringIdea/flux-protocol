// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Minimal constant-product pool (native ETH + one ERC20) for hackathon / testnet demos.
contract FluxNativePair {
    using SafeERC20 for IERC20;

    uint256 private constant FEE_BPS = 997; // 0.3% fee like Uniswap V2
    uint256 private constant BPS = 1000;

    address public immutable token;
    address public immutable factory;

    uint256 public reserveETH;
    uint256 public reserveToken;

    error InsufficientLiquidity();
    error InsufficientOutput();
    error EthTransferFailed();

    event LiquidityAdded(uint256 ethAmount, uint256 tokenAmount, uint256 reserveETH, uint256 reserveToken);
    event Swap(address indexed sender, uint256 ethIn, uint256 ethOut, uint256 tokenIn, uint256 tokenOut);

    constructor(address token_, address factory_) {
        token = token_;
        factory = factory_;
    }

    function addLiquidity(uint256 tokenAmount) external payable {
        if (msg.value == 0 || tokenAmount == 0) revert InsufficientLiquidity();
        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        reserveETH += msg.value;
        reserveToken += tokenAmount;
        emit LiquidityAdded(msg.value, tokenAmount, reserveETH, reserveToken);
    }

    function swapExactETHForTokens(uint256 minTokenOut, address to) external payable returns (uint256 tokenOut) {
        if (msg.value == 0) revert InsufficientLiquidity();
        uint256 ethIn = msg.value;
        uint256 ethInWithFee = ethIn * FEE_BPS / BPS;
        tokenOut = (ethInWithFee * reserveToken) / (reserveETH + ethInWithFee);
        if (tokenOut < minTokenOut || tokenOut == 0) revert InsufficientOutput();
        reserveETH += ethIn;
        reserveToken -= tokenOut;
        IERC20(token).safeTransfer(to, tokenOut);
        emit Swap(msg.sender, ethIn, 0, 0, tokenOut);
    }

    function swapExactTokensForETH(uint256 amountIn, uint256 minEthOut, address to)
        external
        returns (uint256 ethOut)
    {
        if (amountIn == 0) revert InsufficientLiquidity();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 inWithFee = amountIn * FEE_BPS / BPS;
        ethOut = (inWithFee * reserveETH) / (reserveToken + inWithFee);
        if (ethOut < minEthOut || ethOut == 0) revert InsufficientOutput();
        reserveToken += amountIn;
        reserveETH -= ethOut;
        (bool ok,) = to.call{ value: ethOut }("");
        if (!ok) revert EthTransferFailed();
        emit Swap(msg.sender, 0, ethOut, amountIn, 0);
    }

    receive() external payable { }
}
