// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IBalanceEngine } from "../interfaces/IFlux.sol";
import { FeeCurve } from "./FeeCurve.sol";

contract BalanceEngine is AccessControl, IBalanceEngine {
    uint16 public lowerBps = 3_000;
    uint16 public upperBps = 4_000;
    uint96 public maxFee = 0.01 ether;
    uint16 public rewardQuoteBps = 100;

    error InvalidRange();

    event ParametersUpdated(uint16 lowerBps, uint16 upperBps, uint96 maxFee, uint16 rewardQuoteBps);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setParameters(uint16 lower, uint16 upper, uint96 fee, uint16 rewardBps)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (lower >= upper || upper >= 10_000 || rewardBps > 10_000) revert InvalidRange();
        lowerBps = lower;
        upperBps = upper;
        maxFee = fee;
        rewardQuoteBps = rewardBps;
        emit ParametersUpdated(lower, upper, fee, rewardBps);
    }

    function quote(uint256 ftUnits, uint256 nftUnits, uint256 vaultBalance, bool ftToNft)
        external
        view
        returns (Quote memory result)
    {
        uint256 total = ftUnits + nftUnits;
        uint256 ratio = total == 0 ? 0 : ftUnits * 10_000 / total;
        result.fee = FeeCurve.directionalFee(ratio, ftToNft, lowerBps, upperBps, maxFee);
        uint256 budget = vaultBalance * rewardQuoteBps / 10_000;
        result.reward = FeeCurve.directionalReward(ratio, ftToNft, lowerBps, upperBps, budget);
    }
}
