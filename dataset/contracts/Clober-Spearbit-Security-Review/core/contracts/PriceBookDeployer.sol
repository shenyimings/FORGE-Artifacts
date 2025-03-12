// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "./interfaces/CloberPriceBookDeployer.sol";
import "./ArithmeticPriceBook.sol";
import "./GeometricPriceBook.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

contract PriceBookDeployer is CloberPriceBookDeployer {
    address private immutable _factory;

    constructor(address factory_) {
        _factory = factory_;
    }

    function deployArithmeticPriceBook(uint128 a, uint128 d) external returns (address priceBook) {
        if (msg.sender != _factory) {
            revert Errors.CloberError(Errors.ACCESS);
        }
        bytes32 salt = keccak256(abi.encodePacked(a, d));
        priceBook = address(new ArithmeticPriceBook{salt: salt}(a, d));
    }

    function deployGeometricPriceBook(uint128 a, uint128 r) external returns (address priceBook) {
        if (msg.sender != _factory) {
            revert Errors.CloberError(Errors.ACCESS);
        }
        bytes32 salt = keccak256(abi.encodePacked(a, r));
        priceBook = address(new GeometricPriceBook{salt: salt}(a, r));
    }

    function computeArithmeticPriceBookAddress(uint128 a, uint128 d) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(a, d));
        return
            Create2.computeAddress(
                salt,
                keccak256(abi.encodePacked(type(ArithmeticPriceBook).creationCode, abi.encode(a, d)))
            );
    }

    function computeGeometricPriceBookAddress(uint128 a, uint128 r) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(a, r));
        return
            Create2.computeAddress(
                salt,
                keccak256(abi.encodePacked(type(GeometricPriceBook).creationCode, abi.encode(a, r)))
            );
    }
}
