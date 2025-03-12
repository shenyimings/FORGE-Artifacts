// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../interfaces/AggregatorV3Interface.sol";
import "../../interfaces/IOracle.sol";

/**
 * Fetches price from Chainlink price feed
 *
 * Supports multiplying two prices together, such as WBTC/ETH price and ETH/USDC
 * price to get WBTC/USDC price.
 *
 * Decimals is set to 18
 */
contract ChainlinkOracle is IOracle {
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 public constant SCALE = 1e18;

    address public priceFeed1;
    address public priceFeed2;

    constructor(address _priceFeed1, address _priceFeed2) public {
        priceFeed1 = _priceFeed1;
        priceFeed2 = _priceFeed2;
    }

    function getPrice() external override view returns (uint256 price) {
        price = SCALE;
        if (priceFeed1 != address(0)) {
            price = price.mul(getPriceFromFeed(priceFeed1)).div(SCALE);
        }
        if (priceFeed2 != address(0)) {
            price = price.mul(getPriceFromFeed(priceFeed2)).div(SCALE);
        }
    }

    function getPriceFromFeed(address priceFeed) public view returns (uint256) {
        AggregatorV3Interface aggregator = AggregatorV3Interface(priceFeed);
        (, int256 price, , uint256 timestamp, ) = aggregator.latestRoundData();
        require(timestamp > 0, "Round not complete");
        require(price > 0, "Price is not > 0");

        uint256 decimals = uint256(aggregator.decimals());
        return uint256(price).mul(SCALE).div(10**decimals);
    }
}
