// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { TestBase } from "../TestBase.sol";
import { ConversionEngine } from "../../src/core/ConversionEngine.sol";
import { FluxToken } from "../../src/token/FluxToken.sol";
import { DynamicNFT } from "../../src/token/DynamicNFT.sol";
import { AssetRegistry } from "../../src/core/AssetRegistry.sol";

contract ConversionHandler {
    ConversionEngine public immutable conversion;
    FluxToken public immutable flux;
    DynamicNFT public immutable nft;
    uint256 public nextCredit = 101;
    uint256 public lastToken;

    constructor(ConversionEngine conversion_, FluxToken flux_, DynamicNFT nft_) {
        conversion = conversion_;
        flux = flux_;
        nft = nft_;
    }

    receive() external payable { }

    function materializeFT() external {
        if (nextCredit > 150) return;
        conversion.materializeFT(nextCredit++);
    }

    function convertToNFT(uint256 seed) external {
        if (flux.balanceOf(address(this)) < 10_000 ether) return;
        uint256 fee = conversion.preview(true).fee;
        if (address(this).balance < fee) return;
        lastToken = conversion.ftToNFT{ value: fee }(seed);
    }

    function convertToFT() external {
        uint256 tokenId = lastToken;
        if (tokenId == 0) return;
        try nft.ownerOf(tokenId) returns (address owner) {
            if (owner != address(this)) return;
        } catch {
            return;
        }
        uint256 fee = conversion.preview(false).fee;
        if (address(this).balance < fee) return;
        conversion.nftToFT{ value: fee }(tokenId);
        lastToken = 0;
    }
}

contract ProtocolInvariantTest is TestBase {
    ConversionHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new ConversionHandler(conversion, flux, nft);
        vm.deal(address(handler), 100 ether);
        for (uint256 i = 101; i <= 150; ++i) {
            credits.issue(address(handler), i);
        }
        targetContract(address(handler));
    }

    function invariantAssetUnitsAlwaysConserved() public view {
        assertEq(registry.accountedUnits(), 10_000);
    }

    function invariantFungibleSupplyMatchesFTUnits() public view {
        uint256 ftUnits = registry.stateCount(AssetRegistry.AssetState.FT);
        assertEq(flux.totalSupply() / 10_000 ether, ftUnits);
    }

    function invariantGenesisCannotIncreaseThroughRoundTrips() public view {
        assertEq(registry.stateCount(AssetRegistry.AssetState.GenesisNFT), 0);
        assertEq(genesisVault.activeGenesisSupply(), 0);
    }
}
