// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { CreditManager } from "../core/CreditManager.sol";
import { IFluxToken } from "../interfaces/IFlux.sol";
import { ILiquidityMigrator } from "../interfaces/ILiquidityMigrator.sol";
import { LiquidityVault } from "../vault/LiquidityVault.sol";
import { CCAAllocator } from "./CCAAllocator.sol";

/// @notice Scheme C Genesis launch: continuous MPS Credit auction + Uniswap v4 LP bootstrap.
contract GenesisAuction is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 internal constant WAD = 1e18;

    enum AuctionState {
        Pending,
        Active,
        Finished
    }

    struct Bid {
        uint128 budget;
        uint128 maxPrice;
        uint256 allocatedCredits;
        uint256 spent;
        uint256 refundAmount;
        uint256 creditsClaimed;
        bool claimed;
    }

    uint256 public constant CREDIT_SUPPLY = 5_000;
    /// @dev Upper bound per tx to stay within block gas limits when minting Credits.
    uint256 public constant DEFAULT_CLAIM_BATCH = 200;
    uint256 public constant LP_TOKEN_AMOUNT = 50_000_000 ether;

    CreditManager public immutable credits;
    IFluxToken public immutable flux;
    ILiquidityMigrator public immutable liquidityMigrator;
    LiquidityVault public immutable liquidityVault;

    AuctionState public state;
    uint64 public startTime;
    uint64 public endTime;
    uint64 public lastCheckpointTime;
    uint128 public clearingPrice;
    uint256 public nextCreditId = 1;
    uint256 public totalBudget;
    uint256 public totalEthForLp;
    uint256 public totalCreditsAllocated;
    uint256 public creditsReleasedWad;
    bytes32 public genesisPositionId;

    address[] private _bidders;
    mapping(address => Bid) public bids;
    mapping(address => uint256) private _bidderIndex;

    error InvalidState();
    error InvalidSchedule();
    error InvalidBid();
    error NothingToClaim();
    error TransferFailed();
    error LiquidityBootstrapFailed();
    error AuctionUndersubscribed();
    error BidHasAllocations();
    error InvalidBatchSize();

    event AuctionCreated(uint64 startTime, uint64 endTime);
    event BidPlaced(address indexed bidder, uint256 budget, uint256 maxPrice);
    event BidUpdated(address indexed bidder, uint256 budget, uint256 maxPrice);
    event BidCancelled(address indexed bidder, uint256 refund);
    event Checkpointed(uint256 creditsReleased, uint256 totalAllocated, uint256 clearingPrice);
    event AuctionFinalized(uint256 clearingPrice, uint256 totalBudget, uint256 ethForLp);
    event CreditClaimed(address indexed bidder, uint256 amount, uint256 refund);
    event LiquidityInitialized(
        bytes32 indexed positionId, address indexed receiver, uint256 ethAmount, uint256 fluxAmount
    );

    constructor(
        address admin,
        CreditManager credits_,
        IFluxToken flux_,
        ILiquidityMigrator liquidityMigrator_,
        LiquidityVault liquidityVault_
    ) {
        credits = credits_;
        flux = flux_;
        liquidityMigrator = liquidityMigrator_;
        liquidityVault = liquidityVault_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function bidderCount() external view returns (uint256) {
        return _bidders.length;
    }

    function bidderAt(uint256 index) external view returns (address) {
        return _bidders[index];
    }

    function createAuction(uint64 start, uint64 end) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (state != AuctionState.Pending) revert InvalidState();
        if (start < block.timestamp || end <= start) revert InvalidSchedule();
        startTime = start;
        endTime = end;
        lastCheckpointTime = start;
        state = AuctionState.Active;
        emit AuctionCreated(start, end);
    }

    function bid(uint128 maxPrice) external payable nonReentrant {
        if (
            state != AuctionState.Active || block.timestamp < startTime
                || block.timestamp >= endTime
        ) {
            revert InvalidState();
        }
        if (msg.value == 0 || maxPrice == 0) revert InvalidBid();

        _checkpoint();

        Bid storage userBid = bids[msg.sender];
        if (userBid.budget == 0) {
            _bidderIndex[msg.sender] = _bidders.length + 1;
            _bidders.push(msg.sender);
            userBid.maxPrice = maxPrice;
            userBid.budget = uint128(msg.value);
            emit BidPlaced(msg.sender, msg.value, maxPrice);
        } else {
            if (maxPrice < userBid.maxPrice) revert InvalidBid();
            userBid.budget += uint128(msg.value);
            userBid.maxPrice = maxPrice;
            emit BidUpdated(msg.sender, userBid.budget, maxPrice);
        }
        totalBudget += msg.value;
    }

    function cancelBid() external nonReentrant {
        if (state != AuctionState.Active || block.timestamp >= endTime) revert InvalidState();
        Bid memory userBid = bids[msg.sender];
        if (userBid.budget == 0) revert InvalidBid();
        if (userBid.allocatedCredits != 0) revert BidHasAllocations();
        delete bids[msg.sender];
        totalBudget -= userBid.budget;
        _send(msg.sender, userBid.budget);
        emit BidCancelled(msg.sender, userBid.budget);
    }

    function checkpoint() external {
        if (state != AuctionState.Active) revert InvalidState();
        _checkpoint();
    }

    function clearingPricePreview() public view returns (uint256) {
        uint256 remaining = CREDIT_SUPPLY - totalCreditsAllocated;
        if (remaining == 0) return clearingPrice;
        CCAAllocator.BidInput[] memory inputs = _remainingBidInputs();
        if (inputs.length == 0) return 0;
        return CCAAllocator.computeClearingPrice(inputs, remaining);
    }

    function finalize() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        if (state != AuctionState.Active || block.timestamp < endTime) revert InvalidState();

        _checkpoint();

        if (totalCreditsAllocated < CREDIT_SUPPLY) {
            _allocateCredits(CREDIT_SUPPLY - totalCreditsAllocated);
        }
        if (totalCreditsAllocated < CREDIT_SUPPLY) revert AuctionUndersubscribed();

        totalEthForLp = 0;
        for (uint256 i; i < _bidders.length; ++i) {
            address bidder = _bidders[i];
            Bid storage userBid = bids[bidder];
            userBid.refundAmount = userBid.budget - userBid.spent;
            totalEthForLp += userBid.spent;
        }

        state = AuctionState.Finished;
        _bootstrapLiquidity();
        emit AuctionFinalized(clearingPrice, totalBudget, totalEthForLp);
    }

    function claimCredit() external returns (uint256 amount) {
        return claimCreditBatch(DEFAULT_CLAIM_BATCH);
    }

    function claimCreditBatch(uint256 maxCredits) public nonReentrant returns (uint256 amount) {
        if (maxCredits == 0) revert InvalidBatchSize();
        if (state != AuctionState.Finished) revert InvalidState();
        Bid storage userBid = bids[msg.sender];
        if (userBid.claimed || userBid.budget == 0) revert NothingToClaim();

        uint256 remaining = userBid.allocatedCredits - userBid.creditsClaimed;
        if (remaining > 0) {
            amount = remaining > maxCredits ? maxCredits : remaining;
            uint256 firstAssetId = nextCreditId;
            nextCreditId += amount;
            credits.issueBatch(msg.sender, firstAssetId, amount);
            userBid.creditsClaimed += amount;
        }

        uint256 refund;
        if (userBid.creditsClaimed >= userBid.allocatedCredits) {
            refund = userBid.refundAmount;
            if (refund != 0) {
                userBid.refundAmount = 0;
                _send(msg.sender, refund);
            }
            userBid.claimed = true;
        }

        emit CreditClaimed(msg.sender, amount, refund);
    }

    function _checkpoint() internal {
        if (state != AuctionState.Active) return;

        uint64 now_ = uint64(block.timestamp);
        if (now_ <= lastCheckpointTime) return;

        uint64 capped = now_ > endTime ? endTime : now_;
        if (capped <= lastCheckpointTime) return;

        uint256 elapsed = capped - lastCheckpointTime;
        uint256 duration = endTime - startTime;
        creditsReleasedWad += CREDIT_SUPPLY * WAD * elapsed / duration;
        uint256 maxReleased = CREDIT_SUPPLY * WAD;
        if (creditsReleasedWad > maxReleased) creditsReleasedWad = maxReleased;
        lastCheckpointTime = capped;

        uint256 targetAllocated = creditsReleasedWad / WAD;
        if (targetAllocated > totalCreditsAllocated) {
            _allocateCredits(targetAllocated - totalCreditsAllocated);
        }

        emit Checkpointed(creditsReleasedWad / WAD, totalCreditsAllocated, clearingPrice);
    }

    function _allocateCredits(uint256 delta) internal {
        if (delta == 0) return;

        CCAAllocator.BidInput[] memory inputs = _remainingBidInputs();
        if (inputs.length == 0) return;

        uint256 price = CCAAllocator.computeClearingPrice(inputs, delta);
        CCAAllocator.BidOutput[] memory outputs = CCAAllocator.allocate(inputs, delta, price);

        clearingPrice = uint128(price);
        for (uint256 i; i < _bidders.length; ++i) {
            address bidder = _bidders[i];
            Bid storage userBid = bids[bidder];
            if (outputs[i].credits == 0) continue;
            userBid.allocatedCredits += outputs[i].credits;
            userBid.spent += outputs[i].cost;
            totalCreditsAllocated += outputs[i].credits;
        }
    }

    function _remainingBidInputs() internal view returns (CCAAllocator.BidInput[] memory inputs) {
        inputs = new CCAAllocator.BidInput[](_bidders.length);
        for (uint256 i; i < _bidders.length; ++i) {
            Bid memory userBid = bids[_bidders[i]];
            uint256 remainingBudget = userBid.budget - userBid.spent;
            inputs[i] = CCAAllocator.BidInput(remainingBudget, userBid.maxPrice);
        }
    }

    function _bootstrapLiquidity() internal {
        flux.mint(address(this), LP_TOKEN_AMOUNT);
        IERC20(address(flux)).forceApprove(address(liquidityMigrator), LP_TOKEN_AMOUNT);
        genesisPositionId = liquidityMigrator.bootstrapPool{ value: totalEthForLp }(
            address(flux), LP_TOKEN_AMOUNT, 0, ""
        );
        if (genesisPositionId == bytes32(0)) revert LiquidityBootstrapFailed();
        liquidityVault.registerGenesisPosition(address(uint160(uint256(genesisPositionId))));
        emit LiquidityInitialized(
            genesisPositionId, address(liquidityVault), totalEthForLp, LP_TOKEN_AMOUNT
        );
    }

    function _send(address to, uint256 amount) internal {
        (bool ok,) = to.call{ value: amount }("");
        if (!ok) revert TransferFailed();
    }
}
