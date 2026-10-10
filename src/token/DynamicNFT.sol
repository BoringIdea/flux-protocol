// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { TraitRenderer } from "../trait/TraitRenderer.sol";

contract DynamicNFT is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    struct NFTData {
        bool genesis;
        bool alive;
        uint256 traitSeed;
        uint256 assetId;
    }

    TraitRenderer public renderer;
    uint256 public nextTokenId = 1;
    mapping(uint256 => NFTData) private _data;

    error TokenNotAlive(uint256 tokenId);

    event RendererUpdated(address indexed renderer);

    constructor(address admin, TraitRenderer renderer_) ERC721("Flux Dynamic Asset", "FLUX-NFT") {
        renderer = renderer_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setRenderer(TraitRenderer renderer_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        renderer = renderer_;
        emit RendererUpdated(address(renderer_));
    }

    function mintAsset(address to, uint256 assetId, bool genesis, uint256 seed)
        external
        onlyRole(MINTER_ROLE)
        returns (uint256 tokenId)
    {
        tokenId = nextTokenId++;
        _data[tokenId] = NFTData(genesis, true, seed, assetId);
        _safeMint(to, tokenId);
    }

    function burnAsset(uint256 tokenId)
        external
        onlyRole(BURNER_ROLE)
        returns (uint256 assetId, bool genesis)
    {
        NFTData storage data = _data[tokenId];
        if (!data.alive) revert TokenNotAlive(tokenId);
        assetId = data.assetId;
        genesis = data.genesis;
        data.alive = false;
        _burn(tokenId);
    }

    function assetOf(uint256 tokenId) external view returns (uint256) {
        if (!_data[tokenId].alive) revert TokenNotAlive(tokenId);
        return _data[tokenId].assetId;
    }

    function isGenesis(uint256 tokenId) external view returns (bool) {
        if (!_data[tokenId].alive) revert TokenNotAlive(tokenId);
        return _data[tokenId].genesis;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        NFTData storage data = _data[tokenId];
        return renderer.tokenURI(data.assetId, data.genesis);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
