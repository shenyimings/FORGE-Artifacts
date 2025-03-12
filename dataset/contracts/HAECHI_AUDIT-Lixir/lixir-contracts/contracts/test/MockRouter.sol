pragma solidity ^0.7.6;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol';
import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';
import 'contracts/test/TestERC20.sol';

contract MockRouter is IUniswapV3MintCallback, IUniswapV3SwapCallback {
  /// @notice Add liquidity to an initialized pool
  function mint(
    IUniswapV3Pool pool,
    uint128 liquidity,
    int24 tickLower,
    int24 tickUpper
  ) external {
    pool.mint(
      address(this),
      tickLower,
      tickUpper,
      liquidity,
      abi.encode(msg.sender)
    );
  }

  /// @notice Add liquidity to an initialized pool
  function mintAmounts(
    IUniswapV3Pool pool,
    uint256 amount0,
    uint256 amount1,
    int24 tickLower,
    int24 tickUpper
  ) external returns (uint256 amount0Out, uint256 amount1Out) {
    (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
    (amount0Out, amount1Out) = pool.mint(
      address(this),
      tickLower,
      tickUpper,
      LiquidityAmounts.getLiquidityForAmounts(
        sqrtRatioX96,
        TickMath.getSqrtRatioAtTick(tickLower),
        TickMath.getSqrtRatioAtTick(tickUpper),
        amount0,
        amount1
      ),
      abi.encode(msg.sender)
    );
  }

  function burn(
    IUniswapV3Pool pool,
    uint128 liquidity,
    int24 tickLower,
    int24 tickUpper
  ) external returns (uint256 amount0, uint256 amount1) {
    pool.burn(tickLower, tickUpper, liquidity);
    (amount0, amount1) = pool.collect(
      address(this),
      tickLower,
      tickUpper,
      type(uint128).max,
      type(uint128).max
    );
  }

  /// @inheritdoc IUniswapV3MintCallback
  function uniswapV3MintCallback(
    uint256 amount0Owed,
    uint256 amount1Owed,
    bytes calldata
  ) external override {
    TestERC20(IUniswapV3Pool(msg.sender).token0()).mint(
      msg.sender,
      amount0Owed
    );
    TestERC20(IUniswapV3Pool(msg.sender).token1()).mint(
      msg.sender,
      amount1Owed
    );
  }

  function swap(
    IUniswapV3Pool pool,
    bool zeroForOne,
    int256 amount
  ) external returns (int256 amount0, int256 amount1) {
    (amount0, amount1) = pool.swap(
      msg.sender,
      zeroForOne,
      amount,
      zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
      abi.encode(msg.sender)
    );
  }


  function swapLimit(
    IUniswapV3Pool pool,
    bool zeroForOne,
    int256 amount,
    uint160 sqrtPriceX96Limit
  ) external returns (int256 amount0, int256 amount1) {
    (amount0, amount1) = pool.swap(
      msg.sender,
      zeroForOne,
      amount,
      sqrtPriceX96Limit,
      abi.encode(msg.sender)
    );
  }

  /// @inheritdoc IUniswapV3SwapCallback
  function uniswapV3SwapCallback(
    int256 amount0Delta,
    int256 amount1Delta,
    bytes calldata data
  ) external override {
    address swapper = abi.decode(data, (address));
    if (amount0Delta > 0) {
      TestERC20(IUniswapV3Pool(msg.sender).token0()).transferFrom(
        swapper,
        address(msg.sender),
        uint256(amount0Delta)
      );
    } else {
      require(amount1Delta >= 0);
      TestERC20(IUniswapV3Pool(msg.sender).token1()).transferFrom(
        swapper,
        address(msg.sender),
        uint256(amount1Delta)
      );
    }
  }
}
