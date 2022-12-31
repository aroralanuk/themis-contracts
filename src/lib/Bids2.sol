// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

library Bids2 {
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

    function init(List storage self, uint32 capacity) external {
        require(capacity > 0, "Bids: Invalid capacity");
        self.capacity = capacity;
    }

    function insert(
        List storage self,
        Element memory element,
        uint32 lesserKey,
        uint32 greaterKey
    ) external returns (Element memory) {
        if (lesserKey == 0 && greaterKey == 0) {
            require(self.totalBids == 0, "Bids: Invalid keys");
            uint32 key = self.totalBids + 1;
            self.elements[key] = element;

            self.head = key;
            self.tail = key;
        } else if (lesserKey == 0){
            Element memory greaterElement = self.elements[greaterKey];
            require(lt(element, greaterElement), "Bids: Invalid greater key");

            require(greaterElement.prevKey == 0, "Bids: Invalid prev key");

            uint32 key = self.totalBids + 1;
            element.nextKey = greaterKey;
            self.elements[key] = element;

            self.elements[greaterKey].prevKey = key;
            self.head = key;
        } else if (greaterKey == 0){
            Element memory lesserElement = self.elements[lesserKey];
            require(lt(lesserElement, element), "Bids: Invalid lesser key");

            require(lesserElement.nextKey == 0, "Bids: Invalid next key");

            uint32 key = self.totalBids + 1;
            element.prevKey = lesserKey;
            self.elements[key] = element;

            self.elements[lesserKey].nextKey = key;
            self.tail = key;
        } else {
            Element memory lesserElement = self.elements[lesserKey];
            require(lt(lesserElement, element), "Bids: Invalid lesser key");

            Element memory greaterElement = self.elements[greaterKey];
            require(lt(element, greaterElement), "Bids: Invalid greater key");

            require(lesserElement.nextKey == greaterKey, "Bids: Invalid next key");

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
        require(self.totalBids > 0, "Bids: Empty list");

        uint32 key = self.head;
        Element memory element = self.elements[key];
        require(element.bidderAddress != address(0), "Bids: Invalid element");

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
