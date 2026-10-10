// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { RewardAssetRegistry } from "./RewardAssetRegistry.sol";
import { RewardVault } from "./RewardVault.sol";
import { AccountManager } from "../account/AccountManager.sol";

contract GenesisVault is AccessControl, ReentrancyGuard {
    uint256 private constant ACC_PRECISION = 1e36;
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    RewardVault public immutable rewardVault;
    RewardAssetRegistry public immutable rewardAssets;
    AccountManager public accountManager;
    uint256 public activeGenesisSupply;

    mapping(uint256 => bool) public active;
    mapping(address => uint256) public accRewardPerGenesis;
    mapping(uint256 => mapping(address => uint256)) public rewardDebt;

    error NoActiveGenesis();
    error NotActiveGenesis(uint256 tokenId);
    error AlreadyActive(uint256 tokenId);
    error UnsupportedReward(address asset);

    event GenesisAdded(uint256 indexed tokenId);
    event GenesisRemoved(uint256 indexed tokenId);
    event RewardDeposited(address indexed asset, uint256 amount);
    event RewardClaimed(
        uint256 indexed tokenId, address indexed asset, address account, uint256 amount
    );

    constructor(address admin, RewardVault rewardVault_, RewardAssetRegistry rewardAssets_) {
        rewardVault = rewardVault_;
        rewardAssets = rewardAssets_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setAccountManager(AccountManager manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        accountManager = manager;
    }

    function addGenesis(uint256 tokenId) external onlyRole(CONTROLLER_ROLE) {
        if (active[tokenId]) revert AlreadyActive(tokenId);
        active[tokenId] = true;
        ++activeGenesisSupply;
        address[] memory assets = rewardAssets.registeredAssets();
        for (uint256 i; i < assets.length; ++i) {
            rewardDebt[tokenId][assets[i]] = accRewardPerGenesis[assets[i]];
        }
        emit GenesisAdded(tokenId);
    }

    function deposit(address asset, uint256 amount) external onlyRole(DEPOSITOR_ROLE) {
        if (!rewardAssets.isRegistered(asset)) revert UnsupportedReward(asset);
        if (activeGenesisSupply == 0) revert NoActiveGenesis();
        rewardVault.increaseLiability(asset, amount);
        accRewardPerGenesis[asset] += amount * ACC_PRECISION / activeGenesisSupply;
        emit RewardDeposited(asset, amount);
    }

    function claim(uint256 tokenId, address asset) public nonReentrant returns (uint256 amount) {
        if (!active[tokenId]) revert NotActiveGenesis(tokenId);
        amount = _claim(tokenId, asset);
    }

    function claimAllRegistered(uint256 tokenId) public nonReentrant returns (uint256 total) {
        if (!active[tokenId]) revert NotActiveGenesis(tokenId);
        address[] memory assets = rewardAssets.registeredAssets();
        for (uint256 i; i < assets.length; ++i) {
            total += _claim(tokenId, assets[i]);
        }
    }

    function removeGenesis(uint256 tokenId, address) external onlyRole(CONTROLLER_ROLE) {
        if (!active[tokenId]) revert NotActiveGenesis(tokenId);
        address[] memory assets = rewardAssets.registeredAssets();
        for (uint256 i; i < assets.length; ++i) {
            _claim(tokenId, assets[i]);
        }
        active[tokenId] = false;
        --activeGenesisSupply;
        emit GenesisRemoved(tokenId);
    }

    function pending(uint256 tokenId, address asset) public view returns (uint256) {
        if (!active[tokenId]) return 0;
        return (accRewardPerGenesis[asset] - rewardDebt[tokenId][asset]) / ACC_PRECISION;
    }

    function _claim(uint256 tokenId, address asset) internal returns (uint256 amount) {
        uint256 accumulated = accRewardPerGenesis[asset];
        amount = (accumulated - rewardDebt[tokenId][asset]) / ACC_PRECISION;
        rewardDebt[tokenId][asset] = accumulated;
        if (amount != 0) {
            address account_ = accountManager.ensureAccount(tokenId);
            rewardVault.pay(asset, account_, amount);
            emit RewardClaimed(tokenId, asset, account_, amount);
        }
    }
}
