// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/math/SafeMath.sol';

contract CompoundPriceOracleMock {
    using SafeMath for uint256;

    address public originalOracle;

    bool public constant isPriceOracle = true;
    uint256 public constant MANTISSA = 1e18;

    mapping(address => uint256) public cTokenPrices;

    function setOriginalOracle(address addr) external {
        originalOracle = addr;
    }

    function getPriceUpdate(address cToken) public view returns (uint256) {
        return cTokenPrices[cToken] == 0 ? MANTISSA : cTokenPrices[cToken];
    }

    function setPriceUpdate(address cToken, uint256 priceUpdate) external {
        cTokenPrices[cToken] = priceUpdate;
    }

    function getUnderlyingPrice(address cToken) external view returns (uint256) {
        return
            CompoundPriceOracleMock(originalOracle).getUnderlyingPrice(cToken).mul(getPriceUpdate(cToken)).div(
                MANTISSA
            );
    }
}
