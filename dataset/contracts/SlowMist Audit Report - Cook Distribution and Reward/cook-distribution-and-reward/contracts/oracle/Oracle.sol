pragma solidity ^0.6.2;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../external/UniswapV2OracleLibrary.sol";
import "../external/UniswapV2Library.sol";
import "./IOracle.sol";

// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract Oracle is IOracle, Ownable {
    using FixedPoint for *;

    uint256 public constant PERIOD = 1 seconds;

    IUniswapV2Pair public pair;
    address public override pairAddress;
    address public token0;
    address public token1;
    address private _cookAddress;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public blockTimestampLast;
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;

    uint256 public latestPrice0;
    uint256 public latestPrice1;

    constructor(address _pairAddress, address cookAddress) public {
        require(cookAddress != address(0), "Cook address can not be empty");
        require(
            _pairAddress != address(0),
            "Cook pair address can not be empty"
        );

        pair = IUniswapV2Pair(_pairAddress);
        pairAddress = _pairAddress;
        _cookAddress = cookAddress;
        token0 = IUniswapV2Pair(_pairAddress).token0();
        token1 = IUniswapV2Pair(_pairAddress).token1();
        price0CumulativeLast = IUniswapV2Pair(_pairAddress)
            .price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        price1CumulativeLast = IUniswapV2Pair(_pairAddress)
            .price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = IUniswapV2Pair(_pairAddress)
            .getReserves();
        require(reserve0 != 0 && reserve1 != 0, "Oracle: NO_RESERVES"); // ensure that there's liquidity in the pair
    }

    function update() external override returns (uint256 latestP) {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        // ensure that at least one full period has passed since the last update
        require(timeElapsed >= PERIOD, "Oracle: PERIOD_NOT_ELAPSED");

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        price0Average = FixedPoint.uq112x112(
            uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
        );
        price1Average = FixedPoint.uq112x112(
            uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
        );

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
        latestPrice0 = price0Average.mul(10**18).decode144();
        latestPrice1 = price1Average.mul(10**18).decode144();

        if (pair.token0() == _cookAddress) {
            return latestPrice0;
        } else {
            return latestPrice1;
        }
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            require(token == token1, "Oracle: INVALID_TOKEN");
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }
}
