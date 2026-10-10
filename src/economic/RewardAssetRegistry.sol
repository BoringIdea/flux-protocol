// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract RewardAssetRegistry is AccessControl {
    enum AssetType {
        Native,
        ERC20
    }

    struct AssetConfig {
        AssetType assetType;
        bool enabled;
        address settlementAdapter;
    }

    address[] private _assets;
    mapping(address => AssetConfig) public config;
    mapping(address => bool) private _known;

    error AssetAlreadyRegistered(address asset);
    error AssetNotRegistered(address asset);
    error InvalidNativeAsset();

    event RewardAssetRegistered(
        address indexed asset, AssetType assetType, address settlementAdapter
    );
    event RewardAssetDisabled(address indexed asset);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function registerAsset(address asset, AssetType assetType, address settlementAdapter)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_known[asset]) revert AssetAlreadyRegistered(asset);
        if ((asset == address(0)) != (assetType == AssetType.Native)) revert InvalidNativeAsset();
        _known[asset] = true;
        _assets.push(asset);
        config[asset] = AssetConfig(assetType, true, settlementAdapter);
        emit RewardAssetRegistered(asset, assetType, settlementAdapter);
    }

    function disableAsset(address asset) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_known[asset]) revert AssetNotRegistered(asset);
        config[asset].enabled = false;
        emit RewardAssetDisabled(asset);
    }

    function isRegistered(address asset) external view returns (bool) {
        return _known[asset] && config[asset].enabled;
    }

    function registeredAssets() external view returns (address[] memory) {
        return _assets;
    }
}
