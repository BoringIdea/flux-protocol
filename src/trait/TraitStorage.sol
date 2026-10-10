// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract TraitStorage is AccessControl {
    bytes32 public constant GENERATOR_ROLE = keccak256("GENERATOR_ROLE");

    struct TraitData {
        uint16 background;
        uint16 backgroundStyle;
        uint16 body;
        uint16 skin;
        uint16 eyes;
        uint16 mouth;
        uint16 head;
        uint16 accessory;
    }

    mapping(uint256 => TraitData) private _traits;
    mapping(uint256 => bool) public assigned;

    error TraitAlreadyAssigned(uint256 assetId);
    error TraitNotAssigned(uint256 assetId);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function set(uint256 assetId, TraitData calldata data) external onlyRole(GENERATOR_ROLE) {
        if (assigned[assetId]) revert TraitAlreadyAssigned(assetId);
        assigned[assetId] = true;
        _traits[assetId] = data;
    }

    function release(uint256 assetId) external onlyRole(GENERATOR_ROLE) {
        if (!assigned[assetId]) revert TraitNotAssigned(assetId);
        delete assigned[assetId];
        delete _traits[assetId];
    }

    function traits(uint256 assetId) external view returns (TraitData memory) {
        if (!assigned[assetId]) revert TraitNotAssigned(assetId);
        return _traits[assetId];
    }
}
