// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "../lib/Babylonian.sol";
import "../lib/FixedPoint.sol";
import "../lib/UniswapV2OracleLibrary.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IBasisAsset.sol";
import "../interfaces/IOracle.sol";

// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract OracleAssetToUSDC is IOracle, OwnableUpgradeSafe {
    using FixedPoint for *;
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    // uniswap
    address public token0;
    address public token1;
    IUniswapV2Pair public pair;

    // oracle
    uint32 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;
    address public asset;
    address public usdc;

    uint256 public minAssetPrice;
    uint256 public amountIn; // usually =1e18 (for USDT = 1e6)

    uint256 public lastUpdated;
    uint256 public epochLength;
    uint256 public lastEpochConsult;

    /* =================== Events =================== */

    event MinAssetPriceUpdated(uint256 value);
    event Updated(uint256 price0CumulativeLast, uint256 price1CumulativeLast);

    /* =================== Modifier =================== */

    /* ========== GOVERNANCE ========== */

    function initialize(
        IUniswapV2Pair _pair,
        address _asset,
        address _usdc,
        uint256 _minAssetPrice,
        uint256 _epochLength
    ) external initializer {
        OwnableUpgradeSafe.__Ownable_init();

        pair = _pair;
        token0 = pair.token0();
        token1 = pair.token1();
        price0CumulativeLast = pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        price1CumulativeLast = pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, "OracleToUSDC: NO_RESERVES"); // ensure that there's liquidity in the pair

        asset = _asset;
        usdc = _usdc;

        minAssetPrice = _minAssetPrice;
        amountIn = 10 ** (uint256(uint256(IBasisAsset(_asset).decimals())).add(6).sub(uint256(IBasisAsset(_usdc).decimals())));

        epochLength = _epochLength;
    }

    function setMinPrice(uint256 _minAssetPrice) external onlyOwner {
        minAssetPrice = _minAssetPrice;
        emit MinAssetPriceUpdated(_minAssetPrice);
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    /** @dev Updates 1-hour EMA price from Uniswap.  */
    function update() external override {
        if (block.timestamp >= nextEpochPoint()) {
            (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
            uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

            if (timeElapsed == 0) {
                // prevent divided by zero
                return;
            }

            lastUpdated = block.timestamp;

            // overflow is desired, casting never truncates
            // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
            price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed));
            price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed));

            price0CumulativeLast = price0Cumulative;
            price1CumulativeLast = price1Cumulative;
            blockTimestampLast = blockTimestamp;

            lastEpochConsult = epochConsult();
            emit Updated(price0Cumulative, price1Cumulative);
        }
    }

    /* ========== VIEW FUNCTIONS ========== */

    function nextEpochPoint() public override view returns (uint256) {
        return lastUpdated.add(epochLength);
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function epochConsult() public override view returns (uint256 _amountOut) {
        if (asset == token0) {
            _amountOut = uint256(price0Average.mul(amountIn).decode144());
        } else {
            _amountOut = uint256(price1Average.mul(amountIn).decode144());
        }
    }

    function consult() external view override returns (uint256 _price) {
        _price = consultTrue();
        if (_price < minAssetPrice) {
            _price = minAssetPrice;
        }
    }

    function consultTrue() public view override returns (uint256 _amountOut) {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (asset == token0) {
            _amountOut = uint256(FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)).mul(amountIn).decode144());
        } else {
            _amountOut = uint256(FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)).mul(amountIn).decode144());
        }
    }

    /* ========== EMERGENCY ========== */

    function rescueStuckErc20(IERC20 _token) external onlyOwner {
        _token.transfer(owner(), _token.balanceOf(address(this)));
    }
}
