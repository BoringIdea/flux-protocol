// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { RewardVault } from "./RewardVault.sol";
import { GenesisVault } from "./GenesisVault.sol";
import { IRewardStrategy } from "../interfaces/IFlux.sol";

contract RewardStrategyManager is AccessControl, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    RewardVault public immutable rewardVault;
    GenesisVault public immutable genesisVault;
    mapping(bytes32 => IRewardStrategy) public strategy;

    error StrategyNotConfigured(bytes32 id);
    error InvalidOutput(uint256 actual, uint256 minimum);
    error DepositFailed();

    event StrategySet(bytes32 indexed id, address indexed adapter);
    event RewardStrategyExecuted(
        bytes32 indexed id, address indexed outputAsset, uint256 amountOut
    );

    constructor(address admin, RewardVault rewardVault_, GenesisVault genesisVault_) {
        rewardVault = rewardVault_;
        genesisVault = genesisVault_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    receive() external payable { }

    function setStrategy(bytes32 id, IRewardStrategy adapter)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        strategy[id] = adapter;
        emit StrategySet(id, address(adapter));
    }

    function setPaused(bool paused_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (paused_) _pause();
        else _unpause();
    }

    function holdNative() external payable onlyRole(EXECUTOR_ROLE) whenNotPaused {
        _depositReward(address(0), msg.value);
        emit RewardStrategyExecuted(bytes32(0), address(0), msg.value);
    }

    function execute(bytes32 id, uint256 amountIn, uint256 minAmountOut, bytes calldata data)
        external
        payable
        onlyRole(EXECUTOR_ROLE)
        whenNotPaused
        returns (uint256 amountOut)
    {
        IRewardStrategy adapter = strategy[id];
        if (address(adapter) == address(0)) revert StrategyNotConfigured(id);
        amountOut = adapter.execute{ value: msg.value }(amountIn, minAmountOut, data);
        if (amountOut < minAmountOut) revert InvalidOutput(amountOut, minAmountOut);
        _depositReward(adapter.outputAsset(), amountOut);
        emit RewardStrategyExecuted(id, adapter.outputAsset(), amountOut);
    }

    function _depositReward(address asset, uint256 amount) internal {
        if (amount == 0) return;
        if (asset == address(0)) {
            (bool ok,) = address(rewardVault).call{ value: amount }("");
            if (!ok) revert DepositFailed();
        } else {
            IERC20(asset).safeTransfer(address(rewardVault), amount);
        }
        genesisVault.deposit(asset, amount);
    }
}
