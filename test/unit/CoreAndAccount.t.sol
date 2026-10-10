// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { TestBase } from "../TestBase.sol";
import { AssetRegistry } from "../../src/core/AssetRegistry.sol";
import { ERC6551Registry } from "../../src/account/ERC6551Registry.sol";
import { FluxAccount } from "../../src/account/FluxAccount.sol";
import { TraitRenderer } from "../../src/trait/TraitRenderer.sol";
import { FrogBodyRenderer } from "../../src/trait/FrogBodyRenderer.sol";
import { FrogFaceRenderer } from "../../src/trait/FrogFaceRenderer.sol";
import { FrogHeadRenderer } from "../../src/trait/FrogHeadRenderer.sol";
import { TraitStorage } from "../../src/trait/TraitStorage.sol";
import { MockRandomProvider } from "../../src/integration/MockRandomProvider.sol";
import { SyncVRFRandomProvider } from "../../src/integration/SyncVRFRandomProvider.sol";
import { RewardAssetRegistry } from "../../src/economic/RewardAssetRegistry.sol";

contract CallTarget {
    uint256 public value;

    function set(uint256 value_) external payable returns (uint256) {
        value = value_;
        return value_;
    }
}

contract RevertingTarget {
    fallback() external payable {
        revert();
    }
}

contract CoreAndAccountTest is TestBase {
    function testAssetRegistryTransitionsAndErrors() public {
        assertEq(registry.accountedUnits(), 10_000);
        assertEq(registry.nftUnits(), 0);
        AssetRegistry.AssetData memory initialFT = registry.asset(5_001);
        assertEq(uint256(initialFT.state), uint256(AssetRegistry.AssetState.FT));
        vm.expectRevert(AssetRegistry.AlreadyInitialized.selector);
        registry.initializeGenesis(1);
        AssetRegistry oversized = new AssetRegistry(address(this));
        vm.expectRevert(abi.encodeWithSelector(AssetRegistry.InvalidAssetId.selector, 10_001));
        oversized.initializeGenesis(10_001);
        vm.expectRevert();
        registry.asset(0);

        registry.grantRole(registry.CONTROLLER_ROLE(), address(this));
        registry.transition(
            11, AssetRegistry.AssetState.Credit, AssetRegistry.AssetState.NFT, 99, false
        );
        assertEq(registry.nftUnits(), 1);
        vm.expectRevert();
        registry.transition(
            11, AssetRegistry.AssetState.Credit, AssetRegistry.AssetState.FT, 0, false
        );
        vm.expectRevert(AssetRegistry.InvalidGenesisTransition.selector);
        registry.transition(
            12, AssetRegistry.AssetState.Credit, AssetRegistry.AssetState.GenesisNFT, 1, false
        );
    }

    function testCreditIssueConsumeAndErrors() public {
        credits.issue(alice, 30);
        assertEq(credits.balanceOf(alice), 1);
        vm.expectRevert();
        credits.issue(alice, 30);
        credits.grantRole(credits.CONSUMER_ROLE(), address(this));
        vm.expectRevert();
        credits.consume(bob, 30);
        credits.consume(alice, 30);
        assertEq(credits.totalBurned(), 1);
    }

    function testTokenTraitNFTAndMetadataControls() public {
        flux.grantRole(flux.MINTER_ROLE(), address(this));
        flux.grantRole(flux.BURNER_ROLE(), address(this));
        flux.mint(alice, 1 ether);
        flux.burnFrom(alice, 0.5 ether);
        assertEq(flux.balanceOf(alice), 0.5 ether);
        uint256 maxSupply = flux.MAX_SUPPLY();
        vm.expectRevert();
        flux.mint(alice, maxSupply);

        MockRandomProvider mockRandom = new MockRandomProvider();
        mockRandom.setSalt(123);
        traitGenerator.setRandomProvider(mockRandom);
        traitGenerator.grantRole(traitGenerator.CALLER_ROLE(), address(this));
        uint256 seed = traitGenerator.generate(100, 1, 7, alice);
        assertTrue(seed != 0);
        TraitStorage.TraitData memory t = traitStorage.traits(100);
        _assertTraitRanges(t);
        vm.expectRevert();
        traitGenerator.generate(100, 1, 7, alice);

        nft.grantRole(nft.MINTER_ROLE(), address(this));
        nft.grantRole(nft.BURNER_ROLE(), address(this));
        uint256 id = nft.mintAsset(alice, 100, false, seed);
        assertTrue(bytes(nft.tokenURI(id)).length > 100);
        assertTrue(nft.supportsInterface(0x80ac58cd));
        assertEq(nft.assetOf(id), 100);
        nft.setRenderer(renderer);
        nft.burnAsset(id);
        vm.expectRevert();
        nft.burnAsset(id);
        vm.expectRevert();
        nft.assetOf(id);
        vm.expectRevert();
        nft.isGenesis(id);
        traitGenerator.release(100);
        vm.expectRevert();
        traitStorage.traits(100);
    }

    function testFullyOnchainFrogRendererVariants() public {
        TraitStorage localStorage = new TraitStorage(address(this));
        FrogBodyRenderer body = new FrogBodyRenderer();
        FrogFaceRenderer face = new FrogFaceRenderer();
        FrogHeadRenderer head = new FrogHeadRenderer();
        TraitRenderer localRenderer = new TraitRenderer(localStorage, body, face, head);
        localStorage.grantRole(localStorage.GENERATOR_ROLE(), address(this));

        (string memory backgroundBase,,) = body.backgroundColors(0);
        (string memory bodyBase,,,) = body.bodyColors(0);
        assertGt(bytes(backgroundBase).length, 0);
        assertGt(bytes(bodyBase).length, 0);
        assertGt(bytes(body.accent(0)).length, 0);

        for (uint16 style; style < 14; ++style) {
            assertGt(bytes(body.renderBackground(style, style)).length, 100);
        }
        for (uint16 style; style < 12; ++style) {
            assertGt(bytes(body.renderBody(style, style % 6)).length, 500);
        }
        for (uint16 style; style < 16; ++style) {
            assertGt(bytes(face.renderEyes(style, style)).length, 100);
            assertGt(bytes(face.renderMouth(style, style)).length, 0);
        }
        for (uint16 style; style < 18; ++style) {
            if (style == 0) assertEq(bytes(head.renderHead(style, style)).length, 0);
            else assertGt(bytes(head.renderHead(style, style)).length, 0);
        }
        for (uint16 style; style < 6; ++style) {
            if (style == 0) assertEq(bytes(head.renderAccessory(style, style)).length, 0);
            else assertGt(bytes(head.renderAccessory(style, style)).length, 0);
        }
        assertGt(bytes(head.genesisMark()).length, 100);

        localStorage.set(
            1_000,
            TraitStorage.TraitData({
                background: 11,
                backgroundStyle: 13,
                body: 11,
                skin: 5,
                eyes: 15,
                mouth: 15,
                head: 17,
                accessory: 5
            })
        );
        assertGt(bytes(localRenderer.renderSVG(1_000, true)).length, 1_000);
        assertGt(bytes(localRenderer.tokenURI(1_000, true)).length, 2_000);
        assertGt(bytes(localRenderer.tokenURI(1_000, false)).length, 2_000);
    }

    function testTraitRandomnessUsesBlockTokenAndOwnerEntropy() public {
        SyncVRFRandomProvider vrf = new SyncVRFRandomProvider();
        traitGenerator.setRandomProvider(vrf);
        traitGenerator.grantRole(traitGenerator.CALLER_ROLE(), address(this));

        vrf.requestRandom(traitGenerator.randomNonce(201, 9, 123, alice));
        uint256 first = traitGenerator.generate(201, 9, 123, alice);
        vm.roll(block.number + 7);
        vm.prevrandao(bytes32(uint256(456)));
        vrf.requestRandom(traitGenerator.randomNonce(202, 10, 123, bob));
        uint256 second = traitGenerator.generate(202, 10, 123, bob);
        vm.roll(0);
        vrf.requestRandom(traitGenerator.randomNonce(203, 11, 123, alice));
        uint256 genesisBlockSeed = traitGenerator.generate(203, 11, 123, alice);

        assertNotEq(first, second);
        assertNotEq(second, genesisBlockSeed);
        _assertTraitRanges(traitStorage.traits(201));
        _assertTraitRanges(traitStorage.traits(202));
        _assertTraitRanges(traitStorage.traits(203));
    }

    function testTokenBoundAccountOwnerExecutionAndSettlement() public {
        uint256 tokenId = _mintGenesis(alice, 40);
        address tba = accountManager.ensureAccount(tokenId);
        assertEq(accountManager.ensureAccount(tokenId), tba);
        assertEq(FluxAccount(payable(tba)).owner(), alice);
        (uint256 chainId, address tokenContract, uint256 boundTokenId) =
            FluxAccount(payable(tba)).token();
        assertEq(chainId, block.chainid);
        assertEq(tokenContract, address(nft));
        assertEq(boundTokenId, tokenId);

        CallTarget target = new CallTarget();
        vm.prank(alice);
        bytes memory result =
            FluxAccount(payable(tba)).execute(address(target), 0, abi.encodeCall(target.set, (42)));
        assertEq(abi.decode(result, (uint256)), 42);
        assertEq(target.value(), 42);
        assertEq(FluxAccount(payable(tba)).state(), 1);

        vm.prank(bob);
        vm.expectRevert(FluxAccount.NotOwner.selector);
        FluxAccount(payable(tba)).execute(address(target), 0, "");

        vm.deal(tba, 1 ether);
        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);
        assertEq(FluxAccount(payable(tba)).owner(), bob);
        uint256 fee = conversion.preview(false).fee;
        vm.prank(bob);
        conversion.nftToFT{ value: fee }(tokenId);
        assertEq(tba.balance, 0);
        assertEq(FluxAccount(payable(tba)).owner(), address(0));
    }

    function testERC6551StandardInterface() public {
        address impl = accountRegistry.implementation();
        bytes32 salt = keccak256("standard-salt");
        address created = accountRegistry.createAccount(
            impl, salt, block.chainid, address(nft), 123
        );
        assertEq(
            accountRegistry.account(impl, salt, block.chainid, address(nft), 123), created
        );
        assertEq(FluxAccount(payable(created)).implementation(), impl);
    }

    function testRegistryPermissionAndManagerRequirement() public {
        address impl =
            address(new FluxAccount(address(nft), type(uint256).max, address(0), block.chainid, address(0)));
        ERC6551Registry fresh = new ERC6551Registry(address(this), impl);
        vm.expectRevert(ERC6551Registry.ManagerNotSet.selector);
        fresh.createAccount(address(nft), 1);
        vm.prank(alice);
        vm.expectRevert(ERC6551Registry.NotAdmin.selector);
        fresh.setManager(alice);
        vm.prank(alice);
        vm.expectRevert(ERC6551Registry.NotAdmin.selector);
        fresh.transferAdmin(alice);
        fresh.transferAdmin(alice);
        assertEq(fresh.admin(), alice);
        vm.prank(alice);
        fresh.setManager(bob);
        address created = fresh.createAccount(address(nft), 999);
        assertEq(fresh.createAccount(address(nft), 999), created);
    }

    function testConversionQueueErrorsAndOwnership() public {
        assertEq(conversion.ftAssetCount(), 5_000);
        conversion.setPaused(true);
        conversion.setPaused(false);

        _mintFT(alice, 41);
        uint256 fee = conversion.preview(true).fee;
        vm.prank(alice);
        uint256 tokenId = conversion.ftToNFT{ value: fee }(1);
        vm.prank(bob);
        vm.expectRevert();
        conversion.nftToFT(tokenId);
    }

    function testERC20RewardClaimAndSweep() public {
        rewardAssets.registerAsset(address(flux), RewardAssetRegistry.AssetType.ERC20, address(0));
        uint256 tokenId = _mintGenesis(alice, 43);
        address tba = accountManager.ensureAccount(tokenId);
        flux.mint(address(rewardVault), 100 ether);
        genesisVault.deposit(address(flux), 100 ether);
        vm.prank(alice);
        genesisVault.claim(tokenId, address(flux));
        assertEq(flux.balanceOf(tba), 100 ether);

        uint256 fee = conversion.preview(false).fee;
        vm.prank(alice);
        conversion.nftToFT{ value: fee }(tokenId);
        assertEq(flux.balanceOf(tba), 0);
        assertEq(flux.balanceOf(alice), 10_100 ether);
    }

    function testLiquidityVaultAndFailedAccountExecution() public {
        liquidityVault.grantRole(liquidityVault.GENESIS_REGISTRAR_ROLE(), address(this));
        address locked = makeAddr("locked-position");
        liquidityVault.registerGenesisPosition(locked);
        liquidityVault.grantRole(liquidityVault.LP_MANAGER_ROLE(), address(this));
        CallTarget target = new CallTarget();
        vm.deal(address(liquidityVault), 1 ether);
        bytes memory compoundResult =
            liquidityVault.compound(address(target), 0.2 ether, abi.encodeCall(target.set, (99)));
        assertEq(target.value(), 99);
        assertEq(abi.decode(compoundResult, (uint256)), 99);

        address lockedPosition = liquidityVault.genesisPosition();
        vm.expectRevert();
        liquidityVault.compound(lockedPosition, 0, "");
        RevertingTarget revertingTarget = new RevertingTarget();
        vm.expectRevert();
        liquidityVault.compound(address(revertingTarget), 0, "");

        uint256 tokenId = _mintGenesis(alice, 44);
        address tba = accountManager.ensureAccount(tokenId);
        vm.prank(alice);
        vm.expectRevert(FluxAccount.ExecutionFailed.selector);
        FluxAccount(payable(tba)).execute(address(revertingTarget), 0, "");
        vm.prank(alice);
        vm.expectRevert(FluxAccount.NotManager.selector);
        FluxAccount(payable(tba)).protocolSweep(address(0), alice);

        genesisVault.grantRole(genesisVault.CONTROLLER_ROLE(), address(this));
        vm.expectRevert();
        genesisVault.addGenesis(tokenId);
    }

    function _assertTraitRanges(TraitStorage.TraitData memory t) internal pure {
        assertLt(t.background, 12);
        assertLt(t.backgroundStyle, 14);
        assertLt(t.body, 12);
        assertLt(t.skin, 6);
        assertLt(t.eyes, 16);
        assertLt(t.mouth, 16);
        assertLt(t.head, 18);
        assertLt(t.accessory, 6);
    }
}
