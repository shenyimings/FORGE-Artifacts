// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// libraries
import {LiquidityModuleLib as LML} from "./LiquidityModuleLib.sol";

/**
 * @title AL: Amplification Library
 *
 * @notice A helper library for Liquidity Module Library (LML) to calculate and ramp the A parameter of a given `LiquidityModuleLib.Swap` struct.
 *
 * @dev review: Liquidity Module for the StableSwap logic.
 * @dev This library assumes the LML.Swap struct is fully validated.
 *
 * @dev This is an internal library, requires NO deployment.
 *
 * @author Ice Bear & Crash Bandicoot
 */
library AmplificationLib {
  /**
   * @custom:section                           ** CONSTANTS **
   */
  uint256 public constant A_PRECISION = 100;
  uint256 public constant MAX_A = 10 ** 6;
  uint256 public constant MAX_A_CHANGE = 2;
  uint256 public constant MIN_RAMP_TIME = 14 days;

  /**
   * @custom:section                           ** EVENTS **
   */
  event RampA(uint256 oldA, uint256 newA, uint256 initialTime, uint256 futureTime);
  event StopRampA(uint256 currentA, uint256 time);

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   *
   * @custom:visibility -> view-internal
   */

  /**
   * @notice Return A, the amplification coefficient * n * (n - 1)
   * @dev See the StableSwap paper for details
   * @param self Swap struct to read from
   * @return A parameter
   */
  function getA(LML.Swap storage self) internal view returns (uint256) {
    return _getAPrecise(self) / (A_PRECISION);
  }

  /**
   * @notice Return A in its raw precision
   * @dev See the StableSwap paper for details
   * @param self Swap struct to read from
   * @return A parameter in its raw precision form
   */
  function getAPrecise(LML.Swap storage self) internal view returns (uint256) {
    return _getAPrecise(self);
  }

  /**
   * @notice Return A in its raw precision
   * @dev See the StableSwap paper for details
   * @param self Swap struct to read from
   * @return A parameter in its raw precision form
   */
  function _getAPrecise(LML.Swap storage self) internal view returns (uint256) {
    uint256 t1 = self.futureATime; // time when ramp is finished
    uint256 a1 = self.futureA; // final A value when ramp is finished

    if (block.timestamp < t1) {
      uint256 t0 = self.initialATime; // time when ramp is started
      uint256 a0 = self.initialA; // initial A value when ramp is started
      if (a1 > a0) {
        // a0 + (a1 - a0) * (block.timestamp - t0) / (t1 - t0)
        return a0 + ((a1 - a0) * (block.timestamp - t0)) / (t1 - t0);
      } else {
        // a0 - (a0 - a1) * (block.timestamp - t0) / (t1 - t0)
        return a0 - ((a0 - a1) * (block.timestamp - t0)) / (t1 - t0);
      }
    } else {
      return a1;
    }
  }

  /**
   * @custom:section                           ** SETTER FUNCTIONS **
   *
   * @custom:visibility -> internal
   */

  /**
   * @notice Start ramping up or down A parameter towards given futureA_ and futureTime_
   * Checks if the change is too rapid, and commits the new A value only when it falls under
   * the limit range.
   * @param self Swap struct to update
   * @param futureA_ the new A to ramp towards
   * @param futureTime_ timestamp when the new A should be reached
   */
  function rampA(LML.Swap storage self, uint256 futureA_, uint256 futureTime_) internal {
    require(block.timestamp >= self.initialATime + 1 days, "AL:Wait 1 day before starting ramp");
    require(futureTime_ >= block.timestamp + MIN_RAMP_TIME, "AL:Insufficient ramp time");
    require(futureA_ > 0 && futureA_ < MAX_A, "AL:futureA_ must be > 0 and < MAX_A");

    uint256 initialAPrecise = _getAPrecise(self);
    uint256 futureAPrecise = futureA_ * A_PRECISION;

    if (futureAPrecise < initialAPrecise) {
      require(futureAPrecise * MAX_A_CHANGE >= initialAPrecise, "AL:futureA_ is too small");
    } else {
      require(futureAPrecise <= initialAPrecise * MAX_A_CHANGE, "AL:futureA_ is too large");
    }

    self.initialA = initialAPrecise;
    self.futureA = futureAPrecise;
    self.initialATime = block.timestamp;
    self.futureATime = futureTime_;

    emit RampA(initialAPrecise, futureAPrecise, block.timestamp, futureTime_);
  }

  /**
   * @notice Stops ramping A immediately. Once this function is called, rampA()
   * cannot be called for another 24 hours
   * @param self Swap struct to update
   */
  function stopRampA(LML.Swap storage self) internal {
    require(self.futureATime > block.timestamp, "AL:Ramp is already stopped");

    uint256 currentA = _getAPrecise(self);
    self.initialA = currentA;
    self.futureA = currentA;
    self.initialATime = block.timestamp;
    self.futureATime = block.timestamp;

    emit StopRampA(currentA, block.timestamp);
  }
}
