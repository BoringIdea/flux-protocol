// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract LiquidityVault is AccessControl {
    bytes32 public constant LP_MANAGER_ROLE = keccak256("LP_MANAGER_ROLE");
    bytes32 public constant GENESIS_REGISTRAR_ROLE = keccak256("GENESIS_REGISTRAR_ROLE");

    address public genesisPosition;
    bool public genesisPositionRegistered;

    error CoreLiquidityLocked();
    error PaymentFailed();
    error GenesisPositionAlreadyRegistered();

    event LiquidityCompounded(address indexed target, uint256 amount, bytes data);
    event GenesisPositionRegistered(address indexed position);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    receive() external payable { }

    function registerGenesisPosition(address position) external onlyRole(GENESIS_REGISTRAR_ROLE) {
        if (genesisPositionRegistered) revert GenesisPositionAlreadyRegistered();
        genesisPosition = position;
        genesisPositionRegistered = true;
        emit GenesisPositionRegistered(position);
    }

    function compound(address target, uint256 amount, bytes calldata data)
        external
        onlyRole(LP_MANAGER_ROLE)
        returns (bytes memory result)
    {
        if (target == genesisPosition) revert CoreLiquidityLocked();
        (bool ok, bytes memory returned) = target.call{ value: amount }(data);
        if (!ok) revert PaymentFailed();
        emit LiquidityCompounded(target, amount, data);
        return returned;
    }
}
