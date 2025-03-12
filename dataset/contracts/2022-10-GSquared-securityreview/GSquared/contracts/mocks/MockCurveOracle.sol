// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

import "../oracles/RelationModule.sol";
import "../interfaces/ICurve3Pool.sol";

contract MockCurveOracle is Relation {
    uint256 public price = 1e18;

    constructor() {}

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function getVirtualPrice() public view returns (uint256) {
        return price;
    }

    function getSwappingPrice(
        uint256 _i,
        uint256 _j,
        uint256 _amount,
        bool _deposit
    ) external pure override returns (uint256) {
        return _amount;
    }

    function getSinglePrice(
        uint256 _i,
        uint256 _amount,
        bool _deposit
    ) external view override returns (uint256) {
        return (_amount * getVirtualPrice()) / DEFAULT_FACTOR;
    }

    function getTotalValue(uint256[] memory _amounts)
        external
        view
        override
        returns (uint256)
    {
        uint256 total;
        uint256 vprice = getVirtualPrice();
        for (uint256 i; i < _amounts.length; ++i) {
            total += (_amounts[i] * vprice) / DEFAULT_FACTOR;
        }
        return total;
    }

    function getTokenAmount(
        uint256 _i,
        uint256 _amount,
        bool _deposit
    ) external view override returns (uint256) {
        return (_amount * DEFAULT_FACTOR) / getVirtualPrice();
    }
}
