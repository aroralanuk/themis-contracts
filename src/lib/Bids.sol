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
        ) internal {
        self.array = new uint32[](capacity);
    }

    function insert(
        Heap storage self,
        uint32 domain,
        address bidderAddress,
        uint128 bidAmount,
        uint64 bidTimestamp
    ) internal returns (uint32,uint32) {
        if (self.totalBids >= self.array.length
            && bidAmount < self.index[self.array[0]].bidAmount) {

            return (0,0);
        } else if (self.totalBids >= self.array.length) {
            uint32 discarded = self.array[0];
            self.totalBids++;
            self.array[0] = self.totalBids;
            self.index[self.totalBids] = Node(
                domain,
                bidderAddress,
                bidAmount,
                bidTimestamp
            );
            heapify(self, 0);
            return (self.totalBids, discarded);
        } else {
            self.totalBids++;
            self.array[self.totalBids] = self.totalBids;
            self.index[self.totalBids] = Node(
                domain,
                bidderAddress,
                bidAmount,
                bidTimestamp
            );

            uint32 i = self.totalBids - 1;
            while (i > 0 && getBid(self, i).bidAmount
                                < getBid(self, (i - 1) / 2).bidAmount) {
                swap(self, i, (i - 1) / 2);
                i = (i - 1) / 2;
            }
            return (self.totalBids, 0);
        }


    }

    function heapify(
        Heap storage self,
        uint32 i
    ) internal {
        uint32 l = 2 * i + 1;
        uint32 r = 2 * i + 2;
        uint32 smallest = i;
        if (
            l < self.totalBids &&
            getBid(self, l).bidAmount < getBid(self, smallest).bidAmount
        ) {
            smallest = l;
        }
        if (
            r < self.totalBids &&
            getBid(self, r).bidAmount < getBid(self, smallest).bidAmount
        ) {
            smallest = r;
        }

        if (smallest != i) {
            swap(self, i, smallest);
            heapify(self, smallest);
        }
    }

    function getBid(
        Heap storage self,
        uint32 bidIndex
    ) internal view returns (Node memory) {
        return self.index[self.array[bidIndex]];
    }

    function getAllBids(
        Heap storage self
    ) internal view returns (Node[] memory) {
        Node[] memory bids = new Node[](self.totalBids);
        for (uint32 i = 0; i < self.totalBids; i++) {
            bids[i] = self.index[self.array[i]];
        }
        return bids;
    }

    function contains(
        Heap storage self,
        uint32 domain,
        address bidderAddress
    ) internal view returns (bool) {
        return getBidPosition(self, domain, bidderAddress) < self.totalBids;
    }

    function getBidPosition(
        Heap storage self,
        uint32 domain,
        address bidderAddress
    ) internal view returns (uint32) {
        for (uint32 i = 0; i < self.totalBids; i++) {
            if (self.index[self.array[i]].domain == domain
                && self.index[self.array[i]].bidderAddress == bidderAddress) {
                return i;
            }
        }
        return self.totalBids;
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
