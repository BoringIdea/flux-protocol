// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IRandomProvider } from "../interfaces/IFlux.sol";

/// @notice Chainlink-style asynchronous VRF adapter with explicit fulfillment.
contract ChainlinkVRFRandomProvider is IRandomProvider {
    address public coordinator;
    mapping(uint256 => uint256) private _randomness;
    mapping(uint256 => bool) private _ready;
    mapping(uint256 => uint256) public requestToNonce;

    error NotCoordinator();
    error RandomnessNotReady(uint256 nonce);
    error RequestAlreadyPending(uint256 nonce);

    event CoordinatorUpdated(address indexed coordinator);
    event RandomnessRequested(uint256 indexed nonce, uint256 requestId);
    event RandomnessFulfilled(uint256 indexed nonce, uint256 randomness);

    constructor(address coordinator_) {
        coordinator = coordinator_;
    }

    function setCoordinator(address coordinator_) external {
        if (msg.sender != coordinator && coordinator != address(0)) revert NotCoordinator();
        coordinator = coordinator_;
        emit CoordinatorUpdated(coordinator_);
    }

    function requestRandom(uint256 nonce) external returns (uint256 requestId) {
        if (_ready[nonce]) revert RequestAlreadyPending(nonce);
        requestId = uint256(keccak256(abi.encode(nonce, block.chainid, address(this), block.number)));
        requestToNonce[requestId] = nonce;
        emit RandomnessRequested(nonce, requestId);
    }

    function fulfillRandom(uint256 requestId, uint256 randomness) external {
        if (msg.sender != coordinator) revert NotCoordinator();
        uint256 nonce = requestToNonce[requestId];
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
