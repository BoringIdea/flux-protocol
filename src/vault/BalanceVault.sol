// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract BalanceVault is AccessControl {
    bytes32 public constant REWARDER_ROLE = keccak256("REWARDER_ROLE");
    uint16 public dailyReleaseBps = 10;
    uint64 public epochStart;
    uint256 public epochBudget;
    uint256 public epochSpent;

    error EpochBudgetExceeded();
    error PaymentFailed();

    event RewardPaid(address indexed to, uint256 amount);
    event DailyReleaseUpdated(uint16 bps);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        epochStart = uint64(block.timestamp);
    }

    receive() external payable { }

    function setDailyReleaseBps(uint16 bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (bps > 10_000) revert EpochBudgetExceeded();
        dailyReleaseBps = bps;
        emit DailyReleaseUpdated(bps);
    }

    function payReward(address to, uint256 amount) external onlyRole(REWARDER_ROLE) {
        _rollEpoch();
        if (epochSpent + amount > epochBudget) revert EpochBudgetExceeded();
        epochSpent += amount;
        (bool ok,) = to.call{ value: amount }("");
        if (!ok) revert PaymentFailed();
        emit RewardPaid(to, amount);
    }

    function availableReward() external view returns (uint256) {
        if (block.timestamp >= epochStart + 1 days) {
            return address(this).balance * dailyReleaseBps / 10_000;
        }
        return epochBudget - epochSpent;
    }

    function _rollEpoch() internal {
        if (block.timestamp >= epochStart + 1 days || epochBudget == 0) {
            epochStart = uint64(block.timestamp);
            epochBudget = address(this).balance * dailyReleaseBps / 10_000;
            epochSpent = 0;
        }
    }
}
