// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract CreditManager is AccessControl {
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant CONSUMER_ROLE = keccak256("CONSUMER_ROLE");

    mapping(uint256 => address) public creditOwner;
    mapping(address => uint256) public balanceOf;
    uint256 public totalIssued;
    uint256 public totalBurned;

    error CreditAlreadyIssued(uint256 assetId);
    error NotCreditOwner(uint256 assetId);

    event CreditIssued(address indexed to, uint256 indexed assetId);
    event CreditBurned(address indexed owner, uint256 indexed assetId);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function issue(address to, uint256 assetId) external onlyRole(ISSUER_ROLE) {
        if (creditOwner[assetId] != address(0)) revert CreditAlreadyIssued(assetId);
        creditOwner[assetId] = to;
        ++balanceOf[to];
        ++totalIssued;
        emit CreditIssued(to, assetId);
    }

    function consume(address owner, uint256 assetId) external onlyRole(CONSUMER_ROLE) {
        if (creditOwner[assetId] != owner) revert NotCreditOwner(assetId);
        delete creditOwner[assetId];
        --balanceOf[owner];
        ++totalBurned;
        emit CreditBurned(owner, assetId);
    }

    function issueBatch(address to, uint256 firstAssetId, uint256 count) external onlyRole(ISSUER_ROLE) {
        for (uint256 i; i < count; ++i) {
            uint256 assetId = firstAssetId + i;
            if (creditOwner[assetId] != address(0)) revert CreditAlreadyIssued(assetId);
            creditOwner[assetId] = to;
            ++totalIssued;
            emit CreditIssued(to, assetId);
        }
        balanceOf[to] += count;
    }
}
