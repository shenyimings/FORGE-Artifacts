// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./Deposit.sol";
import "./FixedPointMath.sol";
import {IERC20} from "./../interfaces/ERC20.sol";
import {IPriceOracle} from "./../interfaces/IPriceOracle.sol";

library Pool {
    using FixedPointMath for uint256;

    struct Data {
        uint256 id;
        IERC20 depositToken;
        IPriceOracle priceOracle;
        bool isCompounding;
        uint256 depositsAmount;
        uint256 depositorApr;
        uint256 magisterApr;
        uint256 depositorBonusApr;
        uint256 magisterBonusApr;
    }

    uint256 internal constant ONE = 100e16;
    uint256 internal constant SECONDS_PER_YEAR = 31536000;

    function getDepositsValue(Data memory self) internal view returns (uint256 depositsValue) {
        if (self.depositsAmount == 0) {
            return 0;
        }

        uint256 depositTokenPrice = self.priceOracle.getNormalizedPrice(self.depositToken);
        depositsValue = self.depositsAmount.mul(depositTokenPrice);
    }

    function calculateMultiplier(
        Data memory self,
        uint256 apr,
        uint256 fee,
        uint256 timeDelta
    ) internal pure returns (uint256 multiplier) {
        if (!self.isCompounding) {
            multiplier = apr.mul(timeDelta.mulDiv(ONE, SECONDS_PER_YEAR));
        } else {
            multiplier =
                FixedPointMath.pow(ONE + (ONE - fee).mul(apr).div(SECONDS_PER_YEAR * ONE), timeDelta * ONE) -
                ONE;
        }
    }

    function getDepositorApr(Data memory self) internal pure returns (uint256 depositorApr) {
        depositorApr = self.depositorApr + self.depositorBonusApr;
    }

    function getMagisterApr(Data memory self) internal pure returns (uint256 magisterApr) {
        magisterApr = self.magisterApr + self.magisterBonusApr;
    }

    function getTotalApr(Data memory self) internal pure returns (uint256 totalApr) {
        totalApr = getDepositorApr(self) + getMagisterApr(self);
    }
}
