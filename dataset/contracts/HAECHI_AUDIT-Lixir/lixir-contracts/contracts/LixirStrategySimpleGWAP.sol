pragma solidity ^0.7.6;

import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';

import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';

import 'contracts/interfaces/ILixirStrategy.sol';
import 'contracts/interfaces/ILixirVault.sol';
import 'contracts/LixirBase.sol';

contract LixirStrategySimpleGWAP is LixirBase, ILixirStrategy {
  constructor(address _registry) LixirBase(_registry) {}

  mapping(address => VaultData) public vaultDatas;

  /**
   * @notice Struct for containing data pertaining to strategy vaults
   * @param TICK_SHORT_DURATION how long we want to wait to get a TWAP to prevent sandwiching
   * @param MAX_TICK_DIFF check on the short_gwap and expected tick to prevent sandwiching
   * @param mainSpread tick width of the main position
   * @param rangeSpread tick width of the range position
   * @param timestamp keeping track of last time of rebalance or config
   * @param tickCumulative last cumulative tick value from pool
   */
  struct VaultData {
    uint32 TICK_SHORT_DURATION;
    int24 MAX_TICK_DIFF;
    int24 mainSpread;
    int24 rangeSpread;
    uint32 timestamp;
    int56 tickCumulative;
  }

  event VaultConfigUpdate(
    address indexed vault,
    uint32 TICK_SHORT_DURATION,
    int24 MAX_TICK_DIFF,
    int24 mainSpread,
    int24 rangeSpread
  );

  /**
    @notice adds a vault to this strategy contract.
    @dev called externally by the `LixirFactory` when you `createVault`
   */
  function initializeVault(ILixirVault _vault, bytes memory data)
    external
    override
    onlyRole(LixirRoles.factory_role)
  {
    (
      uint24 fee,
      uint32 TICK_SHORT_DURATION,
      int24 MAX_TICK_DIFF,
      int24 mainSpread,
      int24 rangeSpread
    ) = abi.decode(data, (uint24, uint32, int24, int24, int24));
    _configureVault(
      _vault,
      fee,
      TICK_SHORT_DURATION,
      MAX_TICK_DIFF,
      mainSpread,
      rangeSpread
    );
  }

  function setTickShortDuration(ILixirVault _vault, uint32 TICK_SHORT_DURATION)
    external
    onlyRole(LixirRoles.strategist_role)
    hasRole(LixirRoles.vault_role, address(_vault))
  {
    require(msg.sender == _vault.strategist());
    require(
      TICK_SHORT_DURATION >= 30,
      'TICK_SHORT_DURATION must be greater than 30 seconds'
    );
    VaultData storage vaultData = vaultDatas[address(_vault)];
    vaultData.TICK_SHORT_DURATION = TICK_SHORT_DURATION;
    emit VaultConfigUpdate(
      address(_vault),
      TICK_SHORT_DURATION,
      vaultData.MAX_TICK_DIFF,
      vaultData.mainSpread,
      vaultData.rangeSpread
    );
  }

  function setMaxTickDiff(ILixirVault _vault, int24 MAX_TICK_DIFF)
    external
    onlyRole(LixirRoles.strategist_role)
    hasRole(LixirRoles.vault_role, address(_vault))
  {
    require(msg.sender == _vault.strategist());
    require(
      MAX_TICK_DIFF >= 0,
      'MAX_TICK_DIFF must be greater than or equal to 0'
    );
    VaultData storage vaultData = vaultDatas[address(_vault)];
    vaultData.MAX_TICK_DIFF = MAX_TICK_DIFF;
    emit VaultConfigUpdate(
      address(_vault),
      vaultData.TICK_SHORT_DURATION,
      MAX_TICK_DIFF,
      vaultData.mainSpread,
      vaultData.rangeSpread
    );
  }

  /**
    @notice sets the tick width of the main and range positions when rebalancing
   */
  function setSpreads(
    ILixirVault _vault,
    int24 mainSpread,
    int24 rangeSpread
  )
    external
    onlyRole(LixirRoles.strategist_role)
    hasRole(LixirRoles.vault_role, address(_vault))
  {
    require(msg.sender == _vault.strategist());
    require(mainSpread >= 0);
    require(rangeSpread >= 0);
    VaultData storage vaultData = vaultDatas[address(_vault)];
    vaultData.mainSpread = mainSpread;
    vaultData.rangeSpread = rangeSpread;
    emit VaultConfigUpdate(
      address(_vault),
      vaultData.TICK_SHORT_DURATION,
      vaultData.MAX_TICK_DIFF,
      mainSpread,
      rangeSpread
    );
  }

  /**
    @notice function for strategist to set all `VaultData` in one call
   */
  function configureVault(
    ILixirVault _vault,
    uint24 fee,
    uint32 TICK_SHORT_DURATION,
    int24 MAX_TICK_DIFF,
    int24 mainSpread,
    int24 rangeSpread
  )
    external
    onlyRole(LixirRoles.strategist_role)
    hasRole(LixirRoles.vault_role, address(_vault))
  {
    require(msg.sender == _vault.strategist());
    _configureVault(
      _vault,
      fee,
      TICK_SHORT_DURATION,
      MAX_TICK_DIFF,
      mainSpread,
      rangeSpread
    );
  }

  function _configureVault(
    ILixirVault _vault,
    uint24 fee,
    uint32 TICK_SHORT_DURATION,
    int24 MAX_TICK_DIFF,
    int24 mainSpread,
    int24 rangeSpread
  ) internal {
    require(TICK_SHORT_DURATION >= 30);
    require(MAX_TICK_DIFF > 0);
    require(mainSpread >= 0);
    require(rangeSpread >= 0);
    require(_vault.strategy() == address(this), 'Incorrect vault strategy');
    VaultData storage vaultData = vaultDatas[address(_vault)];
    vaultData.TICK_SHORT_DURATION = TICK_SHORT_DURATION;
    vaultData.MAX_TICK_DIFF = MAX_TICK_DIFF;
    vaultData.mainSpread = mainSpread;
    vaultData.rangeSpread = rangeSpread;
    if (
      block.timestamp - vaultData.timestamp > 60 * 60 * 24 ||
      fee != _vault.activeFee()
    ) {
      IUniswapV3Pool newPool = IUniswapV3Pool(
        PoolAddress.computeAddress(
          registry.uniV3Factory(),
          PoolAddress.getPoolKey(
            address(_vault.token0()),
            address(_vault.token1()),
            fee
          )
        )
      );
      (int24 short_gwap, int56 lastShortTicksCumulative) = getTickShortGwap(
        newPool,
        TICK_SHORT_DURATION
      );
      vaultData.tickCumulative = lastShortTicksCumulative;
      vaultData.timestamp = uint32(block.timestamp - TICK_SHORT_DURATION);
      (uint160 sqrtRatioX96, int24 tick) = getSqrtRatioX96AndTick(newPool);
      // neither check tick nor _rebalance read timestamp or tickCumulative
      // so we don't have to update the cache
      checkTick(tick, short_gwap, vaultData.MAX_TICK_DIFF);
      emit VaultConfigUpdate(
        address(_vault),
        TICK_SHORT_DURATION,
        MAX_TICK_DIFF,
        mainSpread,
        rangeSpread
      );
      _rebalance(
        _vault,
        newPool,
        sqrtRatioX96,
        tick,
        short_gwap,
        mainSpread,
        rangeSpread
      );
    }
  }

  /**
    @dev Calculates short term TWAP for rebalance sanity checks
    @return tick_gwap short term TWAP
   */
  function getTickShortGwap(IUniswapV3Pool pool, uint32 TICK_SHORT_DURATION)
    internal
    view
    returns (int24 tick_gwap, int56 lastShortTicksCumulative)
  {
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = TICK_SHORT_DURATION;
    secondsAgos[1] = 0;
    (int56[] memory ticksCumulative, ) = pool.observe(secondsAgos);
    lastShortTicksCumulative = ticksCumulative[0];
    // compute the time weighted tick, rounded towards negative infinity
    int56 numerator = (ticksCumulative[1] - lastShortTicksCumulative);
    int56 timeWeightedTick = numerator / int56(TICK_SHORT_DURATION);
    if (numerator < 0 && numerator % int56(TICK_SHORT_DURATION) != 0) {
      timeWeightedTick--;
    }
    tick_gwap = int24(timeWeightedTick);
    require(int56(tick_gwap) == timeWeightedTick, 'Tick over/underflow');
  }

  /**
    @dev Sanity checks on current tick, expected tick from keeper, and GWAP tick
    @param expectedTick Expected tick passed by keeper
   */
  function checkTick(
    int24 tick,
    int24 expectedTick,
    int24 MAX_TICK_DIFF
  ) internal pure {
    int24 diff = expectedTick >= tick
      ? expectedTick - tick
      : tick - expectedTick;
    require(diff <= MAX_TICK_DIFF, 'Tick diff to great');
  }

  function getMainTicks(
    int24 tick_gwap,
    int24 tickSpacing,
    int24 spread
  ) internal pure returns (int24 lower, int24 upper) {
    lower = roundTickDown(tick_gwap - spread, tickSpacing);
    upper = roundTickUp(tick_gwap + spread, tickSpacing);
    require(lower < upper, 'Main ticks are the same');
  }

  function getRangeTicks(
    uint160 sqrtRatioX96,
    int24 tick,
    int24 tickSpacing,
    int24 spread
  )
    internal
    pure
    returns (
      int24 lower0,
      int24 upper0,
      int24 lower1,
      int24 upper1
    )
  {
    lower0 = roundTickUp(
      (TickMath.getSqrtRatioAtTick(tick) == sqrtRatioX96) ? tick : tick + 1,
      tickSpacing
    );
    upper0 = roundTickUp(lower0 + spread, tickSpacing);

    upper1 = roundTickDown(tick, tickSpacing);
    lower1 = roundTickDown(upper1 - spread, tickSpacing);
    require(lower0 < upper0, 'Range0 ticks are the same');
    require(lower1 < upper1, 'Range1 ticks are the same');
  }

  /**
    @dev Calculates long term TWAP for setting ranges
    @return tick_gwap Long term TWAP
   */
  function getTickGwapUpdateCumulative(
    IUniswapV3Pool pool,
    VaultData storage vaultData
  ) internal returns (int24 tick_gwap) {
    uint32[] memory secondsAgos = new uint32[](1);
    secondsAgos[0] = 0;
    (int56[] memory ticksCumulative, ) = pool.observe(secondsAgos);
    int56 tickCumulative = ticksCumulative[0];
    // compute the time weighted tick, rounded towards negative infinity
    int56 numerator = (tickCumulative - vaultData.tickCumulative);
    int56 secondsAgo = int56(block.timestamp - vaultData.timestamp);
    int56 timeWeightedTick = numerator / secondsAgo;
    if (numerator < 0 && numerator % secondsAgo != 0) {
      timeWeightedTick--;
    }
    tick_gwap = int24(timeWeightedTick);
    require(int56(tick_gwap) == timeWeightedTick, 'Tick over/underflow');
    vaultData.timestamp = uint32(block.timestamp);
    vaultData.tickCumulative = tickCumulative;
  }

  /**
    @notice rebalances the vault to the given tick. In the process
    it collects UniV3 fees and repools them.
    @dev only keeper role can call

   */
  function rebalance(ILixirVault vault, int24 expectedTick)
    external
    hasRole(LixirRoles.vault_role, address(vault))
    onlyRole(LixirRoles.keeper_role)
  {
    VaultData storage vaultData = vaultDatas[address(vault)];
    require(vaultData.timestamp > 0);
    IUniswapV3Pool pool = vault.activePool();
    (int24 short_gwap, ) = getTickShortGwap(
      pool,
      vaultData.TICK_SHORT_DURATION
    );
    (uint160 sqrtRatioX96, int24 tick) = getSqrtRatioX96AndTick(pool);
    int24 MAX_TICK_DIFF = vaultData.MAX_TICK_DIFF;
    checkTick(tick, short_gwap, MAX_TICK_DIFF);
    checkTick(tick, expectedTick, MAX_TICK_DIFF);
    int24 tick_gwap = getTickGwapUpdateCumulative(pool, vaultData);
    _rebalance(
      vault,
      pool,
      sqrtRatioX96,
      tick,
      tick_gwap,
      vaultData.mainSpread,
      vaultData.rangeSpread
    );
  }

  function _rebalance(
    ILixirVault vault,
    IUniswapV3Pool pool,
    uint160 sqrtRatioX96,
    int24 tick,
    int24 tick_gwap,
    int24 mainSpread,
    int24 rangeSpread
  ) internal {
    int24 mlower;
    int24 mupper;
    int24 rlower0;
    int24 rupper0;
    int24 rlower1;
    int24 rupper1;
    uint24 fee;
    {
      int24 tickSpacing = pool.tickSpacing();
      (mlower, mupper) = getMainTicks(tick_gwap, tickSpacing, mainSpread);
      (rlower0, rupper0, rlower1, rupper1) = getRangeTicks(
        sqrtRatioX96,
        tick,
        tickSpacing,
        rangeSpread
      );
      fee = pool.fee();
    }
    vault.rebalance(mlower, mupper, rlower0, rupper0, rlower1, rupper1, fee);
  }

  /**
   * @dev Queries activePool for current square root price and current tick
   * @return _sqrtRatioX96 Current square root price
   * @return _tick Current tick
   */
  function getSqrtRatioX96AndTick(IUniswapV3Pool pool)
    internal
    view
    returns (uint160 _sqrtRatioX96, int24 _tick)
  {
    (_sqrtRatioX96, _tick, , , , , ) = pool.slot0();
  }

  function max(int24 x, int24 y) internal pure returns (int24) {
    return y < x ? x : y;
  }

  function min(int24 x, int24 y) internal pure returns (int24) {
    return x < y ? x : y;
  }

  function roundTickDown(int24 tick, int24 tickSpacing)
    internal
    pure
    returns (int24)
  {
    int24 tickMod = tick % tickSpacing;
    int24 roundedTick;
    if (tickMod == 0) {
      roundedTick = tick;
    } else if (0 < tick) {
      roundedTick = tick - tickMod;
    } else {
      roundedTick = tick - tickSpacing + (-tickMod);
    }
    return max(roundedTick, TickMath.MIN_TICK);
  }

  function roundTickUp(int24 tick, int24 tickSpacing)
    internal
    pure
    returns (int24)
  {
    int24 tickDown = roundTickDown(tick, tickSpacing);
    return
      min(tick == tickDown ? tick : tickDown + tickSpacing, TickMath.MAX_TICK);
  }
}
