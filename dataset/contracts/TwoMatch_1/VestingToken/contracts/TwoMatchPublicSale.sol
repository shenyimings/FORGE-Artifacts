// SPDX-License-Identifier: BSD Protection License
pragma solidity 0.8.17;

import './Vesting.sol';
import './IBEP20.sol';

interface IUniswapV3Pool {
  function slot0()
    external
    view
    returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
  /// @notice The first of the two tokens of the pool, sorted by address
  /// @return The token contract address
  function token0() external view returns (address);

  /// @notice The second of the two tokens of the pool, sorted by address
  /// @return The token contract address
  function token1() external view returns (address);
}

contract TwoMatchPublicSale {
  address public uniswapV3PoolAddress;
  address private immutable owner;
  address private immutable liquidityProvider;
  bool private isFirstRelease = true;
  bool private isStarted;

  IBEP20 tmToken;

  TwoMatchVesting public immutable vestingContract;

  mapping (uint => bool) isTokenLiquidityClaimedByRate;

  constructor (address vestingContractAddress, address tmTokenAddress, address liquidityProviderAddress) {
    tmToken = IBEP20(tmTokenAddress);
    liquidityProvider = liquidityProviderAddress;
    vestingContract = TwoMatchVesting(vestingContractAddress);
    owner = msg.sender;
  }

  function getExchangeRate () internal view returns (uint) {
    IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3PoolAddress);
    (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

    uint rate = (sqrtPriceX96 * sqrtPriceX96 * 1e18) >> (96 * 2); 

    uint8 decimals0 = IBEP20(pool.token0()).decimals();
    uint8 decimals1 = IBEP20(pool.token1()).decimals();

    return (decimals1 * 1e18) / (decimals0 * rate);
  }


  function start () external {
    require(uniswapV3PoolAddress != address(0), 'TM Public sale: Cannot start distribution without uniswap pair address');
    require(tmToken.balanceOf(address(this)) >= 10_000_000 ether);
    vestingContract.tokenGenerationEvent();
  }

  function changePairAddress (address pairAddress) external {
    require(msg.sender == owner, 'TM Public sale: Only owner can execute this function');
    require(uniswapV3PoolAddress == address(0), 'TM Public sale: Pair address cannot be changed after it has been set');
    
    uniswapV3PoolAddress = pairAddress;
  }

  bool public isFirstStageClaimed;
  bool public isSecondStageClaimed;
  bool public isThridStageClaimed;
  bool public isFourthStageClaimed;
  bool public isFifthStageClaimed;
  bool public isSixthStageClaimed;
  bool public isSeventhStageClaimed;

  function releaseLiquidity () external {
    require(isStarted, 'TM Public sale: Cannot release liquidity before start');

    uint releaseAmount;
    uint exchangeRateMultiplied = getExchangeRate() * 10;

    if (isFirstRelease) {
      isFirstRelease = false;
      releaseAmount += 333_333 ether;
    }
    
    // 1.2 USDT - 666.666 TM
    if (exchangeRateMultiplied >= 12 ether && !isFirstStageClaimed) {
      isFirstStageClaimed = true;
      releaseAmount += 666_666 ether;
    }


    // 2.2 USDT - 999.999 TM
    if (exchangeRateMultiplied >= 22 ether && !isSecondStageClaimed) {
      isSecondStageClaimed = true;
      releaseAmount += 999_999 ether;
    }

    // 4.4 USDT - 1.333.332 TM
    if (exchangeRateMultiplied >= 44 ether && !isThridStageClaimed) {
      isThridStageClaimed = true;
      releaseAmount += 1_333_332 ether;
    }

    // 8.8 USDT - 1.666.665 TM
    if (exchangeRateMultiplied >= 88 ether && !isFourthStageClaimed) {
      isFourthStageClaimed = true;
      releaseAmount += 1_666_665 ether;
    }

    // 17 USDT - 1.999.999 TM
    if (exchangeRateMultiplied >= 170 ether && !isFifthStageClaimed) {
      isFifthStageClaimed = true;
      releaseAmount += 1_999_999 ether;
    }
    // 32 USDT - 2.333.332 TM
    if (exchangeRateMultiplied >= 320 ether && !isSixthStageClaimed) {
      isSixthStageClaimed = true;
      releaseAmount += 2_333_332 ether;
    }

    // 64 USDT - 666.674 TM
    if (exchangeRateMultiplied >= 640 ether && !isSeventhStageClaimed) {
      isSeventhStageClaimed = true;
      releaseAmount += 666_674 ether;
    }

    if (releaseAmount > 0) {
      tmToken.transfer(liquidityProvider, releaseAmount);
    }
  }

  function withdrawCoinBalance () external onlyOwner {
    payable(owner).transfer(address(this).balance);
  }

  modifier onlyOwner () {
    require(
      msg.sender == owner,
      'Only owner can call this method'
    ); _;
  }
}

// * 0   USDT - 333,333 TM
// * 1.2 USDT - 666,666 TM
// * 2.2 USDT - 999,999 TM
// * 4.4 USDT - 1,333,332 TM
// * 8.8 USDT - 1,666,665 TM
// * 17  USDT - 1,999,999 TM
// * 32  USDT - 2,333,332 TM
// * 64  USDT - 666,674 TM