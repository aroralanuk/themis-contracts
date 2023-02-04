// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// import "forge-std/console.sol";

library Bids {
    error EmptyList();
    error InvalidCapacity();
    error InvalidElement();
    error InvalidGreaterKey();
    error InvalidLesserKey();
    error InvalidNextKey();
    error InvalidPreviousKey();
    error NotEmptyList();

    struct Element {
        address bidder;
        bytes32 salt;
        uint128 amount;
        uint64 blockNumber;

        uint32 prevKey;
        uint32 nextKey;
    }

    struct List {
        uint32 head;
        uint32 tail;
        mapping(uint32 => Element) elements; // 1-indexed
        uint32 totalBids;
        uint32 capacity;
    }

    function init(List storage self, uint32 capacity) internal {
        if (capacity == 0) revert InvalidCapacity();
        self.capacity = capacity;
    }

    function insert(
        List storage self,
        Element memory element
    ) internal returns (uint32, uint32) {
        uint32 lesserKey = element.prevKey;
        uint32 greaterKey = element.nextKey;
        uint32 key;
        // list is empty
        if (lesserKey == 0 && greaterKey == 0) {
            if (self.totalBids > 0) revert NotEmptyList();
            key = self.totalBids + 1;
            self.elements[key] = element;

            element.prevKey = 0;
            element.nextKey = 0;

            self.head = key;
            self.tail = key;
        } else if (lesserKey == 0){
            Element memory greaterElement = self.elements[greaterKey];
            if (!lt(element, greaterElement)) revert InvalidGreaterKey();
            if (greaterElement.prevKey != 0) revert InvalidPreviousKey();

            key = self.totalBids + 1;
            element.nextKey = greaterKey;
            element.prevKey = 0;
            self.elements[key] = element;

            self.elements[greaterKey].prevKey = key;
            self.head = key;
        } else if (greaterKey == 0){
            Element memory lesserElement = self.elements[lesserKey];
            if (!lt(lesserElement, element)) revert InvalidLesserKey();
            if (lesserElement.nextKey != 0) revert InvalidNextKey();

            key = self.totalBids + 1;
            element.prevKey = lesserKey;
            element.nextKey = 0;
            self.elements[key] = element;

            self.elements[lesserKey].nextKey = key;
            self.tail = key;
        } else {
            Element memory lesserElement = self.elements[lesserKey];
            Element memory greaterElement = self.elements[greaterKey];

            if (!lt(lesserElement, element)) revert InvalidLesserKey();
            if (!lt(element, greaterElement)) revert InvalidGreaterKey();
            if (lesserElement.nextKey != greaterKey) revert InvalidNextKey();

            key = self.totalBids + 1;
            element.prevKey = lesserKey;
            element.nextKey = greaterKey;
            self.elements[key] = element;

            self.elements[lesserKey].nextKey = key;
            self.elements[greaterKey].prevKey = key;
        }
        self.totalBids += 1;
        if (self.totalBids > self.capacity) {
            return (0, pop(self));
        }
        return (key, 0);
    }

    function pop(List storage self) internal returns (uint32) {
        if (self.totalBids == 0) revert EmptyList();

        uint32 key = self.head;
        Element memory element = self.elements[key];
        if (element.bidder == address(0)) revert InvalidElement();

        if (self.totalBids == 1) {
            self.head = 0;
            self.tail = 0;
        } else {
            self.head = element.nextKey;
            self.elements[element.nextKey].prevKey = 0;
        }

        self.totalBids -= 1;
        return key;
    }

    function getAllBids(List storage self) internal view returns (Element[] memory) {
        Element[] memory elements = new Element[](self.totalBids);
        uint32 key = self.tail;
        for (uint32 i = 0; i < self.totalBids; i++) {
            elements[i] = self.elements[key];
            key = self.elements[key].prevKey;
        }
        return elements;
    }

    function getBid(List storage self, uint32 key) internal view returns (Element memory) {
        return self.elements[key];
    }

    function lt(
        Element memory element1,
        Element memory element2
    ) internal pure returns (bool) {
        return element1.amount < element2.amount ||
        (element1.amount == element2.amount &&
            element1.blockNumber >= element2.blockNumber);
    }
}
