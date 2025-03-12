// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./FixedPointMath.sol";
import "./Loan.sol";
import {IERC20} from "./../interfaces/ERC20.sol";
import {IPriceOracle} from "./../interfaces/IPriceOracle.sol";

library CollateralToken {
    using FixedPointMath for uint256;

    struct Data {
        IERC20 collateralToken;
        IPriceOracle priceOracle;
        uint256 stabilityFee;
        uint256 stabilizationFee;
        uint256 exchangeFee;
        uint256 developmentFee;
        uint256 initialLoanToValueRatio;
        uint256 marginCallLoanToValueRatio;
        uint256 liquidationLoanToValueRatio;
        uint256 collateralAmount;
    }

    uint256 internal constant ONE = 100e16;

    function calculateLoanByPrincipalAmount(Data memory self, uint256 principalAmount)
        internal
        view
        returns (
            Loan.Data memory loan,
            uint256 exchangeFee,
            uint256 developmentFee,
            uint256 stabilityFee
        )
    {
        uint256 collateralTokenPrice = self.priceOracle.getNormalizedPrice(self.collateralToken);

        uint256 restOfIssuance = principalAmount.mul(ONE - self.initialLoanToValueRatio).div(
            self.initialLoanToValueRatio
        );
        uint256 stabilizationFee = restOfIssuance.mul(self.stabilizationFee);
        exchangeFee = restOfIssuance.mul(self.exchangeFee);
        developmentFee = restOfIssuance.mul(self.developmentFee);

        uint256 collateralAmount = principalAmount.div(self.initialLoanToValueRatio.mul(collateralTokenPrice));
        stabilityFee = self.stabilityFee.mul(principalAmount).div(collateralTokenPrice);

        loan = Loan.Data({
            id: 0,
            isActive: true,
            borrower: msg.sender,
            collateralToken: self.collateralToken,
            isNativeCurrency: false,
            priceOracle: self.priceOracle,
            interest: 0,
            stabilizationFee: stabilizationFee,
            principalAmount: principalAmount,
            interestAmount: 0,
            collateralAmount: collateralAmount,
            lastInteractionAt: block.timestamp
        });
    }

    function calculateLoanByCollateralAmount(Data memory self, uint256 collateralAmount)
        internal
        view
        returns (
            Loan.Data memory loan,
            uint256 exchangeFee,
            uint256 developmentFee,
            uint256 stabilityFee
        )
    {
        uint256 collateralTokenPrice = self.priceOracle.getNormalizedPrice(self.collateralToken);
        uint256 principalAmount = collateralAmount.mul(self.initialLoanToValueRatio).mul(collateralTokenPrice);

        uint256 restOfIssuance = principalAmount.mul(ONE - self.initialLoanToValueRatio).div(
            self.initialLoanToValueRatio
        );
        uint256 stabilizationFee = restOfIssuance.mul(self.stabilizationFee);
        exchangeFee = restOfIssuance.mul(self.exchangeFee);
        developmentFee = restOfIssuance.mul(self.developmentFee);

        stabilityFee = self.stabilityFee.mul(principalAmount).div(collateralTokenPrice);

        loan = Loan.Data({
            id: 0,
            isActive: true,
            borrower: msg.sender,
            collateralToken: self.collateralToken,
            isNativeCurrency: false,
            priceOracle: self.priceOracle,
            stabilizationFee: stabilizationFee,
            interest: 0,
            principalAmount: principalAmount,
            interestAmount: 0,
            collateralAmount: collateralAmount,
            lastInteractionAt: block.timestamp
        });
    }

    function calculateLoanBySecurityAmount(Data memory self, uint256 securityAmount)
        internal
        view
        returns (
            Loan.Data memory loan,
            uint256 exchangeFee,
            uint256 developmentFee,
            uint256 stabilityFee
        )
    {
        uint256 collateralTokenPrice = self.priceOracle.getNormalizedPrice(self.collateralToken);
        uint256 c = self.stabilityFee.mul(self.initialLoanToValueRatio);
        uint256 principalAmount = securityAmount.mul(self.initialLoanToValueRatio).mul(collateralTokenPrice).div(
            c + ONE
        );
        return calculateLoanByPrincipalAmount(self, principalAmount);
    }

    function getCollateralValue(Data memory self) internal view returns (uint256 collateralValue) {
        if (self.collateralAmount == 0) {
            return 0;
        }

        uint256 collateralTokenPrice = self.priceOracle.getNormalizedPrice(self.collateralToken);
        collateralValue = self.collateralAmount.mul(collateralTokenPrice);
    }
}
