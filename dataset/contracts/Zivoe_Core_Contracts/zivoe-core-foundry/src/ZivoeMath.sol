// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "./libraries/FloorMath.sol";



/// @notice  This contract facilitates mathematics, intended solely for the YDL.
contract ZivoeMath {

    using FloorMath for uint256;

    // ---------------------
    //    State Variables
    // ---------------------

    uint256 private constant BIPS = 10000;
    uint256 private constant WAD = 10 ** 18;
    uint256 private constant RAY = 10 ** 27;



    // ----------
    //    Math
    // ----------

    /**
        @notice     Calculates the current EMA (exponential moving average).
        @dev        M * cV + (1 - M) * bV, where our smoothing factor M = 2 / (N + 1)
        @param      bV  = The base value (typically an EMA from prior calculations).
        @param      cV  = The current value, which is factored into bV.
        @param      N   = Number of steps to average over.
        @return     eV  = EMA-based value given prior and current conditions.
    */
    function ema(uint256 bV, uint256 cV, uint256 N) external pure returns (uint256 eV) {
        uint256 M = (WAD * 2).floorDiv(N + 1);
        eV = ((M * cV) + (WAD - M) * bV).floorDiv(WAD);
    }

    /**
        @notice     Calculates proportion of yield attributable to junior tranche.
        @dev        (Q * eJTT * sP / BIPS).floorDiv(eSTT).min(RAY - sP)
        @param      eSTT = ema-based supply of zSTT                     (units = WEI)
        @param      eJTT = ema-based supply of zJTT                     (units = WEI)
        @param      sP   = Proportion of yield attributable to seniors  (units = RAY)
        @param      Q    = senior to junior tranche target ratio        (units = BIPS)
        @return     jP   = Yield attributable to junior tranche in RAY.
        @dev        Precision of return value, jP, is in RAY (10**27).
        @dev        The return value for this equation MUST never exceed RAY (10**27).
    */
    function juniorProportion(uint256 eSTT, uint256 eJTT, uint256 sP, uint256 Q) external pure returns (uint256 jP) {
        if (sP <= RAY) { jP = (Q * eJTT * sP / BIPS).floorDiv(eSTT).min(RAY - sP); }
    }

    /**
        @notice     Calculates proportion of yield distributble which is attributable to the senior tranche.
        @param      yD   = yield distributable                      (units = WEI)
        @param      yT   = ema-based yield target                   (units = WEI)
        @param      eSTT = ema-based supply of zSTT                 (units = WEI)
        @param      eJTT = ema-based supply of zJTT                 (units = WEI)
        @param      Y    = target annual yield for senior tranche   (units = BIPS)
        @param      Q    = multiple of Y                            (units = BIPS)
        @param      T    = # of days between distributions          (units = integer)
        @return     sP   = Proportion of yD attributable to senior tranche.
        @dev        Precision of return value, sP, is in RAY (10**27).
    */
    function seniorProportion(
        uint256 yD, uint256 yT, uint256 eSTT, uint256 eJTT, uint256 Y, uint256 Q, uint256 T
    ) external pure returns (uint256 sP) {
        // Shortfall of yield.
        if (yD < yT) { sP = seniorProportionShortfall(eSTT, eJTT, Q); } 
        // Excess yield and historical out-performance.
        else { sP = seniorProportionBase(yD, eSTT, Y, T); }
    }

    // NOTE: The following three functions could be marked internal, but are marked public for testing.

    /**
        @notice     Calculates proportion of yield attributed to senior tranche (no extenuating circumstances).
        @dev          Y  * eSTT * T
                    ----------------- *  RAY
                        (365) * yD
        @param      yD   = yield distributable                      (units = WEI)
        @param      eSTT = ema-based supply of zSTT                 (units = WEI)
        @param      Y    = target annual yield for senior tranche   (units = BIPS)
        @param      T    = # of days between distributions          (units = integer)
        @return     sPB  = Proportion of yield attributed to senior tranche in RAY.
        @dev        Precision of return value, sRB, is in RAY (10**27).
    */
    function seniorProportionBase(uint256 yD, uint256 eSTT, uint256 Y, uint256 T) public pure returns (uint256 sPB) {
        sPB = ((RAY * Y * (eSTT) * T / BIPS) / 365).floorDiv(yD).min(RAY);
    }

    /**
        @notice     Calculates proportion of yield attributed to senior tranche (shortfall occurence).
        @dev                     WAD
                   --------------------------------  *  RAY
                             Q * eJTT * WAD / BIPS      
                    WAD  +   ---------------------
                                     eSTT
        @param      eSTT = ema-based supply of zSTT                 (units = WEI)
        @param      eJTT = ema-based supply of zJTT                 (units = WEI)
        @param      Q    = senior to junior tranche target ratio    (units = integer)
        @return     sPS  = Proportion of yield attributed to senior tranche in RAY.
        @dev        Precision of return value, sPS, is in RAY (10**27).
    */
    function seniorProportionShortfall(uint256 eSTT, uint256 eJTT, uint256 Q) public pure returns (uint256 sPS) {
        sPS = (WAD * RAY).floorDiv(WAD + (Q * eJTT * WAD / BIPS).floorDiv(eSTT)).min(RAY);
    }

    /**
        @notice     Calculates amount of annual yield required to meet target rate for both tranches.
        @dev        (Y * T * (eSTT + eJTT * Q / BIPS) / BIPS) / 365
        @param      eSTT = ema-based supply of zSTT                  (units = WEI)
        @param      eJTT = ema-based supply of zJTT                  (units = WEI)
        @param      Y    = target annual yield for senior tranche   (units = BIPS)
        @param      Q    = multiple of Y                            (units = BIPS)
        @param      T    = # of days between distributions          (units = integer)
        @return     yT   = yield target for the senior and junior tranche combined.
        @dev        Precision of the return value, yT, is in WEI (10**18).
    */
    function yieldTarget(uint256 eSTT, uint256 eJTT, uint256 Y, uint256 Q, uint256 T) public pure returns (uint256 yT) {
        yT = (Y * T * (eSTT + eJTT * Q / BIPS) / BIPS) / 365;
    }

}
