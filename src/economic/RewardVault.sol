// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract RewardVault is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ACCOUNTANT_ROLE = keccak256("ACCOUNTANT_ROLE");
    mapping(address => uint256) public liability;

    error InsufficientBacking(address asset, uint256 balance, uint256 liability_);
    error PaymentFailed();

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    receive() external payable virtual { }

    function increaseLiability(address asset, uint256 amount) external onlyRole(ACCOUNTANT_ROLE) {
        uint256 next = liability[asset] + amount;
        uint256 balance =
            asset == address(0) ? address(this).balance : IERC20(asset).balanceOf(address(this));
        if (next > balance) revert InsufficientBacking(asset, balance, next);
        liability[asset] = next;
    }

    function pay(address asset, address to, uint256 amount) external onlyRole(ACCOUNTANT_ROLE) {
        liability[asset] -= amount;
        if (asset == address(0)) {
            (bool ok,) = to.call{ value: amount }("");
            if (!ok) revert PaymentFailed();
        } else {
            IERC20(asset).safeTransfer(to, amount);
        }
    }

    function available(address asset) external view returns (uint256) {
        uint256 balance =
            asset == address(0) ? address(this).balance : IERC20(asset).balanceOf(address(this));
        return balance - liability[asset];
    }
}
