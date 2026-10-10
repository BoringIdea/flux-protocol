// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { TestBase } from "../TestBase.sol";
import { AssetRegistry } from "../../src/core/AssetRegistry.sol";

contract ProtocolFlowTest is TestBase {
    function testGenesisRewardClaimTransferAndAtomicBurn() public {
        uint256 tokenId = _mintGenesis(alice, 1);
        assertTrue(nft.isGenesis(tokenId));
        assertEq(genesisVault.activeGenesisSupply(), 1);

        vm.deal(address(rewardVault), 2 ether);
        genesisVault.deposit(address(0), 2 ether);
        assertEq(genesisVault.pending(tokenId, address(0)), 2 ether);

        vm.prank(alice);
        genesisVault.claim(tokenId, address(0));
        address tba = accountManager.account(tokenId);
        assertEq(tba.balance, 2 ether);

        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);
        assertEq(nft.ownerOf(tokenId), bob);

        uint256 fee = conversion.preview(false).fee;
        vm.prank(bob);
        conversion.nftToFT{ value: fee }(tokenId);

        assertEq(bob.balance, 102 ether - fee);
        assertEq(flux.balanceOf(bob), 10_000 ether);
        assertEq(genesisVault.activeGenesisSupply(), 0);
        assertEq(tba.balance, 0);
        AssetRegistry.AssetData memory data = registry.asset(1);
        assertEq(uint256(data.state), uint256(AssetRegistry.AssetState.FT));
        assertFalse(data.genesis);
    }

    function testFTToNFTAndBackMaintainsSupply() public {
        _mintFT(alice, 2);
        uint256 supply = flux.totalSupply();
        vm.startPrank(alice);
        uint256 tokenId = conversion.ftToNFT{ value: conversion.preview(true).fee }(777);
        assertEq(flux.totalSupply(), supply - 10_000 ether);
        assertFalse(nft.isGenesis(tokenId));
        conversion.nftToFT{ value: conversion.preview(false).fee }(tokenId);
        vm.stopPrank();
        assertEq(flux.totalSupply(), supply);
        assertEq(registry.accountedUnits(), 10_000);
    }

    function testMultipleGenesisShareRewardsAndBurnRedistributes() public {
        uint256 one = _mintGenesis(alice, 3);
        uint256 two = _mintGenesis(bob, 4);
        vm.deal(address(rewardVault), 4 ether);
        genesisVault.deposit(address(0), 4 ether);
        assertEq(genesisVault.pending(one, address(0)), 2 ether);
        assertEq(genesisVault.pending(two, address(0)), 2 ether);

        uint256 fee = conversion.preview(false).fee;
        vm.prank(alice);
        conversion.nftToFT{ value: fee }(one);
        vm.deal(address(rewardVault), address(rewardVault).balance + 1 ether);
        genesisVault.deposit(address(0), 1 ether);
        assertEq(genesisVault.pending(two, address(0)), 3 ether);
    }

    function testPauseAndFeeValidation() public {
        _mintFT(alice, 5);
        conversion.setPaused(true);
        vm.prank(alice);
        vm.expectRevert();
        conversion.ftToNFT(1);
        conversion.setPaused(false);

        vm.prank(alice);
        vm.expectRevert();
        conversion.ftToNFT{ value: 1 }(1);
    }

    function testFuzzRoundTrip(uint96 seed) public {
        _mintFT(alice, 6);
        vm.startPrank(alice);
        uint256 tokenId = conversion.ftToNFT{ value: conversion.preview(true).fee }(seed);
        conversion.nftToFT{ value: conversion.preview(false).fee }(tokenId);
        vm.stopPrank();
        assertEq(registry.accountedUnits(), 10_000);
        assertEq(flux.balanceOf(alice), 10_000 ether);
    }
}
