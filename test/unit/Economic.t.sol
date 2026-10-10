// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { TestBase } from "../TestBase.sol";
import { FeeEngine } from "../../src/economic/FeeEngine.sol";
import { HoldETHStrategy } from "../../src/strategy/HoldETHStrategy.sol";
import { RewardStrategyManager } from "../../src/economic/RewardStrategyManager.sol";
import { IBalanceEngine } from "../../src/interfaces/IFlux.sol";
import { RewardAssetRegistry } from "../../src/economic/RewardAssetRegistry.sol";
import { RewardVault } from "../../src/economic/RewardVault.sol";
import { ChainlinkVRFRandomProvider } from "../../src/integration/ChainlinkVRFRandomProvider.sol";
import { TraitGenerator } from "../../src/trait/TraitGenerator.sol";

contract EconomicTest is TestBase {
    receive() external payable { }

    function testBalanceEngineQuotesAllZones() public {
        IBalanceEngine.Quote memory high = balanceEngine.quote(5_000, 5_000, 100 ether, true);
        assertGt(high.reward, 0);
        assertEq(high.fee, 0);

        IBalanceEngine.Quote memory low = balanceEngine.quote(2_000, 8_000, 100 ether, false);
        assertGt(low.reward, 0);
        assertEq(low.fee, 0);

        IBalanceEngine.Quote memory penalized = balanceEngine.quote(2_000, 8_000, 0, true);
        assertGt(penalized.fee, 0);
        IBalanceEngine.Quote memory neutral = balanceEngine.quote(3_500, 6_500, 100 ether, true);
        assertEq(neutral.fee, 0);
        assertEq(neutral.reward, 0);
        IBalanceEngine.Quote memory empty = balanceEngine.quote(0, 0, 100 ether, true);
        assertGt(empty.fee, 0);

        balanceEngine.setParameters(2_500, 4_500, 0.02 ether, 200);
        assertEq(balanceEngine.maxFee(), 0.02 ether);
        vm.expectRevert();
        balanceEngine.setParameters(5_000, 4_000, 0, 0);
    }

    function testFeeDistributionAndGenesisAccounting() public {
        uint256 tokenId = _mintGenesis(alice, 10);
        vm.deal(address(feeEngine), 4 ether);
        feeEngine.distribute();
        assertEq(address(liquidityVault).balance, 1.2 ether);
        assertEq(address(balanceVault).balance, 11 ether);
        assertEq(address(protocolVault).balance, 0.8 ether);
        assertEq(genesisVault.pending(tokenId, address(0)), 1 ether);

        vm.prank(alice);
        genesisVault.claimAllRegistered(tokenId);
        assertEq(accountManager.account(tokenId).balance, 1 ether);

        FeeEngine.FeeSplit memory updated = FeeEngine.FeeSplit(2_500, 2_500, 2_500, 2_500);
        feeEngine.setFeeSplit(updated);
        vm.expectRevert(FeeEngine.InvalidFeeSplit.selector);
        feeEngine.setFeeSplit(FeeEngine.FeeSplit(1, 1, 1, 1));
    }

    function testRewardStrategyConfigurationPauseAndAdapter() public {
        HoldETHStrategy adapter = new HoldETHStrategy();
        assertEq(adapter.inputAsset(), address(0));
        assertEq(adapter.outputAsset(), address(0));
        bytes32 id = keccak256("HOLD");
        rewardStrategy.setStrategy(id, adapter);
        uint256 tokenId = _mintGenesis(alice, 77);
        vm.deal(address(rewardStrategy), 1 ether);
        uint256 out = rewardStrategy.execute{ value: 1 ether }(id, 1 ether, 1 ether, "");
        assertEq(out, 1 ether);
        assertEq(genesisVault.pending(tokenId, address(0)), 1 ether);

        rewardStrategy.setPaused(true);
        vm.expectRevert();
        rewardStrategy.holdNative{ value: 1 ether }();
        rewardStrategy.setPaused(false);
        vm.expectRevert();
        rewardStrategy.execute(bytes32("missing"), 0, 0, "");
    }

    function testBalanceVaultEpochAndProtocolVault() public {
        balanceVault.grantRole(balanceVault.REWARDER_ROLE(), address(this));
        balanceVault.setDailyReleaseBps(100);
        uint256 before = alice.balance;
        balanceVault.payReward(alice, 0.1 ether);
        assertEq(alice.balance, before + 0.1 ether);
        vm.expectRevert();
        balanceVault.payReward(alice, 2 ether);
        vm.warp(block.timestamp + 1 days);
        assertGt(balanceVault.availableReward(), 0);

        protocolVault.setRecipient(address(this));
        vm.deal(address(protocolVault), 1 ether);
        protocolVault.withdraw(1 ether);
        assertEq(address(protocolVault).balance, 0);

        RevertingEconomicReceiver receiver = new RevertingEconomicReceiver();
        protocolVault.setRecipient(address(receiver));
        vm.deal(address(protocolVault), 1 ether);
        vm.expectRevert();
        protocolVault.withdraw(1 ether);

        balanceVault.setDailyReleaseBps(10_000);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert();
        balanceVault.payReward(address(receiver), 1 wei);
    }

    function testRewardRegistryAndVaultBacking() public {
        assertTrue(rewardAssets.isRegistered(address(0)));
        vm.expectRevert();
        rewardAssets.registerAsset(address(0), RewardAssetRegistry.AssetType.Native, address(0));
        vm.expectRevert();
        rewardAssets.registerAsset(address(1), RewardAssetRegistry.AssetType.Native, address(0));
        rewardAssets.registerAsset(address(flux), RewardAssetRegistry.AssetType.ERC20, address(0));
        rewardAssets.disableAsset(address(flux));
        assertFalse(rewardAssets.isRegistered(address(flux)));
        vm.expectRevert();
        rewardAssets.disableAsset(address(2));

        rewardVault.grantRole(rewardVault.ACCOUNTANT_ROLE(), address(this));
        vm.deal(address(rewardVault), 1 ether);
        rewardVault.increaseLiability(address(0), 1 ether);
        assertEq(rewardVault.available(address(0)), 0);
        vm.expectRevert();
        rewardVault.increaseLiability(address(0), 1);
        rewardVault.pay(address(0), alice, 1 ether);
    }

    function testGenesisVaultErrorsAndDisabledAssetSettlement() public {
        uint256 tokenId = _mintGenesis(alice, 88);
        vm.expectRevert();
        genesisVault.claim(tokenId + 100, address(0));
        genesisVault.grantRole(genesisVault.DEPOSITOR_ROLE(), address(this));
        vm.expectRevert();
        genesisVault.deposit(address(0), 1);
        rewardAssets.disableAsset(address(0));
        accountManager.grantRole(accountManager.SETTLEMENT_ROLE(), address(this));
        accountManager.settleBeforeBurn(tokenId, alice);
    }

    function testTraitGeneratorRandomnessNotReady() public {
        ChainlinkVRFRandomProvider vrf = new ChainlinkVRFRandomProvider(makeAddr("coord"));
        traitGenerator.setRandomProvider(vrf);
        traitGenerator.grantRole(traitGenerator.CALLER_ROLE(), address(this));
        vm.expectRevert(
            abi.encodeWithSelector(TraitGenerator.RandomnessNotReady.selector, traitGenerator.randomNonce(500, 1, 1, alice))
        );
        traitGenerator.generate(500, 1, 1, alice);
    }

    function testRewardStrategyDepositFailed() public {
        RejectingRewardVault rejector = new RejectingRewardVault(address(this));
        RewardStrategyManager broken = new RewardStrategyManager(address(this), rejector, genesisVault);
        genesisVault.grantRole(genesisVault.DEPOSITOR_ROLE(), address(broken));
        rejector.grantRole(rejector.ACCOUNTANT_ROLE(), address(genesisVault));
        broken.grantRole(broken.EXECUTOR_ROLE(), address(this));
        vm.expectRevert(RewardStrategyManager.DepositFailed.selector);
        broken.holdNative{ value: 1 ether }();
    }
}

contract RejectingRewardVault is RewardVault {
    constructor(address admin) RewardVault(admin) {}

    receive() external payable override {
        revert();
    }
}

contract RevertingEconomicReceiver {
    receive() external payable {
        revert();
    }
}
