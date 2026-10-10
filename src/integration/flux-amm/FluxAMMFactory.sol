// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { FluxNativePair } from "./FluxNativePair.sol";

/// @notice Deploys one native-ETH pair per ERC20 token.
contract FluxAMMFactory {
    mapping(address token => address pair) internal _pair;

    event PairCreated(address indexed token, address indexed pair);

    function getPair(address token) external view returns (address pair) {
        return _pair[token];
    }

    function createPair(address token) external returns (address pair) {
        pair = _pair[token];
        if (pair != address(0)) return pair;
        pair = address(new FluxNativePair(token, address(this)));
        _pair[token] = pair;
        emit PairCreated(token, pair);
    }
}
