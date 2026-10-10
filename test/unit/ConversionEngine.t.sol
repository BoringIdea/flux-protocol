// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { TestBase } from "../TestBase.sol";
import { ConversionEngine } from "../../src/core/ConversionEngine.sol";
import { AssetRegistry } from "../../src/core/AssetRegistry.sol";
import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import {
    IFluxToken,
    IDynamicNFT,
    ITraitGenerator,
    IBalanceEngine,
    IBalanceVault,
    IAccountManager,
    IGenesisVault
} from "../../src/interfaces/IFlux.sol";
import { FailingReceiver } from "../mocks/MockUniswap.sol";

contract ConversionEngineTest is TestBase {
    using stdStorage for StdStorage;

    function testMaterializeFTFromCredit() public {
        _issue(alice, 20);
        vm.prank(alice);
        conversion.materializeFT(20);
        assertEq(flux.balanceOf(alice), 10_000 ether);
        assertEq(registry.stateCount(AssetRegistry.AssetState.FT), 5_001);
    }

    function testConversionWithDynamicFeeAndReward() public {
        uint256 tokenId = _mintGenesis(alice, 51);
        uint256 fee = conversion.preview(false).fee;
        assertGt(fee, 0);
        vm.deal(alice, fee);
        vm.prank(alice);
        conversion.nftToFT{ value: fee }(tokenId);
    }

    function testNoFTAssetAvailable() public {
        stdstore.target(address(conversion)).sig("initialFTCursor()").checked_write(5_000);
        flux.mint(alice, 10_000 ether);
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(ConversionEngine.NoFTAssetAvailable.selector);
        conversion.ftToNFT{ value: 0 }(1);
    }

    function testFeeEngineTransferFailureReverts() public {
        FailingReceiver failingFee = new FailingReceiver();
        ConversionEngine engine = _deployEngineWithFeeSink(address(failingFee));
        uint256 tokenId = _mintGenesisViaEngine(engine, alice, 52);
        uint256 fee = engine.preview(false).fee;
        assertGt(fee, 0);
        vm.deal(alice, fee);
        vm.prank(alice);
        vm.expectRevert(ConversionEngine.TransferFailed.selector);
        engine.nftToFT{ value: fee }(tokenId);
    }

    function testReceiveAcceptsEth() public {
        (bool ok,) = address(conversion).call{ value: 1 wei }("");
        assertTrue(ok);
    }

    function testPreviewReturnsNonZeroFeeWhenImbalanced() public view {
        IBalanceEngine.Quote memory q = conversion.preview(false);
        assertGt(q.fee, 0);
    }

    function testFtToNftWithRewardPayout() public {
        balanceEngine.setParameters(2_000, 3_000, 0, 500);
        balanceVault.setDailyReleaseBps(10_000);
        vm.warp(block.timestamp + 1 days);
        _mintFT(alice, 53);
        IBalanceEngine.Quote memory q = conversion.preview(true);
        assertGt(q.reward, 0);
        vm.deal(alice, q.fee);
        vm.prank(alice);
        conversion.ftToNFT{ value: q.fee }(999);
    }

    function _mintGenesisViaEngine(ConversionEngine engine, address to, uint256 assetId)
        internal
        returns (uint256 tokenId)
    {
        _issue(to, assetId);
        vm.prank(to);
        tokenId = engine.materializeGenesisNFT(assetId, assetId * 17);
    }

    function _deployEngineWithFeeSink(address feeSink)
        internal
        returns (ConversionEngine engine)
    {
        engine = new ConversionEngine(
            address(this),
            registry,
            credits,
            IFluxToken(address(flux)),
            IDynamicNFT(address(nft)),
            ITraitGenerator(address(traitGenerator)),
            balanceEngine,
            IBalanceVault(address(balanceVault)),
            IAccountManager(address(accountManager)),
            IGenesisVault(address(genesisVault)),
            feeSink
        );
        registry.grantRole(registry.CONTROLLER_ROLE(), address(engine));
        credits.grantRole(credits.CONSUMER_ROLE(), address(engine));
        flux.grantRole(flux.MINTER_ROLE(), address(engine));
        flux.grantRole(flux.BURNER_ROLE(), address(engine));
        nft.grantRole(nft.MINTER_ROLE(), address(engine));
        nft.grantRole(nft.BURNER_ROLE(), address(engine));
        traitGenerator.grantRole(traitGenerator.CALLER_ROLE(), address(engine));
        genesisVault.grantRole(genesisVault.CONTROLLER_ROLE(), address(engine));
        balanceVault.grantRole(balanceVault.REWARDER_ROLE(), address(engine));
        accountManager.grantRole(accountManager.SETTLEMENT_ROLE(), address(engine));
    }
}
