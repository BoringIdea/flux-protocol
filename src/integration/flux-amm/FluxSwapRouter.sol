// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FluxAMMFactory } from "./FluxAMMFactory.sol";
import { FluxNativePair } from "./FluxNativePair.sol";

/// @notice User-facing swaps against FluxNativePair pools (Uniswap V2–style UX, native ETH).
/// @dev Takes an optional protocol fee on each swap and forwards it to `feeEngine` (v4 Hook analogue).
contract FluxSwapRouter is AccessControl {
    using SafeERC20 for IERC20;

    uint256 private constant BPS = 10_000;
    uint256 private constant MAX_PROTOCOL_FEE_BPS = 1_000; // 10%

    FluxAMMFactory public immutable factory;
    address public immutable feeEngine;
    uint16 public protocolFeeBps;

    error PairNotFound();
    error FeeEngineNotConfigured();
    error InvalidProtocolFeeBps();
    error ProtocolFeeTransferFailed();

    event ProtocolFeeCollected(address indexed feeEngine, uint256 amount, address indexed payer);
    event SwapETHForTokens(
        address indexed token, address indexed buyer, uint256 grossEthIn, uint256 protocolFee, uint256 tokenOut
    );
    event SwapTokensForETH(
        address indexed token, address indexed seller, uint256 tokenIn, uint256 protocolFee, uint256 netEthOut
    );

    receive() external payable { }

    constructor(FluxAMMFactory factory_, address feeEngine_, uint16 protocolFeeBps_) {
        if (protocolFeeBps_ > MAX_PROTOCOL_FEE_BPS) revert InvalidProtocolFeeBps();
        factory = factory_;
        feeEngine = feeEngine_;
        protocolFeeBps = protocolFeeBps_;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setProtocolFeeBps(uint16 protocolFeeBps_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (protocolFeeBps_ > MAX_PROTOCOL_FEE_BPS) revert InvalidProtocolFeeBps();
        protocolFeeBps = protocolFeeBps_;
    }

    function getPair(address token) public view returns (FluxNativePair pair) {
        address p = factory.getPair(token);
        if (p == address(0)) revert PairNotFound();
        pair = FluxNativePair(payable(p));
    }

    function protocolFeeAmount(uint256 grossAmount) public view returns (uint256) {
        if (feeEngine == address(0) || protocolFeeBps == 0) return 0;
        return grossAmount * protocolFeeBps / BPS;
    }

    function netAfterProtocolFee(uint256 grossAmount) public view returns (uint256) {
        return grossAmount - protocolFeeAmount(grossAmount);
    }

    /// @dev Preview token out for `swapExactETHForTokens` (pool fee + protocol fee on ETH in).
    function getAmountOutETHForToken(address token, uint256 grossEthIn) external view returns (uint256 tokenOut) {
        uint256 netEth = netAfterProtocolFee(grossEthIn);
        FluxNativePair pair = getPair(token);
        uint256 ethInWithFee = netEth * 997 / 1000;
        tokenOut = (ethInWithFee * pair.reserveToken()) / (pair.reserveETH() + ethInWithFee);
    }

    /// @dev Preview net ETH out for `swapExactTokensForETH` (pool fee + protocol fee on ETH out).
    function getAmountOutTokenForETH(address token, uint256 tokenIn)
        external
        view
        returns (uint256 netEthOut)
    {
        FluxNativePair pair = getPair(token);
        uint256 inWithFee = tokenIn * 997 / 1000;
        uint256 grossEth = (inWithFee * pair.reserveETH()) / (pair.reserveToken() + inWithFee);
        netEthOut = netAfterProtocolFee(grossEth);
    }

    function swapExactETHForTokens(uint256 minTokenOut, address token, address to)
        external
        payable
        returns (uint256 tokenOut)
    {
        uint256 fee = _collectProtocolFee(msg.value);
        uint256 netEth = msg.value - fee;
        tokenOut = getPair(token).swapExactETHForTokens{ value: netEth }(minTokenOut, to);
        emit SwapETHForTokens(token, to, msg.value, fee, tokenOut);
    }

    function swapExactTokensForETH(uint256 amountIn, uint256 minEthOut, address token, address to)
        external
        returns (uint256 netEthOut)
    {
        FluxNativePair pair = getPair(token);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(token).forceApprove(address(pair), amountIn);
        // Pair pays gross ETH; protocol fee is taken before forwarding net to `to`.
        uint256 minGrossEthOut = minEthOut * BPS / (BPS - protocolFeeBps);
        if (protocolFeeBps == 0 || feeEngine == address(0)) minGrossEthOut = minEthOut;
        uint256 grossEthOut = pair.swapExactTokensForETH(amountIn, minGrossEthOut, address(this));
        uint256 fee = _collectProtocolFee(grossEthOut);
        netEthOut = grossEthOut - fee;
        _sendEth(to, netEthOut);
        emit SwapTokensForETH(token, to, amountIn, fee, netEthOut);
    }

    function _collectProtocolFee(uint256 grossAmount) internal returns (uint256 fee) {
        fee = protocolFeeAmount(grossAmount);
        if (fee == 0) return 0;
        if (feeEngine == address(0)) revert FeeEngineNotConfigured();
        _sendEth(feeEngine, fee);
        emit ProtocolFeeCollected(feeEngine, fee, msg.sender);
    }

    function _sendEth(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok,) = to.call{ value: amount }("");
        if (!ok) revert ProtocolFeeTransferFailed();
    }
}
