// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../libraries/CurveLPTokenPricing.sol";

contract TestCurveLPTokenPricing {
    function calcA(uint256 D, uint256 A, uint8 n) external pure returns (int256) {
        return CurveLPTokenPricing.calcA(D, A, n);
    }

    function calcB(uint256 D, uint256 A, uint8 n) external pure returns (uint256) {
        return CurveLPTokenPricing.calcB(D, A, n);
    }

    function calcR(uint256 x, uint256 b, int256 a) external pure returns (uint256) {
        return CurveLPTokenPricing.calcR(x, b, a);
    }

    function computeDfSForXAndS(
        uint256 D,
        uint256 A,
        uint256 x,
        uint256 s,
        uint8 n
    ) external pure returns (int256) {
        return CurveLPTokenPricing.computeDfSForXAndS(D, A, x, s, n);
    }

    function computeDDfForX(
        uint256 D,
        uint256 A,
        uint256 x,
        uint8 n
    ) external pure returns (int256) {
        return CurveLPTokenPricing.computeDDfForX(D, A, x, n);
    }

    function nextIter(
        uint256 D,
        uint256 A,
        uint256 x,
        uint256 s,
        uint8 n
    ) external pure returns (uint256) {
        return CurveLPTokenPricing.nextIter(D, A, x, s, n);
    }

    function calcYFromD(uint256 D, uint256 A, uint256 price) external pure returns (uint256) {
        return CurveLPTokenPricing.calcYFromD(D, A, price);
    }

    function calcYFromXCrv(uint256 x, uint256 A, uint256 D) external pure returns (uint256) {
        return CurveLPTokenPricing.calcYFromXCrv(x, A, D);
    }

    function getV1LpTokenPrice(
        ICurvePoolV1 pool,
        uint256 priceA,
        uint256 priceB
    ) external view returns (uint256) {
        return CurveLPTokenPricing.getV1LpTokenPrice(pool, priceA, priceB);
    }
}
