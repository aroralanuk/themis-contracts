// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

library XAddress {
    struct Info {
        uint32 _domain;
        address _address;
    }

    function init(
        Info storage self,
        bytes32 xaddress
    ) internal {
        self._domain = uint32(uint256(xaddress) >> 160);
        self._address = address(uint160(uint256(xaddress)));
    }

    function init(
        Info storage self,
        uint32 domain_,
        address address_
    ) internal {
        self._domain = domain_;
        self._address = address_;
    }

    function toBytes32(
        Info storage self
    ) internal view returns (bytes32 x) {
        x = bytes32(uint256(self._domain) << 160 | uint160(self._address));
    }

    function getDomain(Info storage self) internal view returns (uint32 domain) {
        domain = uint32(uint256(toBytes32(self)) >> 160);
    }

    function getAddress(Info storage self) internal view returns (address address_) {
        address_ = address(uint160(uint256(toBytes32(self))));
    }
}
