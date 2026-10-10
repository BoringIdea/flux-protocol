// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @dev Pure CCA allocation helpers shared by GenesisAuction and tests.
library CCAAllocator {
    struct BidInput {
        uint256 budget;
        uint256 maxPrice;
    }

    struct BidOutput {
        uint256 credits;
        uint256 cost;
        uint256 refund;
    }

    error InvalidClearingPrice();
    error NoEligibleBids();

    function computeClearingPrice(BidInput[] memory bids, uint256 creditSupply)
        internal
        pure
        returns (uint256 clearingPrice)
    {
        uint256[] memory prices = _uniqueMaxPrices(bids);
        if (prices.length == 0) revert NoEligibleBids();

        clearingPrice = prices[0];
        for (uint256 i; i < prices.length; ++i) {
            if (_demandAtPrice(bids, prices[i]) >= creditSupply) {
                clearingPrice = prices[i];
            }
        }
        if (_demandAtPrice(bids, clearingPrice) < creditSupply) revert NoEligibleBids();
    }

    function allocate(BidInput[] memory bids, uint256 creditSupply, uint256 clearingPrice)
        internal
        pure
        returns (BidOutput[] memory outputs)
    {
        if (clearingPrice == 0) revert InvalidClearingPrice();
        outputs = new BidOutput[](bids.length);

        uint256 totalRaw;
        for (uint256 i; i < bids.length; ++i) {
            if (bids[i].maxPrice < clearingPrice || bids[i].budget == 0) continue;
            uint256 raw = bids[i].budget / clearingPrice;
            outputs[i].credits = raw;
            totalRaw += raw;
        }
        if (totalRaw == 0) revert NoEligibleBids();

        if (totalRaw > creditSupply) {
            uint256 assigned;
            for (uint256 i; i < bids.length; ++i) {
                if (outputs[i].credits == 0) continue;
                outputs[i].credits = outputs[i].credits * creditSupply / totalRaw;
                assigned += outputs[i].credits;
            }
            uint256 remaining = creditSupply - assigned;
            for (uint256 i; remaining != 0; ++i) {
                if (i >= bids.length) break;
                if (bids[i].maxPrice < clearingPrice || bids[i].budget == 0) continue;
                if (bids[i].budget / clearingPrice == 0) continue;
                ++outputs[i].credits;
                --remaining;
            }
        }

        for (uint256 i; i < bids.length; ++i) {
            if (outputs[i].credits == 0) {
                outputs[i].refund = bids[i].budget;
                continue;
            }
            outputs[i].cost = outputs[i].credits * clearingPrice;
            outputs[i].refund = bids[i].budget - outputs[i].cost;
        }
    }

    function _demandAtPrice(BidInput[] memory bids, uint256 price)
        private
        pure
        returns (uint256 demand)
    {
        for (uint256 i; i < bids.length; ++i) {
            if (bids[i].maxPrice >= price && bids[i].budget != 0) {
                demand += bids[i].budget / price;
            }
        }
    }

    function _uniqueMaxPrices(BidInput[] memory bids)
        private
        pure
        returns (uint256[] memory prices)
    {
        uint256 count;
        uint256[] memory scratch = new uint256[](bids.length);
        for (uint256 i; i < bids.length; ++i) {
            if (bids[i].budget == 0 || bids[i].maxPrice == 0) continue;
            if (_contains(scratch, count, bids[i].maxPrice)) continue;
            scratch[count++] = bids[i].maxPrice;
        }
        prices = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            prices[i] = scratch[i];
        }
        _sortAscending(prices);
    }

    function _contains(uint256[] memory values, uint256 length, uint256 value)
        private
        pure
        returns (bool)
    {
        for (uint256 i; i < length; ++i) {
            if (values[i] == value) return true;
        }
        return false;
    }

    function _sortAscending(uint256[] memory values) private pure {
        for (uint256 i = 1; i < values.length; ++i) {
            uint256 key = values[i];
            uint256 j = i;
            while (j > 0 && values[j - 1] > key) {
                values[j] = values[j - 1];
                --j;
            }
            values[j] = key;
        }
    }
}
