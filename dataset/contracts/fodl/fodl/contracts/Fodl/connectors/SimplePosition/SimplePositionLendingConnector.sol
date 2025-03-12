// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import '../interfaces/ISimplePositionLendingConnector.sol';
import '../../modules/Lender/LendingDispatcher.sol';
import '../../modules/SimplePosition/SimplePositionStorage.sol';

contract SimplePositionLendingConnector is LendingDispatcher, SimplePositionStorage, ISimplePositionLendingConnector {
    using SafeERC20 for IERC20;

    function increaseSimplePositionWithFunds(
        address platform,
        address supplyToken,
        uint256 supplyAmount,
        address borrowToken,
        uint256 borrowAmount
    ) external override onlyAccountOwnerOrRegistry {
        address lender = getLender(platform);
        if (isSimplePosition()) {
            requireSimplePositionDetails(platform, supplyToken, borrowToken);
        } else {
            simplePositionStore().platform = platform;
            simplePositionStore().supplyToken = supplyToken;
            simplePositionStore().borrowToken = borrowToken;

            address[] memory markets = new address[](2);
            markets[0] = supplyToken;
            markets[1] = borrowToken;
            enterMarkets(lender, platform, markets);
        }

        address accountOwner = accountOwner();

        if (supplyAmount > 0) {
            IERC20(supplyToken).safeTransferFrom(accountOwner, address(this), supplyAmount);

            supply(lender, platform, supplyToken, supplyAmount);
        }

        if (borrowAmount > 0) {
            borrow(lender, platform, borrowToken, borrowAmount);

            IERC20(borrowToken).safeTransfer(accountOwner, borrowAmount);
        }
    }

    function decreaseSimplePositionWithFunds(
        address platform,
        address supplyToken,
        uint256 supplyAmount,
        address borrowToken,
        uint256 borrowAmount
    ) external override onlyAccountOwner {
        require(isSimplePosition(), 'SP1');
        requireSimplePositionDetails(platform, supplyToken, borrowToken);

        address accountOwner = accountOwner();
        address lender = getLender(platform);

        if (borrowAmount > 0) {
            IERC20(borrowToken).safeTransferFrom(accountOwner, address(this), borrowAmount);
            repayBorrow(lender, platform, borrowToken, borrowAmount);
        }

        if (supplyAmount > 0) {
            redeemSupply(lender, platform, supplyToken, supplyAmount);
            IERC20(supplyToken).safeTransfer(accountOwner, supplyAmount);
        }
    }
}
