// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {IButtonswapPair} from "./interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapERC20} from "./ButtonswapERC20.sol";
import {Math} from "./libraries/Math.sol";
import {PairMath} from "./libraries/PairMath.sol";
import {UQ112x112} from "./libraries/UQ112x112.sol";
import {IERC20} from "buttonswap-core_@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "buttonswap-core_@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IButtonswapFactory} from "./interfaces/IButtonswapFactory/IButtonswapFactory.sol";

contract ButtonswapPair is IButtonswapPair, ButtonswapERC20 {
    using UQ112x112 for uint224;

    /**
     * @dev A set of liquidity values.
     * @param pool0 The active `token0` liquidity
     * @param pool1 The active `token1` liquidity
     * @param reservoir0 The inactive `token0` liquidity
     * @param reservoir1 The inactive `token1` liquidity
     */
    struct LiquidityBalances {
        uint256 pool0;
        uint256 pool1;
        uint256 reservoir0;
        uint256 reservoir1;
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    /**
     * @dev Denominator for basis points.
     */
    uint256 private constant BPS = 10_000;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint16 public maxVolatilityBps;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint32 public minTimelockDuration;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint32 public maxTimelockDuration;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint16 public maxSwappableReservoirLimitBps;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint32 public swappableReservoirGrowthWindow;

    /**
     * @inheritdoc IButtonswapPair
     */
    address public immutable factory;

    /**
     * @inheritdoc IButtonswapPair
     */
    address public immutable token0;

    /**
     * @inheritdoc IButtonswapPair
     */
    address public immutable token1;

    /**
     * @dev The active `token0` liquidity amount following the last swap.
     * This value is used to determine active liquidity balances after potential rebases until the next future swap.
     */
    uint112 internal pool0Last;

    /**
     * @dev The active `token1` liquidity amount following the last swap.
     * This value is used to determine active liquidity balances after potential rebases until the next future swap.
     */
    uint112 internal pool1Last;

    /**
     * @dev The timestamp of the block that the last swap occurred in.
     */
    uint32 internal blockTimestampLast;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint256 public price0CumulativeLast;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint256 public price1CumulativeLast;

    /**
     * @dev The value of `movingAveragePrice0` at the time of the last swap.
     */
    uint256 internal movingAveragePrice0Last;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint120 public singleSidedTimelockDeadline;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint120 public swappableReservoirLimitReachesMaxDeadline;

    /**
     * @dev Whether or not the pair is isPaused (paused = 1, unPaused = 0).
     * When paused, all operations other than dual-sided burning LP tokens are disabled.
     */
    uint8 internal isPaused;

    /**
     * @dev Value to track the state of the re-entrancy guard.
     */
    uint8 private unlocked = 1;

    /**
     * @dev Guards against re-entrancy.
     */
    modifier lock() {
        if (unlocked == 0) {
            revert Locked();
        }
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /**
     * @dev Prevents certain operations from being executed if the price volatility induced timelock has yet to conclude.
     */
    modifier singleSidedTimelock() {
        if (block.timestamp < singleSidedTimelockDeadline) {
            revert SingleSidedTimelock();
        }
        _;
    }

    /**
     * @dev Prevents operations from being executed if the Pair is currently paused.
     */
    modifier checkPaused() {
        if (isPaused == 1) {
            revert Paused();
        }
        _;
    }

    /**
     * @dev Called whenever an LP wants to burn their LP tokens to make sure they get their fair share of fees.
     * If `feeTo` is defined, `balanceOf(address(this))` gets transferred to `feeTo`.
     * If `feeTo` is not defined, `balanceOf(address(this))` gets burned and the LP tokens all grow in value.
     */
    modifier sendOrRefundFee() {
        address feeTo = IButtonswapFactory(factory).feeTo();
        if (feeTo != address(0)) {
            _transfer(address(this), feeTo, balanceOf[address(this)]);
        } else {
            _burn(address(this), balanceOf[address(this)]);
        }
        _;
    }

    /**
     * @dev Prevents operations from being executed if the caller is not the factory.
     */
    modifier onlyFactory() {
        if (msg.sender != factory) {
            revert Forbidden();
        }
        _;
    }

    constructor() {
        factory = msg.sender;
        (
            token0,
            token1,
            maxVolatilityBps,
            minTimelockDuration,
            maxTimelockDuration,
            maxSwappableReservoirLimitBps,
            swappableReservoirGrowthWindow
        ) = IButtonswapFactory(factory).lastCreatedTokensAndParameters();
    }

    /**
     * @dev Always mints liquidity equivalent to 1/6th of the growth in sqrt(k) and allocates to address(this)
     * If there isn't a `feeTo` address defined, these LP tokens will get burned this 1/6th gets reallocated to LPs
     * @param pool0 The `token0` active liquidity balance at the start of the ongoing swap
     * @param pool1 The `token1` active liquidity balance at the start of the ongoing swap
     * @param pool0New The `token0` active liquidity balance at the end of the ongoing swap
     * @param pool1New The `token1` active liquidity balance at the end of the ongoing swap
     */
    function _mintFee(uint256 pool0, uint256 pool1, uint256 pool0New, uint256 pool1New) internal {
        uint256 liquidityOut = PairMath.getProtocolFeeLiquidityMinted(totalSupply, pool0 * pool1, pool0New * pool1New);
        if (liquidityOut > 0) {
            _mint(address(this), liquidityOut);
        }
    }

    /**
     * @dev Updates `price0CumulativeLast` and `price1CumulativeLast` based on the current timestamp.
     * @param pool0 The `token0` active liquidity balance at the start of the ongoing swap
     * @param pool1 The `token1` active liquidity balance at the start of the ongoing swap
     */
    function _updatePriceCumulative(uint256 pool0, uint256 pool1) internal {
        uint112 _pool0 = uint112(pool0);
        uint112 _pool1 = uint112(pool1);
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            // underflow is desired
            timeElapsed = blockTimestamp - blockTimestampLast;
        }
        if (timeElapsed > 0 && pool0 != 0 && pool1 != 0) {
            // * never overflows, and + overflow is desired
            unchecked {
                price0CumulativeLast += ((pool1 << 112) * timeElapsed) / _pool0;
                price1CumulativeLast += ((pool0 << 112) * timeElapsed) / _pool1;
            }
            blockTimestampLast = blockTimestamp;
        }
    }

    /**
     * @dev Refer to [closest-bound-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/closest-bound-math.md) for more detail.
     * @param poolALower The lower bound for the active liquidity balance of the non-fixed token
     * @param poolB The active liquidity balance of the fixed token
     * @param _poolALast The active liquidity balance at the end of the last swap for the non-fixed token
     * @param _poolBLast The active liquidity balance at the end of the last swap for the fixed token
     * @return closestBound The bound for the active liquidity balance of the non-fixed token that produces a price ratio closest to last swap price
     */
    function _closestBound(uint256 poolALower, uint256 poolB, uint256 _poolALast, uint256 _poolBLast)
        internal
        pure
        returns (uint256 closestBound)
    {
        if ((poolALower * _poolBLast) + (_poolBLast / 2) < _poolALast * poolB) {
            closestBound = poolALower + 1;
        }
        closestBound = poolALower;
    }

    /**
     * @dev Refer to [liquidity-balances-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/liquidity-balances-math.md) for more detail.
     * @param total0 The total amount of `token0` held by the Pair
     * @param total1 The total amount of `token1` held by the Pair
     * @return lb The current active and inactive liquidity balances
     */
    function _getLiquidityBalances(uint256 total0, uint256 total1)
        internal
        view
        returns (LiquidityBalances memory lb)
    {
        uint256 _pool0Last = uint256(pool0Last);
        uint256 _pool1Last = uint256(pool1Last);
        if (_pool0Last == 0 || _pool1Last == 0) {
            // Before Pair is initialized by first dual mint just return zeroes
        } else if (total0 == 0 || total1 == 0) {
            // Save the extra calculations and just return zeroes
        } else {
            if (total0 * _pool1Last < total1 * _pool0Last) {
                lb.pool0 = total0;
                // pool0Last/pool1Last == pool0/pool1 => pool1 == (pool0*pool1Last)/pool0Last
                // pool1Last/pool0Last == pool1/pool0 => pool1 == (pool0*pool1Last)/pool0Last
                lb.pool1 = (lb.pool0 * _pool1Last) / _pool0Last;
                lb.pool1 = _closestBound(lb.pool1, lb.pool0, _pool1Last, _pool0Last);
                // reservoir0 is zero, so no need to set it
                lb.reservoir1 = total1 - lb.pool1;
            } else {
                lb.pool1 = total1;
                // pool0Last/pool1Last == pool0/pool1 => pool0 == (pool1*pool0Last)/pool1Last
                // pool1Last/pool0Last == pool1/pool0 => pool0 == (pool1*pool0Last)/pool1Last
                lb.pool0 = (lb.pool1 * _pool0Last) / _pool1Last;
                lb.pool0 = _closestBound(lb.pool0, lb.pool1, _pool0Last, _pool1Last);
                // reservoir1 is zero, so no need to set it
                lb.reservoir0 = total0 - lb.pool0;
            }
            if (lb.pool0 > type(uint112).max || lb.pool1 > type(uint112).max) {
                revert Overflow();
            }
        }
    }

    /**
     * @dev Calculates current price volatility and initiates a timelock scaled to the volatility size.
     * This timelock prohibits single-sided operations from being executed until enough time has passed for the timelock
     *   to conclude.
     * This protects against attempts to manipulate the price that the reservoir is valued at during single-sided operations.
     * @param _movingAveragePrice0 The current `movingAveragePrice0` value
     * @param pool0New The `token0` active liquidity balance at the end of the ongoing swap
     * @param pool1New The `token1` active liquidity balance at the end of the ongoing swap
     */
    function _updateSingleSidedTimelock(uint256 _movingAveragePrice0, uint112 pool0New, uint112 pool1New) internal {
        uint256 newPrice0 = uint256(UQ112x112.encode(pool1New).uqdiv(pool0New));
        uint256 priceDifference;
        if (newPrice0 > _movingAveragePrice0) {
            priceDifference = newPrice0 - _movingAveragePrice0;
        } else {
            priceDifference = _movingAveragePrice0 - newPrice0;
        }
        // priceDifference / ((_movingAveragePrice0 * maxVolatilityBps)/BPS)
        uint256 timelock = Math.min(
            minTimelockDuration
                + (
                    (priceDifference * BPS * (maxTimelockDuration - minTimelockDuration))
                        / (_movingAveragePrice0 * maxVolatilityBps)
                ),
            maxTimelockDuration
        );
        uint120 timelockDeadline = uint120(block.timestamp + timelock);
        if (timelockDeadline > singleSidedTimelockDeadline) {
            singleSidedTimelockDeadline = timelockDeadline;
        }
    }

    /**
     * @dev Calculates the current limit on the number of reservoir tokens that can be exchanged during a single-sided
     *   operation.
     * This is based on corresponding active liquidity size and time since and size of the last single-sided operation.
     * @param poolA The active liquidity balance for the non-zero reservoir token
     * @return swappableReservoir The amount of non-zero reservoir token that can be exchanged as part of a single-sided operation
     */
    function _getSwappableReservoirLimit(uint256 poolA) internal view returns (uint256 swappableReservoir) {
        // Calculate the maximum the limit can be as a fraction of the corresponding active liquidity
        uint256 maxSwappableReservoirLimit = (poolA * maxSwappableReservoirLimitBps) / BPS;
        uint256 _swappableReservoirLimitReachesMaxDeadline = swappableReservoirLimitReachesMaxDeadline;
        if (_swappableReservoirLimitReachesMaxDeadline > block.timestamp) {
            // If the current deadline is still active then calculate the progress towards reaching it
            uint256 progress =
                swappableReservoirGrowthWindow - (_swappableReservoirLimitReachesMaxDeadline - block.timestamp);
            // The greater the progress, the closer to the max limit we get
            swappableReservoir = (maxSwappableReservoirLimit * progress) / swappableReservoirGrowthWindow;
        } else {
            // If the current deadline has expired then the full limit is available
            swappableReservoir = maxSwappableReservoirLimit;
        }
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function getSwappableReservoirLimit() external view returns (uint256 swappableReservoirLimit) {
        uint256 total0 = IERC20(token0).balanceOf(address(this));
        uint256 total1 = IERC20(token1).balanceOf(address(this));
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);

        if (lb.reservoir0 > 0) {
            swappableReservoirLimit = _getSwappableReservoirLimit(lb.pool0);
        } else {
            swappableReservoirLimit = _getSwappableReservoirLimit(lb.pool1);
        }
    }

    /**
     * @dev Updates the value of `swappableReservoirLimitReachesMaxDeadline` which is the time at which the maximum
     *   amount of inactive liquidity tokens can be exchanged during a single-sided operation.
     * @dev Assumes `swappedAmountA` is less than or equal to `maxSwappableReservoirLimit`
     * @param poolA The active liquidity balance for the non-zero reservoir token
     * @param swappedAmountA The amount of non-zero reservoir tokens that were exchanged during the ongoing single-sided
     *   operation
     */
    function _updateSwappableReservoirDeadline(uint256 poolA, uint256 swappedAmountA) internal {
        // Calculate the maximum the limit can be as a fraction of the corresponding active liquidity
        uint256 maxSwappableReservoirLimit = (poolA * maxSwappableReservoirLimitBps) / BPS;
        // Calculate how much time delay the swap instigates
        uint256 delay;
        // Check non-zero to avoid div by zero error
        if (maxSwappableReservoirLimit > 0) {
            // Since `swappedAmountA/maxSwappableReservoirLimit <= 1`, `delay <= swappableReservoirGrowthWindow`
            delay = (swappableReservoirGrowthWindow * swappedAmountA) / maxSwappableReservoirLimit;
        } else {
            // If it is zero then it's in an extreme condition and a delay is most appropriate way to handle it
            delay = swappableReservoirGrowthWindow;
        }
        // Apply the delay
        uint256 _swappableReservoirLimitReachesMaxDeadline = swappableReservoirLimitReachesMaxDeadline;
        if (_swappableReservoirLimitReachesMaxDeadline > block.timestamp) {
            // If the current deadline hasn't expired yet then add the delay to it
            swappableReservoirLimitReachesMaxDeadline = uint120(_swappableReservoirLimitReachesMaxDeadline + delay);
        } else {
            // If the current deadline has expired already then add the delay to the current time, so that the full
            //   delay is still applied
            swappableReservoirLimitReachesMaxDeadline = uint120(block.timestamp + delay);
        }
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function getIsPaused() external view returns (bool _isPaused) {
        _isPaused = isPaused == 1;
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function setIsPaused(bool isPausedNew) external onlyFactory {
        isPaused = isPausedNew ? 1 : 0;
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function getLiquidityBalances()
        external
        view
        returns (uint112 _pool0, uint112 _pool1, uint112 _reservoir0, uint112 _reservoir1, uint32 _blockTimestampLast)
    {
        uint256 total0 = IERC20(token0).balanceOf(address(this));
        uint256 total1 = IERC20(token1).balanceOf(address(this));
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
        _pool0 = uint112(lb.pool0);
        _pool1 = uint112(lb.pool1);
        _reservoir0 = uint112(lb.reservoir0);
        _reservoir1 = uint112(lb.reservoir1);
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function movingAveragePrice0() public view returns (uint256 _movingAveragePrice0) {
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            // overflow is desired
            timeElapsed = blockTimestamp - blockTimestampLast;
        }
        uint256 currentPrice0 = uint256(UQ112x112.encode(pool1Last).uqdiv(pool0Last));
        if (timeElapsed == 0) {
            _movingAveragePrice0 = movingAveragePrice0Last;
        } else if (timeElapsed >= 24 hours) {
            _movingAveragePrice0 = currentPrice0;
        } else {
            _movingAveragePrice0 =
                ((movingAveragePrice0Last * (24 hours - timeElapsed)) + (currentPrice0 * timeElapsed)) / 24 hours;
        }
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function mint(uint256 amountIn0, uint256 amountIn1, address to)
        external
        lock
        checkPaused
        sendOrRefundFee
        returns (uint256 liquidityOut)
    {
        uint256 _totalSupply = totalSupply;
        uint256 total0 = IERC20(token0).balanceOf(address(this));
        uint256 total1 = IERC20(token1).balanceOf(address(this));
        SafeERC20.safeTransferFrom(IERC20(token0), msg.sender, address(this), amountIn0);
        SafeERC20.safeTransferFrom(IERC20(token1), msg.sender, address(this), amountIn1);
        // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
        amountIn0 = IERC20(token0).balanceOf(address(this)) - total0;
        amountIn1 = IERC20(token1).balanceOf(address(this)) - total1;

        if (_totalSupply == 0) {
            liquidityOut = Math.sqrt(amountIn0 * amountIn1) - MINIMUM_LIQUIDITY;
            // permanently lock the first MINIMUM_LIQUIDITY tokens
            _mint(address(0), MINIMUM_LIQUIDITY);
            // Initialize Pair last swap price
            pool0Last = uint112(amountIn0);
            pool1Last = uint112(amountIn1);
            // Initialize timestamp so first price update is accurate
            blockTimestampLast = uint32(block.timestamp % 2 ** 32);
            // Initialize moving average
            movingAveragePrice0Last = uint256(UQ112x112.encode(pool1Last).uqdiv(pool0Last));
        } else {
            // Don't need to check that amountIn{0,1} are in the right ratio because the least generous ratio is used
            //   to determine the liquidityOut value, meaning any tokens that exceed that ratio are donated.
            // If total0 or total1 are zero (eg. due to negative rebases) then the function call reverts with div by zero
            liquidityOut =
                PairMath.getDualSidedMintLiquidityOutAmount(_totalSupply, amountIn0, amountIn1, total0, total1);
        }

        if (liquidityOut == 0) {
            revert InsufficientLiquidityMinted();
        }
        _mint(to, liquidityOut);
        emit Mint(msg.sender, amountIn0, amountIn1, liquidityOut, to);
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function mintWithReservoir(uint256 amountIn, address to)
        external
        lock
        checkPaused
        singleSidedTimelock
        sendOrRefundFee
        returns (uint256 liquidityOut)
    {
        if (amountIn == 0) {
            revert InsufficientLiquidityAdded();
        }
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            revert Uninitialized();
        }
        uint256 total0 = IERC20(token0).balanceOf(address(this));
        uint256 total1 = IERC20(token1).balanceOf(address(this));
        // Determine current pool liquidity
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
        if (lb.pool0 == 0 || lb.pool1 == 0) {
            revert InsufficientLiquidity();
        }
        if (lb.reservoir0 == 0) {
            // If reservoir0 is empty then we're adding token0 to pair with token1 reservoir liquidity
            SafeERC20.safeTransferFrom(IERC20(token0), msg.sender, address(this), amountIn);
            // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
            amountIn = IERC20(token0).balanceOf(address(this)) - total0;

            // Ensure there's enough reservoir1 liquidity to do this without growing reservoir0
            LiquidityBalances memory lbNew = _getLiquidityBalances(total0 + amountIn, total1);
            if (lbNew.reservoir0 > 0) {
                revert InsufficientReservoir();
            }

            uint256 swappedReservoirAmount1;
            (liquidityOut, swappedReservoirAmount1) = PairMath.getSingleSidedMintLiquidityOutAmountA(
                _totalSupply, amountIn, total0, total1, movingAveragePrice0()
            );

            uint256 swappableReservoirLimit = _getSwappableReservoirLimit(lb.pool1);
            if (swappedReservoirAmount1 > swappableReservoirLimit) {
                revert SwappableReservoirExceeded();
            }
            _updateSwappableReservoirDeadline(lb.pool1, swappedReservoirAmount1);
        } else {
            // If reservoir1 is empty then we're adding token1 to pair with token0 reservoir liquidity
            SafeERC20.safeTransferFrom(IERC20(token1), msg.sender, address(this), amountIn);
            // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
            amountIn = IERC20(token1).balanceOf(address(this)) - total1;

            // Ensure there's enough reservoir0 liquidity to do this without growing reservoir1
            LiquidityBalances memory lbNew = _getLiquidityBalances(total0, total1 + amountIn);
            if (lbNew.reservoir1 > 0) {
                revert InsufficientReservoir();
            }

            uint256 swappedReservoirAmount0;
            (liquidityOut, swappedReservoirAmount0) = PairMath.getSingleSidedMintLiquidityOutAmountB(
                _totalSupply, amountIn, total0, total1, movingAveragePrice0()
            );

            uint256 swappableReservoirLimit = _getSwappableReservoirLimit(lb.pool0);
            if (swappedReservoirAmount0 > swappableReservoirLimit) {
                revert SwappableReservoirExceeded();
            }
            _updateSwappableReservoirDeadline(lb.pool0, swappedReservoirAmount0);
        }

        if (liquidityOut == 0) {
            revert InsufficientLiquidityMinted();
        }
        _mint(to, liquidityOut);
        if (lb.reservoir0 == 0) {
            emit Mint(msg.sender, amountIn, 0, liquidityOut, to);
        } else {
            emit Mint(msg.sender, 0, amountIn, liquidityOut, to);
        }
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function burn(uint256 liquidityIn, address to)
        external
        lock
        sendOrRefundFee
        returns (uint256 amountOut0, uint256 amountOut1)
    {
        uint256 _totalSupply = totalSupply;
        uint256 total0 = IERC20(token0).balanceOf(address(this));
        uint256 total1 = IERC20(token1).balanceOf(address(this));

        (amountOut0, amountOut1) = PairMath.getDualSidedBurnOutputAmounts(_totalSupply, liquidityIn, total0, total1);

        if (amountOut0 == 0 || amountOut1 == 0) {
            revert InsufficientLiquidityBurned();
        }
        _burn(msg.sender, liquidityIn);
        SafeERC20.safeTransfer(IERC20(token0), to, amountOut0);
        SafeERC20.safeTransfer(IERC20(token1), to, amountOut1);
        emit Burn(msg.sender, liquidityIn, amountOut0, amountOut1, to);
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function burnFromReservoir(uint256 liquidityIn, address to)
        external
        lock
        checkPaused
        singleSidedTimelock
        sendOrRefundFee
        returns (uint256 amountOut0, uint256 amountOut1)
    {
        uint256 _totalSupply = totalSupply;
        uint256 total0 = IERC20(token0).balanceOf(address(this));
        uint256 total1 = IERC20(token1).balanceOf(address(this));
        // Determine current pool liquidity
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
        if (lb.pool0 == 0 || lb.pool1 == 0) {
            revert InsufficientLiquidity();
        }
        if (lb.reservoir0 == 0) {
            // If reservoir0 is empty then we're swapping amountOut0 for token1 from reservoir1
            uint256 swappedReservoirAmount1;
            (amountOut1, swappedReservoirAmount1) = PairMath.getSingleSidedBurnOutputAmountB(
                _totalSupply, liquidityIn, total0, total1, movingAveragePrice0()
            );
            // Check there's enough reservoir liquidity to withdraw from
            // If `amountOut1` exceeds reservoir1 then it will result in reservoir0 growing from excess token0
            if (amountOut1 > lb.reservoir1) {
                revert InsufficientReservoir();
            }

            uint256 swappableReservoirLimit = _getSwappableReservoirLimit(lb.pool1);
            if (swappedReservoirAmount1 > swappableReservoirLimit) {
                revert SwappableReservoirExceeded();
            }
            _updateSwappableReservoirDeadline(lb.pool1, swappedReservoirAmount1);
        } else {
            // If reservoir0 isn't empty then we're swapping amountOut1 for token0 from reservoir0
            uint256 swappedReservoirAmount0;
            (amountOut0, swappedReservoirAmount0) = PairMath.getSingleSidedBurnOutputAmountA(
                _totalSupply, liquidityIn, total0, total1, movingAveragePrice0()
            );
            // Check there's enough reservoir liquidity to withdraw from
            // If `amountOut0` exceeds reservoir0 then it will result in reservoir1 growing from excess token1
            if (amountOut0 > lb.reservoir0) {
                revert InsufficientReservoir();
            }

            uint256 swappableReservoirLimit = _getSwappableReservoirLimit(lb.pool0);
            if (swappedReservoirAmount0 > swappableReservoirLimit) {
                revert SwappableReservoirExceeded();
            }
            _updateSwappableReservoirDeadline(lb.pool0, swappedReservoirAmount0);
        }
        _burn(msg.sender, liquidityIn);
        if (amountOut0 > 0) {
            SafeERC20.safeTransfer(IERC20(token0), to, amountOut0);
        } else if (amountOut1 > 0) {
            SafeERC20.safeTransfer(IERC20(token1), to, amountOut1);
        } else {
            revert InsufficientLiquidityBurned();
        }
        emit Burn(msg.sender, liquidityIn, amountOut0, amountOut1, to);
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function swap(uint256 amountIn0, uint256 amountIn1, uint256 amountOut0, uint256 amountOut1, address to)
        external
        lock
        checkPaused
    {
        {
            if (amountOut0 == 0 && amountOut1 == 0) {
                revert InsufficientOutputAmount();
            }
            if (to == token0 || to == token1) {
                revert InvalidRecipient();
            }
            uint256 total0 = IERC20(token0).balanceOf(address(this));
            uint256 total1 = IERC20(token1).balanceOf(address(this));
            // Determine current pool liquidity
            LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
            if (amountOut0 >= lb.pool0 || amountOut1 >= lb.pool1) {
                revert InsufficientLiquidity();
            }
            // Transfer in the specified input
            if (amountIn0 > 0) {
                SafeERC20.safeTransferFrom(IERC20(token0), msg.sender, address(this), amountIn0);
            }
            if (amountIn1 > 0) {
                SafeERC20.safeTransferFrom(IERC20(token1), msg.sender, address(this), amountIn1);
            }
            // Optimistically transfer output
            if (amountOut0 > 0) {
                SafeERC20.safeTransfer(IERC20(token0), to, amountOut0);
            }
            if (amountOut1 > 0) {
                SafeERC20.safeTransfer(IERC20(token1), to, amountOut1);
            }

            // Refresh balances
            total0 = IERC20(token0).balanceOf(address(this));
            total1 = IERC20(token1).balanceOf(address(this));
            // The reservoir balances must remain unchanged during a swap, so all balance changes impact the pool balances
            uint256 pool0New = total0 - lb.reservoir0;
            uint256 pool1New = total1 - lb.reservoir1;
            if (pool0New == 0 || pool1New == 0) {
                revert InvalidFinalPrice();
            }
            // Update to the actual amount of tokens the user sent in based on the delta between old and new pool balances
            if (pool0New > lb.pool0) {
                amountIn0 = pool0New - lb.pool0;
                amountOut0 = 0;
            } else {
                amountIn0 = 0;
                amountOut0 = lb.pool0 - pool0New;
            }
            if (pool1New > lb.pool1) {
                amountIn1 = pool1New - lb.pool1;
                amountOut1 = 0;
            } else {
                amountIn1 = 0;
                amountOut1 = lb.pool1 - pool1New;
            }
            // If after accounting for input and output cancelling one another out, fee on transfer, etc there is no
            //   input tokens in real terms then revert.
            if (amountIn0 == 0 && amountIn1 == 0) {
                revert InsufficientInputAmount();
            }
            uint256 pool0NewAdjusted = (pool0New * 1000) - (amountIn0 * 3);
            uint256 pool1NewAdjusted = (pool1New * 1000) - (amountIn1 * 3);
            // After account for 0.3% fees, the new K must not be less than the old K
            if (pool0NewAdjusted * pool1NewAdjusted < (lb.pool0 * lb.pool1 * 1000 ** 2)) {
                revert KInvariant();
            }
            // Update moving average before `_updatePriceCumulative` updates `blockTimestampLast` and the new `poolXLast` values are set
            uint256 _movingAveragePrice0 = movingAveragePrice0();
            movingAveragePrice0Last = _movingAveragePrice0;
            _mintFee(lb.pool0, lb.pool1, pool0New, pool1New);
            _updatePriceCumulative(lb.pool0, lb.pool1);
            _updateSingleSidedTimelock(_movingAveragePrice0, uint112(pool0New), uint112(pool1New));
            // Update Pair last swap price
            pool0Last = uint112(pool0New);
            pool1Last = uint112(pool1New);
        }
        emit Swap(msg.sender, amountIn0, amountIn1, amountOut0, amountOut1, to);
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function setMaxVolatilityBps(uint16 _maxVolatilityBps) external onlyFactory {
        maxVolatilityBps = _maxVolatilityBps;
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function setMinTimelockDuration(uint32 _minTimelockDuration) external onlyFactory {
        minTimelockDuration = _minTimelockDuration;
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function setMaxTimelockDuration(uint32 _maxTimelockDuration) external onlyFactory {
        maxTimelockDuration = _maxTimelockDuration;
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function setMaxSwappableReservoirLimitBps(uint16 _maxSwappableReservoirLimitBps) external onlyFactory {
        maxSwappableReservoirLimitBps = _maxSwappableReservoirLimitBps;
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function setSwappableReservoirGrowthWindow(uint32 _swappableReservoirGrowthWindow) external onlyFactory {
        swappableReservoirGrowthWindow = _swappableReservoirGrowthWindow;
    }
}
