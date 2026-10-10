// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract ProtocolVault is AccessControl {
    address public recipient;

    error PaymentFailed();

    event RecipientUpdated(address indexed recipient);
    event Withdrawn(address indexed recipient, uint256 amount);

    constructor(address admin, address recipient_) {
        recipient = recipient_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    receive() external payable { }

    function setRecipient(address recipient_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        recipient = recipient_;
        emit RecipientUpdated(recipient_);
    }

    function withdraw(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool ok,) = recipient.call{ value: amount }("");
        if (!ok) revert PaymentFailed();
        emit Withdrawn(recipient, amount);
    }
}
