// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '../../modules/Lender/LendingDispatcher.sol';
import '../../modules/SimplePosition/SimplePositionStorage.sol';
import '../interfaces/ISimplePositionBaseConnector.sol';

contract SimplePositionBaseConnector is LendingDispatcher, SimplePositionStorage, ISimplePositionBaseConnector {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    function getBorrowBalance() public override returns (uint256) {
        return
            getBorrowBalance(
                getLender(simplePositionStore().platform),
                simplePositionStore().platform,
                simplePositionStore().borrowToken
            );
    }

    function getSupplyBalance() public override returns (uint256) {
        return
            getSupplyBalance(
                getLender(simplePositionStore().platform),
                simplePositionStore().platform,
                simplePositionStore().supplyToken
            );
    }

    function getCollateralUsageFactor() public override returns (uint256) {
        return getCollateralUsageFactor(getLender(simplePositionStore().platform), simplePositionStore().platform);
    }

    function getPositionValue() public override returns (uint256 positionValue) {
        SimplePositionStore memory sp = simplePositionStore();
        address lender = getLender(sp.platform);

        uint256 debt = getBorrowBalance(lender, sp.platform, sp.borrowToken);
        uint256 deposit = getSupplyBalance(lender, sp.platform, sp.supplyToken);
        debt = debt.mul(getReferencePrice(lender, sp.platform, sp.borrowToken)).div(
            getReferencePrice(lender, sp.platform, sp.supplyToken)
        );
        if (deposit >= debt) {
            positionValue = deposit - debt;
        } else {
            positionValue = 0;
        }
    }

    function getPrincipalValue() public override returns (uint256) {
        return simplePositionStore().principalValue;
    }

    function getPositionMetadata() external override returns (SimplePositionMetadata memory metadata) {
        metadata.positionAddress = address(this);
        metadata.platformAddress = simplePositionStore().platform;
        metadata.supplyTokenAddress = simplePositionStore().supplyToken;
        metadata.borrowTokenAddress = simplePositionStore().borrowToken;
        metadata.supplyAmount = getSupplyBalance();
        metadata.borrowAmount = getBorrowBalance();
        metadata.collateralUsageFactor = getCollateralUsageFactor();
        metadata.principalValue = getPrincipalValue();
        metadata.positionValue = getPositionValue();
    }

    function getSimplePositionDetails()
        external
        view
        override
        returns (
            address,
            address,
            address
        )
    {
        SimplePositionStore storage sp = simplePositionStore();
        return (sp.platform, sp.supplyToken, sp.borrowToken);
    }
}
