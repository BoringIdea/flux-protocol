// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IRandomProvider } from "../interfaces/IFlux.sol";

/// @notice Synchronous VRF adapter that fulfills randomness in the same transaction.
///         Useful for tests; production should use ChainlinkVRFRandomProvider.
contract SyncVRFRandomProvider is IRandomProvider {
    mapping(uint256 => uint256) private _randomness;
    mapping(uint256 => bool) private _ready;

    error RandomnessNotReady(uint256 nonce);

    event RandomnessRequested(uint256 indexed nonce, uint256 requestId);
    event RandomnessFulfilled(uint256 indexed nonce, uint256 randomness);

    function requestRandom(uint256 nonce) external returns (uint256 requestId) {
        requestId = uint256(keccak256(abi.encode(nonce, block.prevrandao, block.number, address(this))));
        _randomness[nonce] = requestId;
        _ready[nonce] = true;
        emit RandomnessRequested(nonce, requestId);
        emit RandomnessFulfilled(nonce, requestId);
    }

    function fulfillRandom(uint256 nonce, uint256 randomness) external {
        _randomness[nonce] = randomness;
        _ready[nonce] = true;
        emit RandomnessFulfilled(nonce, randomness);
    }

    function isReady(uint256 nonce) external view returns (bool) {
        return _ready[nonce];
    }

    function random(uint256 nonce) external view returns (uint256) {
        if (!_ready[nonce]) revert RandomnessNotReady(nonce);
        return _randomness[nonce];
    }
}
