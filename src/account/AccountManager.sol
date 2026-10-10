// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ERC6551Registry } from "./ERC6551Registry.sol";
import { FluxAccount } from "./FluxAccount.sol";
import { RewardAssetRegistry } from "../economic/RewardAssetRegistry.sol";

contract AccountManager is AccessControl, ReentrancyGuard {
    bytes32 public constant SETTLEMENT_ROLE = keccak256("SETTLEMENT_ROLE");
    ERC6551Registry public immutable registry;
    RewardAssetRegistry public immutable rewardAssets;
    address public immutable nft;

    event AccountAssetSwept(
        uint256 indexed tokenId, address indexed asset, address indexed recipient, uint256 amount
    );
    event GenesisBurnSettled(uint256 indexed tokenId, address indexed recipient);

    constructor(
        address admin,
        ERC6551Registry registry_,
        RewardAssetRegistry rewardAssets_,
        address nft_
    ) {
        registry = registry_;
        rewardAssets = rewardAssets_;
        nft = nft_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function account(uint256 tokenId) public view returns (address) {
        return registry.account(nft, tokenId);
    }

    function ensureAccount(uint256 tokenId) public returns (address) {
        return registry.createAccount(nft, tokenId);
    }

    function settleBeforeBurn(uint256 tokenId, address recipient)
        external
        onlyRole(SETTLEMENT_ROLE)
        nonReentrant
    {
        address account_ = ensureAccount(tokenId);
        address[] memory assets = rewardAssets.registeredAssets();
        for (uint256 i; i < assets.length; ++i) {
            (, bool enabled,) = rewardAssets.config(assets[i]);
            if (!enabled) continue;
            uint256 amount = FluxAccount(payable(account_)).protocolSweep(assets[i], recipient);
            emit AccountAssetSwept(tokenId, assets[i], recipient, amount);
        }
        emit GenesisBurnSettled(tokenId, recipient);
    }
}
