// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { TraitStorage } from "./TraitStorage.sol";
import { IRandomProvider } from "../interfaces/IFlux.sol";

contract TraitGenerator is AccessControl {
    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");
    TraitStorage public immutable traitStorage;
    IRandomProvider public randomProvider;

    error RandomnessNotReady(uint256 nonce);

    event RandomProviderUpdated(address indexed provider);
    event RandomnessPrepared(uint256 indexed nonce);

    constructor(address admin, TraitStorage storage_, IRandomProvider provider) {
        traitStorage = storage_;
        randomProvider = provider;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setRandomProvider(IRandomProvider provider) external onlyRole(DEFAULT_ADMIN_ROLE) {
        randomProvider = provider;
        emit RandomProviderUpdated(address(provider));
    }

    function randomNonce(uint256 assetId, uint256 tokenId, uint256 seed, address owner)
        public
        view
        returns (uint256)
    {
        return uint256(keccak256(abi.encode(assetId, tokenId, seed, owner, block.chainid)));
    }

    function prepareRandom(uint256 assetId, uint256 tokenId, uint256 seed, address owner)
        external
        onlyRole(CALLER_ROLE)
        returns (uint256 nonce)
    {
        nonce = randomNonce(assetId, tokenId, seed, owner);
        if (!randomProvider.isReady(nonce)) {
            randomProvider.requestRandom(nonce);
        }
        emit RandomnessPrepared(nonce);
    }

    function generate(uint256 assetId, uint256 tokenId, uint256 seed, address owner)
        external
        onlyRole(CALLER_ROLE)
        returns (uint256 traitSeed)
    {
        uint256 nonce = randomNonce(assetId, tokenId, seed, owner);
        if (!randomProvider.isReady(nonce)) revert RandomnessNotReady(nonce);
        bytes32 previousBlockHash = block.number == 0 ? bytes32(0) : blockhash(block.number - 1);
        uint256 providerEntropy = randomProvider.random(nonce);
        traitSeed = uint256(
            keccak256(
                abi.encode(
                    providerEntropy,
                    assetId,
                    tokenId,
                    seed,
                    owner,
                    block.chainid,
                    block.number,
                    block.prevrandao,
                    previousBlockHash,
                    address(this)
                )
            )
        );
        TraitStorage.TraitData memory data = TraitStorage.TraitData({
            background: uint16(traitSeed % 12),
            backgroundStyle: uint16((traitSeed >> 16) % 14),
            body: uint16((traitSeed >> 32) % 12),
            skin: uint16((traitSeed >> 48) % 6),
            eyes: uint16((traitSeed >> 64) % 16),
            mouth: uint16((traitSeed >> 80) % 16),
            head: uint16((traitSeed >> 96) % 18),
            accessory: uint16((traitSeed >> 112) % 6)
        });
        traitStorage.set(assetId, data);
    }

    function release(uint256 assetId) external onlyRole(CALLER_ROLE) {
        traitStorage.release(assetId);
    }
}
