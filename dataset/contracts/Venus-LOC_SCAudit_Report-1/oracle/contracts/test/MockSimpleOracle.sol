// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/OracleInterface.sol";

contract MockSimpleOracle is OracleInterface {
    mapping(address => uint256) public prices;

    constructor() {
        //
    }

    function setPrice(address vToken, uint256 price) public {
        prices[vToken] = price;
    }

    function getUnderlyingPrice(address vToken) external view returns (uint256) {
        return prices[vToken];
    }
}

contract MockBoundValidator is BoundValidatorInterface {
    mapping(address => bool) public validateResults;
    bool public twapUpdated;

    constructor() {
        //
    }

    function setValidateResult(address vToken, bool pass) public {
        validateResults[vToken] = pass;
    }

    function validatePriceWithAnchorPrice(
        address vToken,
        uint256 reporterPrice,
        uint256 anchorPrice
    ) external view returns (bool) {
        return validateResults[vToken];
    }
}
