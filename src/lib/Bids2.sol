// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

library Bids2 {
    error EmptyList();
    error InvalidCapacity();
    error InvalidElement();
    error InvalidGreaterKey();
    error InvalidLesserKey();
    error InvalidNextKey();
    error InvalidPreviousKey();
    error NotEmptyList();

    struct Element {
        uint32 domain;
        address bidderAddress;
        uint128 bidAmount;
        uint64 bidTimestamp;

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

    function init(List storage self, uint32 capacity_) external {
        if (capacity_ == 0) revert InvalidCapacity();
        self.capacity = capacity_;
    }

    function insert(
        List storage self,
        Element memory element
    ) external returns (Element memory) {
        uint32 lesserKey = element.prevKey;
        uint32 greaterKey = element.nextKey;

        if (lesserKey == 0 && greaterKey == 0) {
            if (self.totalBids > 0) revert NotEmptyList();
            uint32 key = self.totalBids + 1;
            self.elements[key] = element;

            element.prevKey = 0;
            element.nextKey = 0;

            self.head = key;
            self.tail = key;
        } else if (lesserKey == 0){
            Element memory greaterElement = self.elements[greaterKey];
            if (!lt(element, greaterElement)) revert InvalidGreaterKey();
            if (greaterElement.prevKey != 0) revert InvalidPreviousKey();

            uint32 key = self.totalBids + 1;
            element.nextKey = greaterKey;
            element.prevKey = 0;
            self.elements[key] = element;

            self.elements[greaterKey].prevKey = key;
            self.head = key;
        } else if (greaterKey == 0){
            Element memory lesserElement = self.elements[lesserKey];
            if (!lt(lesserElement, element)) revert InvalidLesserKey();
            if (lesserElement.nextKey != 0) revert InvalidNextKey();

            uint32 key = self.totalBids + 1;
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

            uint32 key = self.totalBids + 1;
            element.prevKey = lesserKey;
            element.nextKey = greaterKey;
            self.elements[key] = element;

            self.elements[lesserKey].nextKey = key;
            self.elements[greaterKey].prevKey = key;
        }
        self.totalBids += 1;
        if (self.totalBids > self.capacity) {
            return pop(self);
        }
        return self.elements[self.head];
    }

    function pop(List storage self) internal returns (Element memory) {
        if (self.totalBids == 0) revert EmptyList();

        uint32 key = self.head;
        Element memory element = self.elements[key];
        if (element.bidderAddress == address(0)) revert InvalidElement();

        if (self.totalBids == 1) {
            self.head = 0;
            self.tail = 0;
        } else {
            self.head = element.nextKey;
            self.elements[element.nextKey].prevKey = 0;
        }

        delete self.elements[key];
        self.totalBids -= 1;

        return element;
    }

    function getAllBids(List storage self) external view returns (Element[] memory) {
        Element[] memory elements = new Element[](self.totalBids);
        uint32 key = self.tail;
        for (uint32 i = 0; i < self.totalBids; i++) {
            elements[i] = self.elements[key];
            key = self.elements[key].prevKey;
        }
        return elements;
    }

    function lt(
        Element memory element1,
        Element memory element2
    ) public pure returns (bool) {
        return element1.bidAmount < element2.bidAmount ||
        (element1.bidAmount == element2.bidAmount &&
            element1.bidTimestamp >= element2.bidTimestamp);
    }
}
