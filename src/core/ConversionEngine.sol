// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AssetRegistry } from "./AssetRegistry.sol";
import { CreditManager } from "./CreditManager.sol";
import {
    IFluxToken,
    IDynamicNFT,
    ITraitGenerator,
    IBalanceEngine,
    IBalanceVault,
    IAccountManager,
    IGenesisVault
} from "../interfaces/IFlux.sol";

contract ConversionEngine is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 public constant UNIT = 10_000 ether;

    AssetRegistry public immutable registry;
    CreditManager public immutable credits;
    IFluxToken public immutable flux;
    IDynamicNFT public immutable nft;
    ITraitGenerator public immutable traitGenerator;
    IBalanceEngine public immutable balanceEngine;
    IBalanceVault public immutable balanceVault;
    IAccountManager public immutable accountManager;
    IGenesisVault public immutable genesisVault;
    address public immutable feeEngine;

    uint256[] private _ftAssets;
    mapping(uint256 => bool) public queuedFTAsset;
    uint256 public initialFTCursor;
    uint256 public immutable initialFTFloor;

    error NotNFTOwner();
    error IncorrectFee(uint256 expected, uint256 actual);
    error NoFTAssetAvailable();
    error TransferFailed();

    event GenesisMaterialized(address indexed owner, uint256 indexed assetId, uint256 tokenId);
    event FTMaterialized(address indexed owner, uint256 indexed assetId, uint256 amount);
    event NFTBurnedToFT(address indexed owner, uint256 indexed tokenId, uint256 indexed assetId);
    event FTBurnedToNFT(address indexed owner, uint256 indexed tokenId, uint256 indexed assetId);

    constructor(
        address admin,
        AssetRegistry registry_,
        CreditManager credits_,
        IFluxToken flux_,
        IDynamicNFT nft_,
        ITraitGenerator traitGenerator_,
        IBalanceEngine balanceEngine_,
        IBalanceVault balanceVault_,
        IAccountManager accountManager_,
        IGenesisVault genesisVault_,
        address feeEngine_
    ) {
        registry = registry_;
        credits = credits_;
        flux = flux_;
        nft = nft_;
        traitGenerator = traitGenerator_;
        balanceEngine = balanceEngine_;
        balanceVault = balanceVault_;
        accountManager = accountManager_;
        genesisVault = genesisVault_;
        feeEngine = feeEngine_;
        initialFTCursor = registry_.MAX_ASSETS();
        initialFTFloor = registry_.initialCreditUnits();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    receive() external payable { }

    function setPaused(bool paused_) external onlyRole(PAUSER_ROLE) {
        if (paused_) _pause();
        else _unpause();
    }

    function materializeGenesisNFT(uint256 assetId, uint256 seed)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 tokenId)
    {
        credits.consume(msg.sender, assetId);
        traitGenerator.prepareRandom(assetId, nft.nextTokenId(), seed, msg.sender);
        uint256 traitSeed = traitGenerator.generate(assetId, nft.nextTokenId(), seed, msg.sender);
        tokenId = nft.mintAsset(msg.sender, assetId, true, traitSeed);
        registry.transition(
            assetId,
            AssetRegistry.AssetState.Credit,
            AssetRegistry.AssetState.GenesisNFT,
            tokenId,
            true
        );
        genesisVault.addGenesis(tokenId);
        emit GenesisMaterialized(msg.sender, assetId, tokenId);
    }

    function materializeFT(uint256 assetId) external whenNotPaused nonReentrant {
        credits.consume(msg.sender, assetId);
        registry.transition(
            assetId, AssetRegistry.AssetState.Credit, AssetRegistry.AssetState.FT, 0, false
        );
        _queueFT(assetId);
        flux.mint(msg.sender, UNIT);
        emit FTMaterialized(msg.sender, assetId, UNIT);
    }

    function nftToFT(uint256 tokenId) external payable whenNotPaused nonReentrant {
        if (nft.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();
        uint256 assetId = nft.assetOf(tokenId);
        bool genesis = nft.isGenesis(tokenId);
        IBalanceEngine.Quote memory q = preview(false);
        if (msg.value != q.fee) revert IncorrectFee(q.fee, msg.value);

        if (genesis) {
            genesisVault.removeGenesis(tokenId, msg.sender);
            accountManager.settleBeforeBurn(tokenId, msg.sender);
        }
        nft.burnAsset(tokenId);
        traitGenerator.release(assetId);
        registry.transition(
            assetId,
            genesis ? AssetRegistry.AssetState.GenesisNFT : AssetRegistry.AssetState.NFT,
            AssetRegistry.AssetState.FT,
            0,
            false
        );
        _queueFT(assetId);
        flux.mint(msg.sender, UNIT);
        _payFeeAndReward(q, msg.sender);
        emit NFTBurnedToFT(msg.sender, tokenId, assetId);
    }

    function ftToNFT(uint256 seed)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256 tokenId)
    {
        IBalanceEngine.Quote memory q = preview(true);
        if (msg.value != q.fee) revert IncorrectFee(q.fee, msg.value);
        uint256 assetId = _popFT();
        flux.burnFrom(msg.sender, UNIT);
        traitGenerator.prepareRandom(assetId, nft.nextTokenId(), seed, msg.sender);
        uint256 traitSeed = traitGenerator.generate(assetId, nft.nextTokenId(), seed, msg.sender);
        tokenId = nft.mintAsset(msg.sender, assetId, false, traitSeed);
        registry.transition(
            assetId, AssetRegistry.AssetState.FT, AssetRegistry.AssetState.NFT, tokenId, false
        );
        _payFeeAndReward(q, msg.sender);
        emit FTBurnedToNFT(msg.sender, tokenId, assetId);
    }

    function preview(bool ftToNft) public view returns (IBalanceEngine.Quote memory) {
        return balanceEngine.quote(
            registry.stateCount(AssetRegistry.AssetState.FT),
            registry.nftUnits(),
            balanceVault.availableReward(),
            ftToNft
        );
    }

    function ftAssetCount() external view returns (uint256) {
        return _ftAssets.length + initialFTCursor - initialFTFloor;
    }

    function _queueFT(uint256 assetId) internal {
        if (queuedFTAsset[assetId]) return;
        AssetRegistry.AssetData memory data = registry.asset(assetId);
        if (data.state != AssetRegistry.AssetState.FT) {
            revert AssetRegistry.InvalidState(assetId, AssetRegistry.AssetState.FT, data.state);
        }
        queuedFTAsset[assetId] = true;
        _ftAssets.push(assetId);
    }

    function _popFT() internal returns (uint256 assetId) {
        uint256 length = _ftAssets.length;
        if (length != 0) {
            assetId = _ftAssets[length - 1];
            _ftAssets.pop();
            queuedFTAsset[assetId] = false;
            return assetId;
        }
        if (initialFTCursor <= initialFTFloor) revert NoFTAssetAvailable();
        assetId = initialFTCursor--;
    }

    function _payFeeAndReward(IBalanceEngine.Quote memory q, address recipient) internal {
        if (q.fee != 0) {
            (bool ok,) = feeEngine.call{ value: q.fee }("");
            if (!ok) revert TransferFailed();
        }
        if (q.reward != 0) balanceVault.payReward(recipient, q.reward);
    }
}
