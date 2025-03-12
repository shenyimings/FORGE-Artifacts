/*
MIT License

Copyright (c) 2021 Reflexer Labs

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

pragma solidity 0.6.7;

import "./PoolViewer.sol";
import "./PeripheryPayments.sol";
import { IUniswapV3Pool } from "./uni/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3MintCallback } from "./uni/interfaces/callback/IUniswapV3MintCallback.sol";
import { LiquidityAmounts } from "./uni/libraries/LiquidityAmounts.sol";
import { TickMath } from "./uni/libraries/TickMath.sol";

abstract contract OracleForUniswapLike {
    function getResultsWithValidity() public virtual returns (uint256, uint256, bool);
}

/**
 * @notice This contract is based on https://github.com/dmihal/uniswap-liquidity-dao/blob/master/contracts/MetaPool.sol
 */
abstract contract GebUniswapV3ManagerBase is ERC20, PeripheryPayments {
    // --- Pool Variables ---
    // The address of pool's token0
    address public token0;
    // The address of pool's token1
    address public token1;
    // The pool's fee
    uint24 public fee;
    // The pool's tickSpacing
    int24 public tickSpacing;
    // The pool's maximum liquidity per tick
    uint128 public maxLiquidityPerTick;
    // Flag to identify whether the system coin is token0 or token1. Needed for correct tick calculation
    bool systemCoinIsT0;

    // --- General Variables ---
    // The minimum delay required to perform a rebalance. Bounded to be between MINIMUM_DELAY and MAXIMUM_DELAY
    uint256 public delay;
    // The timestamp of the last rebalance
    uint256 public lastRebalance;

    // --- External Contracts ---
    // Address of the Uniswap v3 pool
    IUniswapV3Pool public pool;
    // Address of oracle relayer to get prices from
    OracleForUniswapLike public oracle;
    // Address of contract that allows simulating pool functions
    PoolViewer public poolViewer;

    // --- Constants ---
    // Used to get the max amount of tokens per liquidity burned
    uint128 constant MAX_UINT128 = uint128(0 - 1);
    // 100% - Not really achievable, because it'll reach max and min ticks
    uint256 constant MAX_THRESHOLD = 10000000;
    // 1% - Quite dangerous because the market price can easily move beyond the threshold
    uint256 constant MIN_THRESHOLD = 10000; // 1%
    // A week is the maximum time allowed without a rebalance
    uint256 constant MAX_DELAY = 7 days;
    // 1 hour is the absolute minimum delay for a rebalance. Could be less through deposits
    uint256 constant MIN_DELAY = 60 minutes;
    // Absolutes ticks, (MAX_TICK % tickSpacing == 0) and (MIN_TICK % tickSpacing == 0)
    int24 public constant MAX_TICK = 887220;
    int24 public constant MIN_TICK = -887220;
    // The minimum swap threshold, so it's worthwhile the gas
    uint256 constant SWAP_THRESHOLD = 1 finney; //1e15 units.
    // Constants for price ratio calculation
    uint256 public constant PRICE_RATIO_SCALE = 1000000000;
    uint256 public constant SHIFT_AMOUNT = 192;

    // --- Struct ---
    struct Position {
      bytes32 id;
      int24 lowerTick;
      int24 upperTick;
      uint128 uniLiquidity;
      uint256 threshold;
      uint256 tkn0Reserve;
      uint256 tkn1Reserve;
    }

    // --- Events ---
    event ModifyParameters(bytes32 parameter, uint256 val);
    event ModifyParameters(bytes32 parameter, address val);
    event AddAuthorization(address account);
    event RemoveAuthorization(address account);
    event Deposit(address sender, address recipient, uint256 liquidityAdded);
    event Withdraw(address sender, address recipient, uint256 liquidityAdded);
    event Rebalance(address sender, uint256 timestamp);

    // --- Auth ---
    mapping(address => uint256) public authorizedAccounts;

    /**
     * @notice Add auth to an account
     * @param account Account to add auth to
     */
    function addAuthorization(address account) external isAuthorized {
        authorizedAccounts[account] = 1;
        emit AddAuthorization(account);
    }

    /**
     * @notice Remove auth from an account
     * @param account Account to remove auth from
     */
    function removeAuthorization(address account) external isAuthorized {
        authorizedAccounts[account] = 0;
        emit RemoveAuthorization(account);
    }

    /**
     * @notice Checks whether msg.sender can call an authed function
     **/
    modifier isAuthorized() {
        require(authorizedAccounts[msg.sender] == 1, "GebUniswapV3LiquidityManager/account-not-authorized");
        _;
    }

    /**
     * @notice Constructor that sets initial parameters for this contract
     * @param name_ The name of the ERC20 this contract will distribute
     * @param symbol_ The symbol of the ERC20 this contract will distribute
     * @param systemCoinAddress_ The address of the system coin
     * @param delay_ The minimum required time before rebalance() can be called
     * @param pool_ Address of the already deployed Uniswap v3 pool that this contract will manage
     * @param oracle_ Address of the already deployed oracle that provides both prices
     */
    constructor(
      string memory name_,
      string memory symbol_,
      address systemCoinAddress_,
      uint256 delay_,
      address pool_,
      OracleForUniswapLike oracle_,
      PoolViewer poolViewer_,
      address weth9Address
    ) public ERC20(name_, symbol_) PeripheryPayments(weth9Address) {
        require(delay_ >= MIN_DELAY && delay_ <= MAX_DELAY, "GebUniswapv3LiquidityManager/invalid-delay");

        authorizedAccounts[msg.sender] = 1;

        // Getting pool information
        pool                = IUniswapV3Pool(pool_);

        token0              = pool.token0();
        token1              = pool.token1();
        fee                 = pool.fee();
        tickSpacing         = pool.tickSpacing();
        maxLiquidityPerTick = pool.maxLiquidityPerTick();

        require(MIN_TICK % tickSpacing == 0, "GebUniswapv3LiquidityManager/invalid-max-tick-for-spacing");
        require(MAX_TICK % tickSpacing == 0, "GebUniswapv3LiquidityManager/invalid-min-tick-for-spacing");

        systemCoinIsT0 = token0 == systemCoinAddress_ ? true : false;
        delay       = delay_;
        oracle      = oracle_;
        poolViewer  = poolViewer_;

        emit AddAuthorization(msg.sender);
    }

    // --- Math ---
    /**
     * @notice Calculates the sqrt of a number
     * @param y The number to calculate the square root of
     * @return z The result of the calculation
     */
    function sqrt(uint256 y) public pure returns (uint256 z) {
        if (y > 3) {
          z = y;
          uint256 x = y / 2 + 1;
          while (x < z) {
            z = x;
            x = (y / x + x) / 2;
          }
        } else if (y != 0) {
          z = 1;
        }
    }

    // --- SafeCast ---
    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value < 2**160, "GebUniswapv3LiquidityManager/toUint160_overflow");
        return uint160(value);
    }
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value < 2**128, "GebUniswapv3LiquidityManager/toUint128_overflow");
        return uint128(value);
    }
    function toInt24(uint256 value) internal pure returns (int24) {
        require(value < 2**23, "GebUniswapv3LiquidityManager/toInt24_overflow");
        return int24(value);
    }

    // --- Administration ---
    /**
     * @notice Modify the adjustable parameters
     * @param parameter The variable to change
     * @param data The value to set for the parameter
     */
    function modifyParameters(bytes32 parameter, uint256 data) external isAuthorized {
        if (parameter == "delay") {
          require(data >= MIN_DELAY && data <= MAX_DELAY, "GebUniswapv3LiquidityManager/invalid-delay");
          delay = data;
        } else revert("GebUniswapv3LiquidityManager/modify-unrecognized-param");

        emit ModifyParameters(parameter, data);
    }

    /**
     * @notice Modify adjustable parameters
     * @param parameter The variable to change
     * @param data The value to set for the parameter
     */
    function modifyParameters(bytes32 parameter, address data) external isAuthorized {
        require(data != address(0), "GebUniswapv3LiquidityManager/null-data");

        if (parameter == "oracle") {
          // If it's an invalid address, this tx will revert
          OracleForUniswapLike(data).getResultsWithValidity();
          oracle = OracleForUniswapLike(data);
        } else revert("GebUniswapv3LiquidityManager/modify-unrecognized-param");

        emit ModifyParameters(parameter, data);
    }

    // --- Virtual functions  ---
    function deposit(uint256 newLiquidity, address recipient, uint256 minAm0, uint256 minAm1) external payable virtual returns (uint256 mintAmount);
    function withdraw(uint256 liquidityAmount, address recipient) external virtual returns (uint256 amount0, uint256 amount1);
    function rebalance() external virtual;

    // --- Getters ---
    /**
     * @notice Public function to get both the redemption price for the system coin and the other token's price
     * @return redemptionPrice The redemption price
     * @return tokenPrice The other token's price
     */
    function getPrices() public returns (uint256 redemptionPrice, uint256 tokenPrice) {
        bool valid;
        (redemptionPrice, tokenPrice, valid) = oracle.getResultsWithValidity();
        require(valid, "GebUniswapv3LiquidityManager/invalid-price");
    }

    /**
     * @notice Function that returns the next target ticks based on the redemption price
     * @return _nextLower The lower bound of the range
     * @return _nextUpper The upper bound of the range
     */
    function getNextTicks(uint256 _threshold) public returns (int24 _nextLower, int24 _nextUpper, int24 targetTick) {
       targetTick                 = getTargetTick();
       (_nextLower,  _nextUpper) = getTicksWithThreshold(targetTick, _threshold);
    }

    /**
     * @notice Function that returns the target ticks based on the redemption price
     * @return targetTick The target tick that represents the redemption price
     */
    function getTargetTick() public returns(int24 targetTick){
         // 1. Get prices from the oracle relayer
        (uint256 redemptionPrice, uint256 ethUsdPrice) = getPrices();

        // 2. Calculate the price ratio
        uint160 sqrtPriceX96;
        if (systemCoinIsT0) {
          sqrtPriceX96 = toUint160(sqrt((redemptionPrice.mul(PRICE_RATIO_SCALE).div(ethUsdPrice) << SHIFT_AMOUNT) / PRICE_RATIO_SCALE));
        } else {
          sqrtPriceX96 = toUint160(sqrt((ethUsdPrice.mul(PRICE_RATIO_SCALE).div(redemptionPrice) << SHIFT_AMOUNT) / PRICE_RATIO_SCALE));
        }

        // 3. Calculate the tick that the ratio is at
        int24 approximatedTick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        // 4. Adjust to comply to tickSpacing
        targetTick = approximatedTick - (approximatedTick % tickSpacing);
    }

     /**
     * @notice Function that returns the next target ticks based on the target tick
     * @param targetTick The tick representing the redemption price
     * @param _threshold The threshold used to find ticks
     * @return lowerTick The lower bound of the range
     * @return upperTick The upper bound of the range
     */
    function getTicksWithThreshold(int24 targetTick, uint256 _threshold) public pure returns(int24 lowerTick, int24 upperTick){
        // 5. Find lower and upper bounds for the next position
        lowerTick = targetTick - toInt24(_threshold) < MIN_TICK ? MIN_TICK : targetTick - toInt24(_threshold);
        upperTick = targetTick + toInt24(_threshold) > MAX_TICK ? MAX_TICK : targetTick + toInt24(_threshold);
    }


    /**
     * @notice An internal non state changing function that allows simulating a withdraw and returning the amount of each token received
     * @param _position The position to perform the operation
     * @param _liquidity The amount of liquidity to be withdrawn
     * @return amount0 The amount of token0
     * @return amount1 The amount of token1
     */
    function _getTokenAmountsFromLiquidity(Position storage _position, uint128 _liquidity) internal returns (uint256 amount0, uint256 amount1) {
        uint256 __supply          = _totalSupply;
        uint128 _liquidityBurned  = toUint128(uint256(_liquidity).mul(_position.uniLiquidity).div(__supply));

        (, bytes memory ret) =
          address(poolViewer).delegatecall(
            abi.encodeWithSignature("burnViewer(address,int24,int24,uint128)", address(pool), _position.lowerTick, _position.upperTick, _liquidityBurned)
          );
        (amount0, amount1) = abi.decode(ret, (uint256, uint256));
        require(amount0 > 0 || amount1 > 0, "GebUniswapv3LiquidityManager/invalid-burnViewer-amounts");
    }


    // --- Core user actions ---
    /**
     * @notice Add liquidity to this pool manager
     * @param _position The position to perform the operation
     * @param _newLiquidity The amount of liquidity to add
     * @param _targetTick The price to center the position around
     */

    function _deposit(Position storage _position, uint128 _newLiquidity, int24 _targetTick ) internal returns(uint256 amount0,uint256 amount1){
        (int24 _nextLowerTick,int24 _nextUpperTick) = getTicksWithThreshold(_targetTick,_position.threshold);

        { // Scope to avoid stack too deep
          uint128 compoundLiquidity = 0;
          uint256 used0             = 0;
          uint256 used1             = 0;

          if (_position.uniLiquidity > 0 && (_position.lowerTick != _nextLowerTick || _position.upperTick != _nextUpperTick)) {
            (compoundLiquidity,  used0,  used1) = maxLiquidity(_position,_nextLowerTick,_nextUpperTick);
            require(_newLiquidity + compoundLiquidity >= _newLiquidity, "GebUniswapv3LiquidityManager/liquidity-overflow");

            emit Rebalance(msg.sender, block.timestamp);
          }
          // 3. Mint our new position on Uniswap
          lastRebalance = block.timestamp;
          (uint256 amount0Minted, uint256 amount1Minted) = _mintOnUniswap(_position, _nextLowerTick, _nextUpperTick, _newLiquidity+compoundLiquidity, abi.encode(msg.sender, used0 , used1));
          (amount0, amount1) = (amount0Minted - used0, amount1Minted - used1);
        }
    }

    /**
     * @notice Remove liquidity and withdraw the underlying assets
     * @param _position The position to perform the operation
     * @param _liquidityBurned The amount of liquidity to withdraw
     * @param _recipient The address that will receive token0 and token1 tokens
     * @return amount0 The amount of token0 requested from the pool
     * @return amount1 The amount of token1 requested from the pool
     */
    function _withdraw(
        Position storage _position,
        uint128 _liquidityBurned,
        address _recipient
    ) internal returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _burnOnUniswap(_position, _position.lowerTick, _position.upperTick, _liquidityBurned, _recipient);
        emit Withdraw(msg.sender, _recipient, _liquidityBurned);
    }

    /**
     * @notice Rebalance by burning and then minting the position
     * @param _position The position to perform the operation
     * @param _targetTick The desired price to center the liquidity around
     */
    function _rebalance(Position storage _position, int24 _targetTick) internal {
        (int24 _nextLowerTick, int24 _nextUpperTick) = getTicksWithThreshold(_targetTick,_position.threshold);
        (int24 _currentLowerTick, int24 _currentUpperTick) = (_position.lowerTick, _position.upperTick);

        if (_currentLowerTick != _nextLowerTick || _currentUpperTick != _nextUpperTick) {
          (uint128 compoundLiquidity, uint256 used0, uint256 used1) = maxLiquidity(_position,_nextLowerTick,_nextUpperTick);
          _mintOnUniswap(_position, _nextLowerTick, _nextUpperTick, compoundLiquidity, abi.encode(msg.sender, used0, used1));
        }
        emit Rebalance(msg.sender, block.timestamp);
    }

    // --- Internal helpers ---
    /**
     * @notice Helper function to mint a position
     * @param _nextLowerTick The lower bound of the range to deposit the liquidity to
     * @param _nextUpperTick The upper bound of the range to deposit the liquidity to
     * @param _amount0 The total amount of token0 to use in the calculations
     * @param _amount1 The total amount of token1 to use in the calculations
     * @return compoundLiquidity The amount of total liquidity to be minted
     * @return tkn0Amount The amount of token0 that will be used
     * @return tkn1Amount The amount of token1 that will be used
     */
    function _getCompoundLiquidity(int24 _nextLowerTick, int24 _nextUpperTick, uint256 _amount0, uint256 _amount1) internal view returns(uint128 compoundLiquidity, uint256 tkn0Amount, uint256 tkn1Amount){
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        uint160 lowerSqrtRatio = TickMath.getSqrtRatioAtTick(_nextLowerTick);
        uint160 upperSqrtRatio = TickMath.getSqrtRatioAtTick(_nextUpperTick);

        compoundLiquidity = LiquidityAmounts.getLiquidityForAmounts(
          sqrtRatioX96,
          lowerSqrtRatio,
          upperSqrtRatio,
          _amount0,
          _amount1
        );
        // Tokens amounts aren't precise from the calculation above, so we do the reverse operation to get the precise amount
        (tkn0Amount,tkn1Amount) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96,lowerSqrtRatio,upperSqrtRatio,compoundLiquidity);
    }

    /**
     * @notice This functions perform actions to optimize the liquidity received
      * @param _position The position to perform operations on
     * @param _nextLowerTick The lower bound of the range to deposit the liquidity to
     * @param _nextUpperTick The upper bound of the range to deposit the liquidity to
     * @return compoundLiquidity The amount of total liquidity to be minted
     * @return tkn0Amount The amount of token0 that will be used
     * @return tkn1Amount The amount of token1 that will be used
     */
    function maxLiquidity(Position storage _position, int24 _nextLowerTick, int24 _nextUpperTick) internal returns(uint128 compoundLiquidity, uint256 tkn0Amount, uint256 tkn1Amount){
        // Burn the existing position and get the fees
        (uint256 collected0, uint256 collected1) = _burnOnUniswap(_position, _position.lowerTick, _position.upperTick, _position.uniLiquidity, address(this));

        uint256 partialAmount0 = collected0.add(_position.tkn0Reserve);
        uint256 partialAmount1 = collected1.add(_position.tkn1Reserve);
        (uint256 used0, uint256 used1) = (0,0);
        (uint256 newAmount0, uint256 newAmount1) = (0,0);
        // Calculate how much liquidity we can get from what's been collect + what we have in the reserves
        (compoundLiquidity, used0, used1) = _getCompoundLiquidity(_nextLowerTick,_nextUpperTick,partialAmount0,partialAmount1);

        if(partialAmount0.sub(used0) >= SWAP_THRESHOLD && partialAmount1.sub(used1) >= SWAP_THRESHOLD) {
          // Take the leftover amounts and do a swap to get a bit more liquidity
          (newAmount0, newAmount1) = _swapOutstanding(_position, partialAmount0.sub(used0), partialAmount1.sub(used1));

          // With new amounts, calculate again how much liquidity we can get
          (compoundLiquidity,  used0,  used1) = _getCompoundLiquidity(_nextLowerTick,_nextUpperTick,partialAmount0.add(newAmount0).sub(used0),partialAmount1.add(newAmount1).sub(used1));
        }

        // Update our reserves
        _position.tkn0Reserve = partialAmount0.add(newAmount0).sub(used0);
        _position.tkn1Reserve = partialAmount1.add(newAmount1).sub(used1);
        tkn0Amount = used0;
        tkn1Amount = used1;
    }

    /**
     * @notice Perform a swap on the uni pool to have a balanced position
      * @param _position The position to perform operations on
     * @param swapAmount0 The amount of token0 that will be used
     * @param swapAmount1 The amount of token1 that will be used
     * @return newAmount0 The new amount of token0 received
     * @return newAmount1 The new amount of token1 received
     */
    function _swapOutstanding(Position storage _position, uint256 swapAmount0,uint256 swapAmount1) internal returns(uint256 newAmount0,uint256 newAmount1) {
      // The swap is not the optimal trade, but it's a simpler calculation that will be enough to keep more or less balanced
      if (swapAmount0 > 0 || swapAmount1 > 0) {
            bool zeroForOne = swapAmount0 > swapAmount1;
            (int256 amount0Delta, int256 amount1Delta) = pool.swap(
              address(this),
              zeroForOne,
              int256(zeroForOne ? swapAmount0 : swapAmount1) / 2,
              TickMath.getSqrtRatioAtTick(zeroForOne ? _position.lowerTick : _position.upperTick),
              abi.encode(address(this))
            );

            newAmount0 = uint256(int256(swapAmount0) - amount0Delta);
            newAmount1 = uint256(int256(swapAmount1) - amount1Delta);
      }
    }

    // --- Uniswap Related Functions ---
    /**
     * @notice Helper function to mint a position
     * @param _lowerTick The lower bound of the range to deposit the liquidity to
     * @param _upperTick The upper bound of the range to deposit the liquidity to
     * @param _totalLiquidity The total amount of liquidity to mint
     * @param _callbackData The data to pass on to the callback function
     */
    function _mintOnUniswap(
        Position storage _position,
        int24 _lowerTick,
        int24 _upperTick,
        uint128 _totalLiquidity,
        bytes memory _callbackData
    ) internal returns(uint256 amount0, uint256 amount1) {
        pool.positions(_position.id);
        (amount0, amount1) = pool.mint(address(this), _lowerTick, _upperTick, _totalLiquidity, _callbackData);
        _position.lowerTick = _lowerTick;
        _position.upperTick = _upperTick;

        bytes32 id = keccak256(abi.encodePacked(address(this), _lowerTick, _upperTick));
        (uint128 _liquidity, , , , ) = pool.positions(id);
        _position.id = id;
        _position.uniLiquidity = _liquidity;
    }

    /**
     * @notice Helper function to burn a position
     * @param _lowerTick The lower bound of the range to deposit the liquidity to
     * @param _upperTick The upper bound of the range to deposit the liquidity to
     * @param _burnedLiquidity The amount of liquidity to burn
     * @param _recipient The address to send the tokens to
     * @return collected0 The amount of token0 requested from the pool
     * @return collected1 The amount of token1 requested from the pool
     */
    function _burnOnUniswap(
        Position storage _position,
        int24 _lowerTick,
        int24 _upperTick,
        uint128 _burnedLiquidity,
        address _recipient
    ) internal returns (uint256 collected0, uint256 collected1) {
        pool.burn(_lowerTick, _upperTick, _burnedLiquidity);
        // Collect all owed
        (collected0, collected1) = pool.collect(_recipient, _lowerTick, _upperTick, MAX_UINT128, MAX_UINT128);

        // Update position. All other factors are still the same
        (uint128 _liquidity, , , , ) = pool.positions(_position.id);
        _position.uniLiquidity = _liquidity;
    }
    /**
     * @notice Callback used to transfer tokens to the pool. Tokens need to be approved before calling mint or deposit.
     * @param amount0Owed The amount of token0 necessary to send to pool
     * @param amount1Owed The amount of token1 necessary to send to pool
     * @param data Arbitrary data to use in the function
     */
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        require(msg.sender == address(pool));

        (address sender, uint256 amt0FromThis, uint256 amt1FromThis) = abi.decode(data, (address, uint256, uint256));
        // Pay what this contract owes
        if (amt0FromThis > 0) {
          TransferHelper.safeTransfer(token0, msg.sender, amt0FromThis);
        }
        if (amt1FromThis > 0) {
          TransferHelper.safeTransfer(token1, msg.sender, amt1FromThis);
        }

        // Pay what the sender owes
        if (amount0Owed > amt0FromThis) {
          pay(token0, sender, msg.sender, amount0Owed - amt0FromThis);
        }
        if (amount1Owed > amt1FromThis) {
          pay(token1, sender, msg.sender, amount1Owed - amt1FromThis);
        }
    }

    function uniswapV3SwapCallback(
      int256 amount0Delta,
      int256 amount1Delta,
      bytes calldata /*data*/
    ) external {
      require(msg.sender == address(pool));

      if (amount0Delta > 0) {
        TransferHelper.safeTransfer(token0, msg.sender, uint256(amount0Delta));
      } else if (amount1Delta > 0) {
        TransferHelper.safeTransfer(token1, msg.sender, uint256(amount1Delta));
      }
    }
}