// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { LiquidityVault } from "../vault/LiquidityVault.sol";
import { BalanceVault } from "../vault/BalanceVault.sol";
import { ProtocolVault } from "../vault/ProtocolVault.sol";
import { RewardStrategyManager } from "./RewardStrategyManager.sol";

contract FeeEngine is AccessControl, ReentrancyGuard {
    struct FeeSplit {
        uint16 liquidityBps;
        uint16 genesisBps;
        uint16 balanceBps;
        uint16 protocolBps;
    }

    LiquidityVault public immutable liquidityVault;
    RewardStrategyManager public immutable rewardStrategy;
    BalanceVault public immutable balanceVault;
    ProtocolVault public immutable protocolVault;
    FeeSplit public feeSplit = FeeSplit(3_000, 2_500, 2_500, 2_000);

    error InvalidFeeSplit();
    error TransferFailed();

    event FeeSplitUpdated(uint16 liquidity, uint16 genesis, uint16 balance, uint16 protocol);
    event FeeDistributed(uint256 liquidity, uint256 genesis, uint256 balance, uint256 protocol);

    constructor(
        address admin,
        LiquidityVault liquidityVault_,
        RewardStrategyManager rewardStrategy_,
        BalanceVault balanceVault_,
        ProtocolVault protocolVault_
    ) {
        liquidityVault = liquidityVault_;
        rewardStrategy = rewardStrategy_;
        balanceVault = balanceVault_;
        protocolVault = protocolVault_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    receive() external payable { }

    function setFeeSplit(FeeSplit calldata split) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (
            uint256(split.liquidityBps) + split.genesisBps + split.balanceBps + split.protocolBps
                != 10_000
        ) {
            revert InvalidFeeSplit();
        }
        feeSplit = split;
        emit FeeSplitUpdated(
            split.liquidityBps, split.genesisBps, split.balanceBps, split.protocolBps
        );
    }

    function distribute() external nonReentrant {
        uint256 amount = address(this).balance;
        uint256 liquidity = amount * feeSplit.liquidityBps / 10_000;
        uint256 genesis = amount * feeSplit.genesisBps / 10_000;
        uint256 balance = amount * feeSplit.balanceBps / 10_000;
        uint256 protocol = amount - liquidity - genesis - balance;
        _send(address(liquidityVault), liquidity);
        rewardStrategy.holdNative{ value: genesis }();
        _send(address(balanceVault), balance);
        _send(address(protocolVault), protocol);
        emit FeeDistributed(liquidity, genesis, balance, protocol);
    }

    function _send(address to, uint256 amount) internal {
        (bool ok,) = to.call{ value: amount }("");
        if (!ok) revert TransferFailed();
    }
}
