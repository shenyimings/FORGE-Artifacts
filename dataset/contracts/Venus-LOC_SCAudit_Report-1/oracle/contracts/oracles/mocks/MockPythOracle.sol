// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../PythOracle.sol";
import "../../interfaces/VBep20Interface.sol";

contract MockPythOracle is OwnableUpgradeable {
    mapping(address => uint256) public assetPrices;

    /// @notice the actual pyth oracle address fetch & store the prices
    IPyth public underlyingPythOracle;

    //set price in 6 decimal precision
    constructor() {}

    function initialize(address underlyingPythOracle_) public initializer {
        __Ownable_init();
        require(underlyingPythOracle_ != address(0), "pyth oracle cannot be zero address");
        underlyingPythOracle = IPyth(underlyingPythOracle_);
    }

    function setPrice(address asset, uint256 price) external {
        assetPrices[asset] = price;
    }

    //https://compound.finance/docs/prices
    function getUnderlyingPrice(address vToken) public view returns (uint256) {
        address token = VBep20Interface(vToken).underlying();
        return assetPrices[token];
    }
}
