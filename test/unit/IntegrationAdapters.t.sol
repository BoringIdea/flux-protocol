// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { ChainlinkVRFRandomProvider } from "../../src/integration/ChainlinkVRFRandomProvider.sol";
import { SyncVRFRandomProvider } from "../../src/integration/SyncVRFRandomProvider.sol";
import { MockRandomProvider } from "../../src/integration/MockRandomProvider.sol";
import { UniswapV2LiquidityAdapter } from "../../src/integration/UniswapV2LiquidityAdapter.sol";
import { HoldETHStrategy } from "../../src/strategy/HoldETHStrategy.sol";
import { FluxToken } from "../../src/token/FluxToken.sol";
import {
    MockUniswapV2Factory,
    MockUniswapV2Pair,
    MockUniswapV2Router,
    FailingReceiver
} from "../mocks/MockUniswap.sol";

contract IntegrationAdaptersTest is Test {
    address internal coordinator = makeAddr("coordinator");
    address internal weth = makeAddr("weth");
    address internal lpLock = makeAddr("lpLock");

    function testChainlinkVRFRequestFulfillAndRead() public {
        ChainlinkVRFRandomProvider vrf = new ChainlinkVRFRandomProvider(coordinator);
        uint256 nonce = 42;
        uint256 requestId = vrf.requestRandom(nonce);
        assertFalse(vrf.isReady(nonce));
        vm.expectRevert(abi.encodeWithSelector(ChainlinkVRFRandomProvider.RandomnessNotReady.selector, nonce));
        vrf.random(nonce);
        vm.prank(coordinator);
        vrf.fulfillRandom(requestId, 777);
        assertTrue(vrf.isReady(nonce));
        assertEq(vrf.random(nonce), 777);
        assertEq(vrf.requestToNonce(requestId), nonce);
    }

    function testChainlinkVRFAccessControlAndPending() public {
        ChainlinkVRFRandomProvider vrf = new ChainlinkVRFRandomProvider(coordinator);
        vm.expectRevert(ChainlinkVRFRandomProvider.NotCoordinator.selector);
        vrf.fulfillRandom(1, 1);
        vm.prank(coordinator);
        vrf.setCoordinator(makeAddr("newCoordinator"));
        address newCoordinator = vrf.coordinator();
        uint256 nonce = 99;
        uint256 requestId = vrf.requestRandom(nonce);
        vm.prank(newCoordinator);
        vrf.fulfillRandom(requestId, 1);
        vm.expectRevert(abi.encodeWithSelector(ChainlinkVRFRandomProvider.RequestAlreadyPending.selector, nonce));
        vrf.requestRandom(nonce);
    }

    function testChainlinkVRFInitialCoordinatorUpdate() public {
        ChainlinkVRFRandomProvider vrf = new ChainlinkVRFRandomProvider(address(0));
        vrf.setCoordinator(coordinator);
        assertEq(vrf.coordinator(), coordinator);
    }

    function testSyncVRFRequestFulfillAndManualFulfill() public {
        SyncVRFRandomProvider vrf = new SyncVRFRandomProvider();
        uint256 nonce = 7;
        assertFalse(vrf.isReady(nonce));
        uint256 requestId = vrf.requestRandom(nonce);
        assertTrue(vrf.isReady(nonce));
        assertEq(vrf.random(nonce), requestId);
        vrf.fulfillRandom(nonce + 1, 555);
        assertEq(vrf.random(nonce + 1), 555);
    }

    function testSyncVRFNotReady() public {
        SyncVRFRandomProvider vrf = new SyncVRFRandomProvider();
        vm.expectRevert(abi.encodeWithSelector(SyncVRFRandomProvider.RandomnessNotReady.selector, 1));
        vrf.random(1);
    }

    function testMockRandomProvider() public {
        MockRandomProvider mock = new MockRandomProvider();
        mock.setSalt(999);
        assertTrue(mock.isReady(0));
        assertEq(mock.random(1), uint256(keccak256(abi.encode(1, 999, address(mock)))));
        assertGt(mock.requestRandom(2), 0);
    }

    function testHoldETHStrategy() public {
        HoldETHStrategy strategy = new HoldETHStrategy();
        assertEq(strategy.inputAsset(), address(0));
        assertEq(strategy.outputAsset(), address(0));
        uint256 before = address(this).balance;
        uint256 out = strategy.execute{ value: 1 ether }(1 ether, 1 ether, "");
        assertEq(out, 1 ether);
        assertGe(address(this).balance, before);
        vm.expectRevert(HoldETHStrategy.InvalidAmount.selector);
        strategy.execute{ value: 0.5 ether }(1 ether, 1 ether, "");
        RevertingStrategyCaller caller = new RevertingStrategyCaller(strategy);
        vm.deal(address(caller), 1 ether);
        vm.expectRevert(HoldETHStrategy.TransferFailed.selector);
        caller.run{ value: 1 ether }();
    }

    function testUniswapV2LiquidityAdapterInitializeAndCompound() public {
        FluxToken flux = new FluxToken(address(this));
        flux.grantRole(flux.MINTER_ROLE(), address(this));
        MockUniswapV2Factory factory = new MockUniswapV2Factory();
        MockUniswapV2Router router = new MockUniswapV2Router(address(factory), weth);
        MockUniswapV2Pair pair = new MockUniswapV2Pair(address(flux), weth);
        factory.setPair(address(flux), weth, address(pair));
        UniswapV2LiquidityAdapter adapter =
            new UniswapV2LiquidityAdapter(address(router), lpLock);

        flux.mint(address(this), 100 ether);
        flux.approve(address(adapter), 100 ether);
        uint256 positionId = adapter.initializePool{ value: 1 ether }(address(flux), 50 ether, 0, "");
        assertEq(positionId, uint256(uint160(address(pair))));
        assertEq(router.lastRecipient(), lpLock);

        flux.approve(address(adapter), 10 ether);
        uint256 added = adapter.compound{ value: 1 ether }(
            positionId, 0, abi.encode(10 ether)
        );
        assertEq(added, 11 ether);
    }

    function testUniswapV2LiquidityAdapterToken0IsWeth() public {
        FluxToken flux = new FluxToken(address(this));
        flux.grantRole(flux.MINTER_ROLE(), address(this));
        MockUniswapV2Factory factory = new MockUniswapV2Factory();
        MockUniswapV2Router router = new MockUniswapV2Router(address(factory), weth);
        MockUniswapV2Pair pair = new MockUniswapV2Pair(weth, address(flux));
        factory.setPair(address(flux), weth, address(pair));
        UniswapV2LiquidityAdapter adapter =
            new UniswapV2LiquidityAdapter(address(router), lpLock);
        flux.mint(address(this), 10 ether);
        flux.approve(address(adapter), 10 ether);
        adapter.initializePool{ value: 1 ether }(address(flux), 5 ether, 0, "");
        adapter.compound{ value: 1 ether }(uint256(uint160(address(pair))), 0, "");
    }

    function testUniswapV2LiquidityAdapterValidation() public {
        vm.expectRevert(UniswapV2LiquidityAdapter.InvalidRouter.selector);
        new UniswapV2LiquidityAdapter(address(0), lpLock);
        MockUniswapV2Router router = new MockUniswapV2Router(address(0xBEEF), weth);
        vm.expectRevert(UniswapV2LiquidityAdapter.InvalidRouter.selector);
        new UniswapV2LiquidityAdapter(address(router), address(0));

        UniswapV2LiquidityAdapter adapter =
            new UniswapV2LiquidityAdapter(address(router), lpLock);
        FluxToken flux = new FluxToken(address(this));
        flux.grantRole(flux.MINTER_ROLE(), address(this));
        flux.mint(address(this), 1 ether);
        flux.approve(address(adapter), 1 ether);
        vm.expectRevert(UniswapV2LiquidityAdapter.PoolInitializationFailed.selector);
        adapter.initializePool{ value: 1 ether }(address(flux), 1 ether, 100 ether, "");
        vm.expectRevert(UniswapV2LiquidityAdapter.PoolInitializationFailed.selector);
        adapter.compound(0, 0, "");
    }

    receive() external payable { }
}

contract RevertingStrategyCaller {
    HoldETHStrategy public immutable strategy;

    constructor(HoldETHStrategy strategy_) {
        strategy = strategy_;
    }

    function run() external payable {
        strategy.execute{ value: msg.value }(msg.value, msg.value, "");
    }

    receive() external payable {
        revert();
    }
}
