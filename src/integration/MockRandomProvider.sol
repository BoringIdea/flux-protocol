// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IRandomProvider } from "../interfaces/IFlux.sol";

/// @notice Deterministic random provider for local tests and devnets.
contract MockRandomProvider is IRandomProvider {
    uint256 public salt;

    function setSalt(uint256 salt_) external {
        salt = salt_;
    }

    function random(uint256 nonce) external view returns (uint256) {
        return uint256(keccak256(abi.encode(nonce, salt, address(this))));
    }

    function isReady(uint256) external pure returns (bool) {
        return true;
    }

    function requestRandom(uint256 nonce) external view returns (uint256 requestId) {
        return uint256(keccak256(abi.encode(nonce, address(this), "request")));
    }
}
