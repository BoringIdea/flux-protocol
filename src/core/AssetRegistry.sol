// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract AssetRegistry is AccessControl {
    enum AssetState {
        Uninitialized,
        Credit,
        GenesisNFT,
        NFT,
        FT
    }

    struct AssetData {
        AssetState state;
        bool genesis;
        uint256 tokenId;
    }

    uint256 public constant MAX_ASSETS = 10_000;
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    mapping(uint256 => AssetData) private _assets;
    mapping(uint256 => bool) private _overridden;
    mapping(AssetState => uint256) public stateCount;
    bool public initialized;
    uint256 public initialCreditUnits;

    error AlreadyInitialized();
    error InvalidAssetId(uint256 assetId);
    error InvalidState(uint256 assetId, AssetState expected, AssetState actual);
    error InvalidGenesisTransition();

    event RegistryInitialized(uint256 creditUnits, uint256 ftUnits);
    event AssetTransition(
        uint256 indexed assetId, AssetState indexed from, AssetState indexed to, uint256 tokenId
    );

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function initializeGenesis(uint256 creditUnits) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (initialized) revert AlreadyInitialized();
        if (creditUnits > MAX_ASSETS) revert InvalidAssetId(creditUnits);
        initialized = true;
        initialCreditUnits = creditUnits;
        stateCount[AssetState.Credit] = creditUnits;
        stateCount[AssetState.FT] = MAX_ASSETS - creditUnits;
        emit RegistryInitialized(creditUnits, MAX_ASSETS - creditUnits);
    }

    function transition(
        uint256 assetId,
        AssetState expected,
        AssetState next,
        uint256 tokenId,
        bool genesis
    ) external onlyRole(CONTROLLER_ROLE) {
        _checkId(assetId);
        AssetData storage data = _assets[assetId];
        AssetState actual = _stateOf(assetId);
        if (actual != expected) revert InvalidState(assetId, expected, actual);
        if (next == AssetState.GenesisNFT && (!genesis || expected != AssetState.Credit)) {
            revert InvalidGenesisTransition();
        }
        if (genesis && next == AssetState.NFT) revert InvalidGenesisTransition();

        --stateCount[expected];
        ++stateCount[next];
        _overridden[assetId] = true;
        data.state = next;
        data.genesis = next == AssetState.GenesisNFT;
        data.tokenId = (next == AssetState.NFT || next == AssetState.GenesisNFT) ? tokenId : 0;
        emit AssetTransition(assetId, expected, next, data.tokenId);
    }

    function asset(uint256 assetId) external view returns (AssetData memory) {
        _checkId(assetId);
        if (_overridden[assetId]) return _assets[assetId];
        return AssetData(_stateOf(assetId), false, 0);
    }

    function accountedUnits() external view returns (uint256 total) {
        total = stateCount[AssetState.Credit] + stateCount[AssetState.GenesisNFT]
            + stateCount[AssetState.NFT] + stateCount[AssetState.FT];
    }

    function nftUnits() external view returns (uint256) {
        return stateCount[AssetState.GenesisNFT] + stateCount[AssetState.NFT];
    }

    function _checkId(uint256 assetId) internal pure {
        if (assetId == 0 || assetId > MAX_ASSETS) revert InvalidAssetId(assetId);
    }

    function _stateOf(uint256 assetId) internal view returns (AssetState) {
        if (_overridden[assetId]) return _assets[assetId].state;
        return assetId <= initialCreditUnits ? AssetState.Credit : AssetState.FT;
    }
}
