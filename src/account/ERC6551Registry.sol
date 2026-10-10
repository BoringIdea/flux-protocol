// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { FluxAccount } from "./FluxAccount.sol";
import { IERC6551Registry } from "../interfaces/IERC6551.sol";

/// @notice ERC-6551 compatible registry with Flux-specific helpers.
contract ERC6551Registry is IERC6551Registry {
    address public manager;
    address public admin;
    address public implementation;
    mapping(bytes32 => address) private _accounts;

    error NotAdmin();
    error ManagerNotSet();
    error ImplementationNotSet();

    event ManagerSet(address indexed manager);
    event ImplementationSet(address indexed implementation);
    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);
    event TokenBoundAccountCreated(address indexed nft, uint256 indexed tokenId, address account);

    constructor(address admin_, address implementation_) {
        admin = admin_;
        implementation = implementation_;
    }

    function setManager(address manager_) external {
        if (msg.sender != admin) revert NotAdmin();
        manager = manager_;
        emit ManagerSet(manager_);
    }

    function setImplementation(address implementation_) external {
        if (msg.sender != admin) revert NotAdmin();
        implementation = implementation_;
        emit ImplementationSet(implementation_);
    }

    function transferAdmin(address newAdmin) external {
        if (msg.sender != admin) revert NotAdmin();
        emit AdminTransferred(admin, newAdmin);
        admin = newAdmin;
    }

    function createAccount(
        address implementation_,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address account_) {
        account_ = _createAccount(implementation_, salt, chainId, tokenContract, tokenId);
    }

    function account(
        address implementation_,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external view returns (address) {
        return _accounts[_accountKey(implementation_, salt, chainId, tokenContract, tokenId)];
    }

    function account(address nft, uint256 tokenId) public view returns (address) {
        return _accounts[_accountKey(implementation, _fluxSalt(nft, tokenId), block.chainid, nft, tokenId)];
    }

    function createAccount(address nft, uint256 tokenId) external returns (address account_) {
        if (manager == address(0)) revert ManagerNotSet();
        if (implementation == address(0)) revert ImplementationNotSet();
        account_ = _createAccount(implementation, _fluxSalt(nft, tokenId), block.chainid, nft, tokenId);
        emit TokenBoundAccountCreated(nft, tokenId, account_);
    }

    function _createAccount(
        address implementation_,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal returns (address account_) {
        bytes32 key = _accountKey(implementation_, salt, chainId, tokenContract, tokenId);
        account_ = _accounts[key];
        if (account_ == address(0)) {
            account_ = address(
                new FluxAccount{ salt: salt }(tokenContract, tokenId, manager, chainId, implementation_)
            );
            _accounts[key] = account_;
            emit AccountCreated(account_, implementation_, salt, chainId, tokenContract, tokenId);
        }
    }

    function _fluxSalt(address nft, uint256 tokenId) internal view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, nft, tokenId));
    }

    function _accountKey(
        address implementation_,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(implementation_, salt, chainId, tokenContract, tokenId));
    }
}
