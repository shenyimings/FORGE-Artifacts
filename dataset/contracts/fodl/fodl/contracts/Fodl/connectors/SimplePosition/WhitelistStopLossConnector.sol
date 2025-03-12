// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../../../Fodl/connectors/SimplePosition/SimplePositionBaseConnector.sol';
import '../interfaces/IWhitelistStopLossConnector.sol';
import '../../../Fodl/modules/StopLoss/StopLossStorage.sol';
import '../../../Libs/Mathemagic.sol';
import '../../modules/RiskManagement/RiskManagementStorage.sol';

contract WhitelistStopLossConnector is
    IWhitelistStopLossConnector,
    StopLossStorage,
    RiskManagementStorage,
    SimplePositionBaseConnector
{
    using Mathemagic for uint256;
    using SafeMath for uint256;

    uint256 private constant MANTISSA = 1e18;

    function configureStopLoss(
        uint256 unwindFactor,
        uint256 slippageIncentive,
        uint256 collateralUsageLimit,
        address permittedBot
    ) external override onlyAccountOwner returns (bool) {
        require(isSimplePosition(), 'SP1');
        require(unwindFactor <= MANTISSA, 'WSLC1');
        require(slippageIncentive <= MANTISSA, 'WSLC2');
        require(collateralUsageLimit > getCollateralUsageFactor() && collateralUsageLimit <= MANTISSA, 'WSLC3');

        StopLossStore storage stopLossConfiguration = stopLossStore();
        stopLossConfiguration.unwindFactor = unwindFactor;
        stopLossConfiguration.slippageIncentive = slippageIncentive;
        stopLossConfiguration.collateralUsageLimit = collateralUsageLimit;

        if (permittedBot != address(0)) riskMagamentStore().whitelist[permittedBot] = true;

        return true;
    }

    function executeStopLoss() external override returns (uint256 redeemAmount) {
        require(riskMagamentStore().whitelist[tx.origin] == true, 'WSLC9');
        require(isSimplePosition(), 'WSLC8');

        StopLossStore memory stopLossConfiguration = stopLossStore();
        require(stopLossConfiguration.unwindFactor > 0, 'WSLC7');
        require(getCollateralUsageFactor() > stopLossConfiguration.collateralUsageLimit, 'WSLC5');

        SimplePositionStore memory sp = simplePositionStore();
        address lender = getLender(sp.platform);

        {
            bool isFullRepayment = stopLossConfiguration.unwindFactor == MANTISSA;
            uint256 debt = getBorrowBalance();

            uint256 repayAmount = isFullRepayment ? debt : debt.mulDiv(stopLossConfiguration.unwindFactor, MANTISSA);

            uint256 priceOfBorrowToken = getReferencePrice(lender, sp.platform, sp.borrowToken);
            uint256 priceOfSupplyToken = getReferencePrice(lender, sp.platform, sp.supplyToken);

            uint256 maxRedeemableSupply = isFullRepayment
                ? getSupplyBalance()
                : getSupplyBalance()
                    .mulDiv(getCollateralFactorForAsset(lender, sp.platform, sp.supplyToken), MANTISSA)
                    .sub(debt.sub(repayAmount).mulDiv(priceOfBorrowToken, priceOfSupplyToken));
            redeemAmount = repayAmount.mulDiv(
                (stopLossConfiguration.slippageIncentive + MANTISSA).mul(priceOfBorrowToken),
                MANTISSA.mul(priceOfSupplyToken)
            );

            if (redeemAmount > maxRedeemableSupply) {
                redeemAmount = maxRedeemableSupply;
            }

            repayBorrow(lender, sp.platform, sp.borrowToken, repayAmount);
        }

        redeemSupply(lender, sp.platform, sp.supplyToken, redeemAmount);
        IERC20(sp.supplyToken).safeTransfer(aStore().entryCaller, redeemAmount);

        return redeemAmount;
    }

    function setStopLossWhitelistPermission(address addr, bool permission) external override onlyAccountOwner {
        riskMagamentStore().whitelist[addr] = permission;
    }

    function getStopLossWhitelistPermission(address addr) external override returns (bool) {
        return riskMagamentStore().whitelist[addr];
    }

    function getStopLossConfiguration()
        public
        view
        override
        returns (
            uint256 slippageIncentive,
            uint256 collateralUsageLimit,
            uint256 unwindFactor
        )
    {
        StopLossStore storage stopLossConfiguration = stopLossStore();
        (slippageIncentive, collateralUsageLimit, unwindFactor) = (
            stopLossConfiguration.slippageIncentive,
            stopLossConfiguration.collateralUsageLimit,
            stopLossConfiguration.unwindFactor
        );
    }

    function getStopLossState()
        external
        override
        returns (
            bool canTriggerStopLoss,
            uint256 supplyBalance,
            uint256 borrowBalance,
            uint256 slippageIncentive,
            uint256 collateralUsageLimit,
            uint256 unwindFactor
        )
    {
        (slippageIncentive, collateralUsageLimit, unwindFactor) = getStopLossConfiguration();
        supplyBalance = getSupplyBalance();
        borrowBalance = getBorrowBalance();
        canTriggerStopLoss = getCollateralUsageFactor() > collateralUsageLimit && unwindFactor > 0;
    }
}
