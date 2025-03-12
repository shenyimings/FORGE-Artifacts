// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./FixedPointMath.sol";
import "./Math.sol";
import {IERC20} from "./../interfaces/ERC20.sol";
import {IPriceOracle} from "./../interfaces/IPriceOracle.sol";

library Loan {
    using FixedPointMath for uint256;

    struct Data {
        uint256 id;
        bool isActive;
        address borrower;
        IERC20 collateralToken;
        bool isNativeCurrency;
        IPriceOracle priceOracle;
        uint256 interest;
        uint256 stabilizationFee;
        uint256 principalAmount;
        uint256 interestAmount;
        uint256 collateralAmount;
        uint256 lastInteractionAt;
    }

    uint256 internal constant ONE = 100e16;
    uint256 internal constant SECONDS_PER_YEAR = 31536000;

    function accrueInterest(Data storage self) internal {
        self.interestAmount += calculateInterest(self);
    }

    function calculateInterest(Data memory self) internal view returns (uint256 interest) {
        interest = self.principalAmount.mul(self.interest).mul(
            (block.timestamp - self.lastInteractionAt).mulDiv(ONE, SECONDS_PER_YEAR)
        );
    }

    function getCollateralValue(Data memory self) internal view returns (uint256 collateralValue) {
        uint256 collateralTokenPrice = self.priceOracle.getNormalizedPrice(self.collateralToken);
        collateralValue = self.collateralAmount.mul(collateralTokenPrice);
    }

    function calculateLoanToValueRatio(Data memory self) internal view returns (uint256 loanToValueRatio) {
        if (self.principalAmount == 0) {
            return 0;
        }
        if (self.collateralAmount == 0) {
            return type(uint256).max;
        }

        loanToValueRatio = (self.principalAmount + calculateInterest(self)).div(getCollateralValue(self));
    }
}
