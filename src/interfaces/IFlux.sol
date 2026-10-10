// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IFluxToken {
    function mint(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IDynamicNFT {
    function mintAsset(address to, uint256 assetId, bool genesis, uint256 seed)
        external
        returns (uint256 tokenId);
    function burnAsset(uint256 tokenId) external returns (uint256 assetId, bool genesis);
    function ownerOf(uint256 tokenId) external view returns (address);
    function assetOf(uint256 tokenId) external view returns (uint256);
    function isGenesis(uint256 tokenId) external view returns (bool);
    function nextTokenId() external view returns (uint256);
}

interface ITraitGenerator {
    function generate(uint256 assetId, uint256 tokenId, uint256 seed, address owner)
        external
        returns (uint256 traitSeed);
    function release(uint256 assetId) external;
    function prepareRandom(uint256 assetId, uint256 tokenId, uint256 seed, address owner)
        external
        returns (uint256 nonce);
    function randomNonce(uint256 assetId, uint256 tokenId, uint256 seed, address owner)
        external
        view
        returns (uint256);
}

interface IBalanceEngine {
    struct Quote {
        uint256 fee;
        uint256 reward;
    }

    function quote(uint256 ftUnits, uint256 nftUnits, uint256 vaultBalance, bool ftToNft)
        external
        view
        returns (Quote memory);
}

interface IBalanceVault {
    function payReward(address to, uint256 amount) external;
    function availableReward() external view returns (uint256);
}

interface IAccountManager {
    function account(uint256 tokenId) external view returns (address);
    function settleBeforeBurn(uint256 tokenId, address recipient) external;
}

interface IGenesisVault {
    function activeGenesisSupply() external view returns (uint256);
    function addGenesis(uint256 tokenId) external;
    function removeGenesis(uint256 tokenId, address recipient) external;
}

interface IRewardStrategy {
    function inputAsset() external view returns (address);
    function outputAsset() external view returns (address);
    function execute(uint256 amountIn, uint256 minAmountOut, bytes calldata data)
        external
        payable
        returns (uint256 amountOut);
}

interface IRandomProvider {
    function random(uint256 nonce) external view returns (uint256);

    function isReady(uint256 nonce) external view returns (bool);

    function requestRandom(uint256 nonce) external returns (uint256 requestId);
}
