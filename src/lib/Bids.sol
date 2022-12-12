// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

library Bids {
    struct Node {
        uint32 domain;
        address bidderAddress;
        uint128 bidAmount;
        uint64 bidTimestamp;
    }

    struct Heap {
        uint32[] array;
        mapping(uint32 => Node) index; // 1-indexed
        uint32 totalBids;
    }

    error BidTooLow();

    function initialize(
        Heap storage self,
        uint32 capacity
        ) external {
        self.array = new uint32[](capacity);
    }

    function insert(
        Heap storage self,
        uint32 domain_,
        address bidderAddress_,
        uint128 bidAmount_,
        uint64 bidTimestamp_
    ) internal {

        if (self.totalBids == self.array.length
            && bidAmount_ > self.index[self.array[0]].bidAmount) {
            revert BidTooLow();
        } else if (self.totalBids == self.array.length) {
            return;
        } else {
            self.array[self.totalBids] = self.totalBids + 1;
            self.index[self.totalBids + 1] = Node(
                domain_,
                bidderAddress_,
                bidAmount_,
                bidTimestamp_
            );
            self.totalBids++;
        }

        uint32 i = self.totalBids - 1;
        while (i > 0 && self.array[i] < self.array[(i - 1) / 2]) {
            swap(self, i, (i - 1) / 2);
            i = (i - 1) / 2;
        }
    }

    function swap(
        Heap storage self,
        uint32 i,
        uint32 j
    ) internal {
        (self.array[i], self.array[j])
            = (self.array[j], self.array[i]);
    }
}