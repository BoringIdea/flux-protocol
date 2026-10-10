// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library FeeCurve {
    uint256 internal constant BPS = 10_000;

    function directionalFee(
        uint256 ftRatioBps,
        bool ftToNft,
        uint256 lowerBps,
        uint256 upperBps,
        uint256 maxFee
    ) internal pure returns (uint256) {
        if (ftToNft && ftRatioBps < lowerBps) {
            return maxFee * (lowerBps - ftRatioBps) / lowerBps;
        }
        if (!ftToNft && ftRatioBps > upperBps) {
            return maxFee * (ftRatioBps - upperBps) / (BPS - upperBps);
        }
        return 0;
    }

    function directionalReward(
        uint256 ftRatioBps,
        bool ftToNft,
        uint256 lowerBps,
        uint256 upperBps,
        uint256 budget
    ) internal pure returns (uint256) {
        if (ftToNft && ftRatioBps > upperBps) {
            return budget * (ftRatioBps - upperBps) / (BPS - upperBps);
        }
        if (!ftToNft && ftRatioBps < lowerBps) {
            return budget * (lowerBps - ftRatioBps) / lowerBps;
        }
        return 0;
    }
}
