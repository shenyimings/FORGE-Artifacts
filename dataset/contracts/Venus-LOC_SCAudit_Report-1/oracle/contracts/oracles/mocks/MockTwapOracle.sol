// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../interfaces/VBep20Interface.sol";

contract MockTwapOracle is OwnableUpgradeable {
    mapping(address => uint256) public assetPrices;

    /// @notice vBNB address
    address public vBNB;

    //set price in 6 decimal precision
    constructor() {}

    function initialize(address vBNB_) public initializer {
        __Ownable_init();
        require(vBNB_ != address(0), "vBNB can't be zero address");
        vBNB = vBNB_;
    }

    function setPrice(address asset, uint256 price) external {
        assetPrices[asset] = price;
    }

    //https://compound.finance/docs/prices
    function getUnderlyingPrice(address vToken) public view returns (uint256) {
        return assetPrices[vToken];
    }
}
