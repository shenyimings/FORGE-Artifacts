// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { SafeCastUpgradeable } from "@openzeppelin-upgradeable/utils/math/SafeCastUpgradeable.sol";

// libraries
import { LibFullMath } from "src/libraries/LibFullMath.sol";
import { LibFixedPoint96 } from "src/libraries/LibFixedPoint96.sol";

library LibSqrtPriceX96 {
  using SafeCastUpgradeable for uint256;

  /// @notice Decode qqrtPriceX96 to price token0 / token1 in 18 decimals.
  /// @param _sqrtPriceX96 sqrtPriceX96.
  /// @param _token0Decimals token 0 decimals.
  /// @param _token1Decimals token 1 decimals.
  /// @return _priceE18 decoded sqrtPriceX96 in 18 decimals.
  /// @dev priceE18 = (sqrtPriceX96 / 2**96)**2 * (10**token0Decimals) * 1e18 / (10**token1Decimals)
  /// return 1e18 as decoded price is to be used in calculations.
  function decodeSqrtPriceX96(uint160 _sqrtPriceX96, uint256 _token0Decimals, uint256 _token1Decimals)
    internal
    pure
    returns (uint256 _priceE18)
  {
    uint256 _non18Price = LibFullMath.mulDiv(uint256(_sqrtPriceX96) * 1e18, _sqrtPriceX96, LibFixedPoint96.Q96 ** 2);
    return _non18Price * (10 ** _token0Decimals) / (10 ** _token1Decimals);
  }

  /// @notice Encode priceE18 into estimated sqrtPriceX96 according to token0,1 decimals.
  /// @param _priceE18 Price token0 / token1 in 18 decimals.
  /// @param _token0Decimals token 0 decimals.
  /// @param _token1Decimals token 1 decimals.
  /// @return _sqrtPriceX96 estimated sqrtPriceX96.
  /// @dev sqrtPriceX96 = sqrt(priceE18 * (10**token1Decimals) / (10**(token0Decimals + 18))) * (2**96)
  /// sqrt calculation use estimation so there is minor precision loss.
  function encodeSqrtPriceX96(uint256 _priceE18, uint256 _token0Decimals, uint256 _token1Decimals)
    internal
    pure
    returns (uint160 _sqrtPriceX96)
  {
    uint256 _sqrt = FixedPointMathLib.sqrt(_priceE18 * (10 ** _token1Decimals) / (10 ** _token0Decimals));
    // 1e9 due to taking 1e18 out of sqrt to avoid precision loss
    return (_sqrt * LibFixedPoint96.Q96 / 1e9).toUint160();
  }
}
