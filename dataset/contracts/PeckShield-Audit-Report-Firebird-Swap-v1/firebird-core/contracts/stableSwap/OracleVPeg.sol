// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/ISwap.sol";
import "../libraries/FixedPoint.sol";
import "../libraries/UQ112x112.sol";

// fixed window oracle that recomputes the average price for the entire epochPeriod once every epochPeriod
// note that the price average is only guaranteed to be over at least 1 epochPeriod, but may be over a longer epochPeriod
// @dev This version 2 supports querying twap with shorted period (ie 2hrs for BSDB reference price)
contract OracleVPeg {
    using FixedPoint for *;
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    /* ========= CONSTANT VARIABLES ======== */

    uint256 public oneAmountTokenMain = 10**18;

    /* ========== STATE VARIABLES ========== */

    // governance
    address public operator;

    // epoch
    uint256 public lastEpochTime;
    uint256 public epoch; // for display only
    uint256 public epochPeriod;
    uint256 public maxEpochPeriod = 1 days;

    // 2-hours update
    uint256 public lastUpdateHour;
    uint256 public updatePeriod;

    mapping(uint256 => uint112) public epochPrice;

    // BPool
    address public mainToken;
    uint256 public mainTokenDecimal;
    uint8 public mainTokenIndex;
    uint8 public sideTokenIndex;
    uint256 public sideTokenDecimal;
    ISwap public pool;

    // Pool price for update in cumulative epochPeriod
    uint32 public blockTimestampCumulativeLast;
    uint public priceCumulative;

    // oracle
    uint32 public blockTimestampLast;
    uint256 public priceCumulativeLast;
    FixedPoint.uq112x112 public priceAverage;

    bool private _initialized = false;

    event Updated(uint256 priceCumulativeLast);

    /* ========== CONSTRUCTOR ========== */

    function initialize (
        address _pool,
        address _mainToken,
        address _sideToken,
        uint256 _epoch,
        uint256 _epochPeriod,
        uint256 _lastEpochTime,
        uint256 _updatePeriod,
        uint256 _lastUpdateHour
    ) public {
        require(_initialized == false, "OracleVPeg: Initialize must be false.");

        mainToken = _mainToken;
        mainTokenDecimal = ERC20(_mainToken).decimals();
        {
            pool = ISwap(_pool);

            uint8 _mainTokenIndex = pool.getTokenIndex(_mainToken);
            uint8 _sideTokenIndex = pool.getTokenIndex(_sideToken);
            require(pool.getTokenBalance(_mainTokenIndex) != 0 && pool.getTokenBalance(_sideTokenIndex) != 0, "OracleVPeg: NO_RESERVES"); // ensure that there's liquidity in the pool

            mainTokenIndex = _mainTokenIndex;
            sideTokenIndex = _sideTokenIndex;
            sideTokenDecimal = ERC20(_sideToken).decimals();
        }

        epoch = _epoch;
        epochPeriod = _epochPeriod;
        lastEpochTime = _lastEpochTime;
        lastUpdateHour = _lastUpdateHour;
        updatePeriod = _updatePeriod;

        operator = msg.sender;
        _initialized = true;
    }

    /* ========== GOVERNANCE ========== */

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function setEpoch(uint256 _epoch) external onlyOperator {
        epoch = _epoch;
    }

    function setEpochPeriod(uint256 _epochPeriod) external onlyOperator {
        require(_epochPeriod >= 1 hours && _epochPeriod <= 48 hours, '_epochPeriod out of range');
        epochPeriod = _epochPeriod;
    }

    function setLastUpdateHour(uint256 _lastUpdateHour) external onlyOperator {
        lastUpdateHour = _lastUpdateHour;
    }

    function setUpdatePeriod(uint256 _updatePeriod) external onlyOperator {
        require(_updatePeriod >= 1 hours && _updatePeriod <= epochPeriod, '_updatePeriod out of range');
        updatePeriod = _updatePeriod;
    }

    function setOneAmountTokenMain(uint256 _oneAmountTokenMain) external onlyOperator {
        oneAmountTokenMain = _oneAmountTokenMain;
    }

    function setMaxEpochPeriod(uint256 _maxEpochPeriod) external onlyOperator {
        require(_maxEpochPeriod <= 48 hours, '_maxEpochPeriod is not valid');
        maxEpochPeriod = _maxEpochPeriod;
    }

    function setPool(address _pool, address _sideToken) public onlyOperator {
        pool = ISwap(_pool);

        uint8 _mainTokenIndex = pool.getTokenIndex(mainToken);
        uint8 _sideTokenIndex = pool.getTokenIndex(_sideToken);

        require(pool.getTokenBalance(_mainTokenIndex) != 0 && pool.getTokenBalance(_sideTokenIndex) != 0, "OracleVPeg: NO_RESERVES"); // ensure that there's liquidity in the pool

        mainTokenIndex = _mainTokenIndex;
        sideTokenIndex = _sideTokenIndex;
        sideTokenDecimal = ERC20(_sideToken).decimals();
    }

    /* =================== Modifier =================== */

    modifier checkEpoch {
        uint256 _nextEpochPoint = nextEpochPoint();
        require(block.timestamp >= _nextEpochPoint, "OracleVPeg: not opened yet");

        _;

        for (;;) {
            lastEpochTime = _nextEpochPoint;
            ++epoch;
            _nextEpochPoint = nextEpochPoint();
            if (block.timestamp < _nextEpochPoint) break;
        }
    }

    modifier onlyOperator() {
        require(operator == msg.sender, "OracleVPeg: caller is not the operator");
        _;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function nextEpochPoint() public view returns (uint256) {
        return lastEpochTime.add(epochPeriod);
    }

    function nextUpdateHour() public view returns (uint256) {
        return lastUpdateHour.add(updatePeriod);
    }

    /* ========== MUTABLE FUNCTIONS ========== */
    // update reserves and, on the first call per block, price accumulators
    function updateCumulative() public {
        uint256 _updatePeriod = updatePeriod;
        uint256 _nextUpdateHour = lastUpdateHour.add(_updatePeriod);
        if (block.timestamp >= _nextUpdateHour) {
            uint tokenMainPrice;

            {
                uint _decimalFactor = 10 ** (mainTokenDecimal.sub(sideTokenDecimal));
                tokenMainPrice = pool.calculateSwap(mainTokenIndex, sideTokenIndex, oneAmountTokenMain).mul(_decimalFactor);
                require(tokenMainPrice != 0, "!price");
                require(tokenMainPrice <= uint112(-1), "OracleVPeg: overflow");
            }

            uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
            uint32 timeElapsed = blockTimestamp - blockTimestampCumulativeLast; // overflow is desired

            if (timeElapsed > 0) {
                // * never overflows, and + overflow is desired
                priceCumulative += uint(UQ112x112.encode(uint112(tokenMainPrice)).uqdiv(uint112(oneAmountTokenMain))) * timeElapsed;

                blockTimestampCumulativeLast = blockTimestamp;
            }

            for (;;) {
                if (block.timestamp < _nextUpdateHour.add(_updatePeriod)) {
                    lastUpdateHour = _nextUpdateHour;
                    break;
                } else {
                    _nextUpdateHour = _nextUpdateHour.add(_updatePeriod);
                }
            }
        }
    }

    /** @dev Updates 1-day EMA price.  */
    function update() external checkEpoch {
        updateCumulative();

        uint32 timeElapsed = blockTimestampCumulativeLast - blockTimestampLast; // overflow is desired

        if (timeElapsed == 0) {
            if (epochPrice[epoch] == 0) {
                epochPrice[epoch] = priceAverage.decode();
            }

            // prevent divided by zero
            return;
        }

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        priceAverage = FixedPoint.uq112x112(uint224((priceCumulative - priceCumulativeLast) / timeElapsed));

        priceCumulativeLast = priceCumulative;
        blockTimestampLast = blockTimestampCumulativeLast;

        epochPrice[epoch] = priceAverage.decode();
        emit Updated(priceCumulative);
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address token, uint256 amountIn) external view returns (uint144 amountOut) {
        require(token == mainToken, "OracleVPeg: INVALID_TOKEN");
        require(block.timestamp.sub(blockTimestampLast) <= maxEpochPeriod, "OracleVPeg: Price out-of-date");
        amountOut = priceAverage.mul(amountIn).decode144();
    }

    function twap(uint256 _amountIn) external view returns (uint144) {
        uint32 timeElapsed = blockTimestampCumulativeLast - blockTimestampLast;
        return (timeElapsed == 0) ? priceAverage.mul(_amountIn).decode144() : FixedPoint.uq112x112(uint224((priceCumulative - priceCumulativeLast) / timeElapsed)).mul(_amountIn).decode144();
    }

    function governanceRecoverUnsupported(IERC20 _token, uint256 _amount, address _to) external onlyOperator {
        _token.transfer(_to, _amount);
    }
}
