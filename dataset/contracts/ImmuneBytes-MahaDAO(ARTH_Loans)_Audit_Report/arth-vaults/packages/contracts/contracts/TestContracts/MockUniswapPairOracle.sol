// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import {SafeMath} from "../Dependencies/SafeMath.sol";
import {IUniswapPairOracle} from "../Dependencies/IUniswapPairOracle.sol";

contract MockUniswapOracle is IUniswapPairOracle {
    using SafeMath for uint256;

    uint256 public price = 1e18;

    function setPrice(uint256 _price) public {
        price = _price;
    }

    function getPrice() external view returns (uint256) {
        return price;
    }

    function canUpdate() external view override returns(bool) {
        return true;
    }

    function update() external override {
        emit Updated(price, price);
    }

    function consult(address, uint256 amountIn)
        external
        view
        override
        returns (uint256)
    {
        return price.mul(amountIn).div(1e18);
    }

    event Updated(uint256 price0CumulativeLast, uint256 price1CumulativeLast);
}