// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IOracle.sol";

/**
 * Fetches TWAP (time-weighted average price) from Uniswap V2 Oracle
 *
 * To calculate the TWAP between time A and time B, call `takeSnapshot` just
 * before time A. Then at time B, `getPrice` will return the TWAP during
 * this window
 *
 * Tokens can optionally be sent to this contract to be claimed by the user
 * who last calls `takeSnapshot` before the window starts
 */
contract UniswapOracle is IOracle {
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 public constant SCALE = 1e18;
    uint256 public constant Q112 = 1 << 112;

    IUniswapV2Pair public pair;
    uint256 public startTime;
    uint256 public baseMultiplier;
    uint256 public quoteMultiplier;
    bool public isInverted;

    // data at the start of the TWAP window
    uint256 public snapshotCumulativePrice;
    uint256 public snapshotTimestamp;
    address public snapshotCaller;

    /**
     * @param _pair                     `UniswapV2Pair` address
     * @param _startTime                Start time of the TWAP window
     * @param _isInverted               If false, this oracle calculates token0/token1 price
     *                                  If true, token1/token0 price
     */
    constructor(
        address _pair,
        uint256 _startTime,
        bool _isInverted
    ) public {
        pair = IUniswapV2Pair(_pair);
        startTime = _startTime;
        isInverted = _isInverted;

        uint256 decimals0 = ERC20(pair.token0()).decimals();
        uint256 decimals1 = ERC20(pair.token1()).decimals();

        // set multipliers. divide by gcd to make overflows less likely
        uint256 min = Math.min(decimals0, decimals1);
        decimals0 = decimals0.sub(min);
        decimals1 = decimals1.sub(min);
        baseMultiplier = 10**(_isInverted ? decimals1 : decimals0);
        quoteMultiplier = 10**(_isInverted ? decimals0 : decimals1);

        // set initial data
        takeSnapshot();
    }

    /**
     * Fetches data from uniswap and updates `snapshotCumulativePrice` and `snapshotTimestamp`.
     *
     * When `getPrice` is called in the future, it will return the TWAP during the * window starting from now
     *
     * This method should be called just before the start of the TWAP window
     */
    function takeSnapshot() public {
        require(block.timestamp <= startTime, "TWAP window already started");
        (, snapshotCumulativePrice) = fetchSpotAndCumulativePrice();
        snapshotTimestamp = block.timestamp;
        snapshotCaller = msg.sender;
    }

    /**
     * Return TWAP since `takeSnapshot` was last called
     */
    function getPrice() external override view returns (uint256) {
        (uint256 newSpotPrice, uint256 newCumulativePrice) = fetchSpotAndCumulativePrice();

        // time since last takeSnapshot
        uint256 elapsed = block.timestamp.sub(snapshotTimestamp);

        // if not time has elapsed, just use the current spot price
        if (elapsed == 0) {
            return newSpotPrice;
        }

        // change in cumulative price since last fetch
        uint256 diff = newCumulativePrice.sub(snapshotCumulativePrice);
        return diff.mul(SCALE).mul(baseMultiplier).div(Q112).div(elapsed).div(SCALE).div(quoteMultiplier);
    }

    /**
     * Helper method called by `takeSnapshot` and `getPrice`. Returns spot price
     * and cumulative price from Uniswap
     */
    function fetchSpotAndCumulativePrice() public view returns (uint256 spotPrice, uint256 cumulativePrice) {
        (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast) = pair.getReserves();

        // check uniswap has liquidity
        require(reserve0 > 0 && reserve1 > 0, "No reserves");

        // cumulative price is returned in uq112x112 fixed point units
        uint256 last = isInverted ? pair.price1CumulativeLast() : pair.price0CumulativeLast();

        // add extra cumulative price since last fetch
        uint256 elapsed = block.timestamp.sub(blockTimestampLast);
        uint256 base = isInverted ? reserve0 : reserve1;
        uint256 quote = isInverted ? reserve1 : reserve0;

        // set spot price in case getPrice is called at the same time
        spotPrice = base.mul(SCALE).mul(baseMultiplier).div(quote).div(quoteMultiplier);

        // multiplication doesn't overflow as max value is 2^112 * 2^32 * 2^112
        uint256 sinceLast = elapsed.mul(Q112).mul(base).div(quote);
        cumulativePrice = last.add(sinceLast);
    }

    /**
     * Send reward tokens to the user who last called `takeSnapshot`
     */
    function claimReward(IERC20 rewardToken) external {
        require(block.timestamp > startTime, "TWAP window has not started yet");
        uint256 balance = rewardToken.balanceOf(address(this));
        rewardToken.safeTransfer(snapshotCaller, balance);
    }
}
