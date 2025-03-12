//SPDX-License-Identifier: MIT
pragma solidity 0.6.6;
// solidity 0.6 is used to prevent reverting on overflow
pragma experimental ABIEncoderV2;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import {UniswapV2OracleLibrary} from './libraries/UniswapV2OracleLibrary.sol';
import './interfaces/IUniswapV2TwapOracle.sol';
import './libraries/FixedPoint.sol';
import '../gelatoAutomate/OpsReadySol6.sol';
import '../gelatoAutomate/solidity6Utils/OwnableSol6.sol';

interface ERC20 {
  function decimals() external view returns (uint8);
}

/**
 * @notice Calculates the time-weighted average price of an ERC20 token over a
 * period of time.
 * @dev The TWAP is only valid for the duration of the `PERIOD` after calling
 * `update`. After `PERIOD` has elapsed, the TWAP must be recomputed by calling
 * `update` again.
 */
contract UniswapV2TwapOracle is IUniswapV2TwapOracle, OpsReady, OwnableSol6 {
  using FixedPoint for *;

  /// @dev The number of seconds over which the TWAP is calculated.
  uint public immutable PERIOD;

  IUniswapV2Pair public immutable override pair;
  address public immutable token0;
  address public immutable token1;

  uint public price0CumulativeLast;
  uint public price1CumulativeLast;
  uint32 public blockTimestampLast;

  FixedPoint.uq112x112 public price0Average;
  FixedPoint.uq112x112 public price1Average;

  constructor(
    address _ops,
    IUniswapV2Pair _pair,
    uint256 _period
  ) public OpsReady(_ops, address(this)) {
    pair = _pair;
    PERIOD = _period;
    token0 = _pair.token0();
    token1 = _pair.token1();
    price0CumulativeLast = _pair.price0CumulativeLast();
    price1CumulativeLast = _pair.price1CumulativeLast();
    (, , blockTimestampLast) = _pair.getReserves();
  }

  // ======== AUTOMATION FUNCTIONS ========

  function createTask() external override onlyOwner {
    super._createTimeTask(
      block.timestamp,
      10 seconds,
      address(this),
      abi.encode(this.update.selector)
    );
  }

  function cancelTask() external override onlyOwner {
    super._cancelTask();
  }

  // ======== PUBLIC FUNCTIONS ========

  function withdrawFunds() external onlyOwner {
    _withdrawNativeToken(payable(owner()));
  }

  /**
   * @notice Updates the TWAP to the current block. Reverts if the time elapsed
   * since the last update is less than the minimum period.
   */
  function update() external override automatedTask {
    (
      uint price0Cumulative,
      uint price1Cumulative,
      uint32 blockTimestamp
    ) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));

    uint32 timeElapsed = blockTimestamp - blockTimestampLast;
    require(timeElapsed >= PERIOD, 'time elapsed < min period');

    // NOTE: overflow is desired
    /*
        |----b-------------------------a---------|
        0                                     2**256 - 1
        b - a is preserved even if b overflows
        */
    // NOTE: uint -> uint224 cuts off the bits above uint224
    // max uint
    // 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    // max uint244
    // 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    price0Average = FixedPoint.uq112x112(
      uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
    );
    price1Average = FixedPoint.uq112x112(
      uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
    );

    price0CumulativeLast = price0Cumulative;
    price1CumulativeLast = price1Cumulative;
    blockTimestampLast = blockTimestamp;
  }

  /**
   * @notice Computes the time-weighted average price of the token in terms of the other token from pair.
   * @param token The token to compute the TWAP of.
   * @param amountIn The amount of the token to compute the TWAP of.
   * @return amountOut The time-weighted average price of the token in terms of the other token.
   */
  function consult(
    address token,
    uint amountIn
  ) external view override returns (uint amountOut) {
    require(token == token0 || token == token1, 'invalid token');

    if (token == token0) {
      // using FixedPoint for *
      // mul returns uq144x112
      // decode144 decodes uq144x112 to uint144
      amountOut = price0Average.mul(amountIn).decode144();
    } else {
      amountOut = price1Average.mul(amountIn).decode144();
    }
  }

  /**
   * @notice Returns the time-weighted average price of both tokens in the pair.
   * @param tokenA The first token to compute the TWAP of.
   * @return observedATokenPrice The time-weighted average price of tokenA in terms of the other token.
   * @return observedBTokenPrice The time-weighted average price of the other token in terms of tokenA.
   */
  function getObservedPrices(
    address tokenA
  ) external view override returns (uint observedATokenPrice, uint observedBTokenPrice) {
    uint256 token0Price = price0Average
      .mul(10 ** uint256(ERC20(token0).decimals()))
      .decode144();
    uint256 token1Price = price1Average
      .mul(10 ** uint256(ERC20(token1).decimals()))
      .decode144();
    bool isTokenAToken0 = tokenA == token0;
    (observedATokenPrice, observedBTokenPrice) = isTokenAToken0
      ? (token0Price, token1Price)
      : (token1Price, token0Price);
  }

  /**
   * @notice Returns the time-weighted average ratios of prices of both tokens in the pair.
   * @param denominatorToken The token to reduce the prices to.
   * @return observedDenominatorTokenRatio The time-weighted average price of the denominator token,
   * always going to be 10 ** tokenDecimals.
   * @return observedBTokenRatio The time-weighted average price of the other token in terms of the
   * denominator token.
   */
  function getPriceRatios(
    address denominatorToken
  )
    external
    view
    override
    returns (uint observedDenominatorTokenRatio, uint observedBTokenRatio)
  {
    bool isToken0Denominator = token0 == denominatorToken;
    uint denominatorTokenDecimals = uint(ERC20(denominatorToken).decimals());

    observedDenominatorTokenRatio = 10 ** denominatorTokenDecimals;
    observedBTokenRatio = isToken0Denominator
      ? price0Average.mul(10 ** denominatorTokenDecimals).decode144()
      : price1Average.mul(10 ** denominatorTokenDecimals).decode144();
  }
}
