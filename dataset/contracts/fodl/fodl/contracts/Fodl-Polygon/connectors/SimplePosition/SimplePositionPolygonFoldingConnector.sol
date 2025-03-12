// SPDX-License-Identifier: MIT

pragma solidity 0.6;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/Math.sol';

import '../interfaces/ISimplePositionPolygonFoldingConnector.sol';

import '../../../Fodl/connectors/SimplePosition/SimplePositionBaseConnector.sol';
import '../../../Fodl/modules/Exchanger/ExchangerDispatcher.sol';
import '../../../Fodl/modules/FundsManager/FundsManager.sol';
import '../../../Fodl/core/interfaces/IExchangerAdapterProvider.sol';

import { LendingDispatcherPolygon } from '../../modules/Lender/LendingDispatcherPolygon.sol';

contract SimplePositionPolygonFoldingConnector is
    ISimplePositionPolygonFoldingConnector,
    SimplePositionBaseConnector,
    ExchangerDispatcher,
    LendingDispatcherPolygon,
    FundsManager
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public immutable rewardsFactor;

    constructor(
        uint256 _principal,
        uint256 _profit,
        uint256 _rewardsFactor,
        address _holder
    ) public FundsManager(_principal, _profit, _holder) {
        rewardsFactor = _rewardsFactor;
    }

    /**
     * platform - The lender, ex. Venus Comptroller
     * supplyToken - The principal and supplied token to platform
     * principalAmount - Amount to transferFrom accountOwner
     * minSupplyAmount - Increase position by at least this amount of supply, or revert. Used to protect from unwanted slippage
     * borrowToken - The borrowed token from platform
     * totalBorrowAmount - Increase position by borrowing exactly this amount of borrowToken in total from platform. Used to control target leverage
     * exchangeData - ABI encoded (bytes1, address[]), for (getExchangerAdapter, swapPath). Required for swapping borrowToken to supplyToken, when not same token
     */
    function increaseSimplePositionWithLoop(
        address platform,
        address supplyToken,
        uint256 principalAmount,
        uint256 minSupplyAmount,
        address borrowToken,
        uint256 totalBorrowAmount,
        bytes memory exchangeData
    ) external override onlyAccountOwnerOrRegistry {
        address lender = getLender(platform);
        _prepareSimplePosition(lender, platform, supplyToken, borrowToken);
        address exchanger = IExchangerAdapterProvider(aStore().foldingRegistry).getExchangerAdapter(exchangeData[0]);

        uint256 startSupply = getSupplyBalance();

        if (principalAmount > 0) {
            addPrincipal(principalAmount);
            supply(lender, platform, supplyToken, principalAmount);
        }

        while (totalBorrowAmount > 0) {
            uint256 borrowAmount = Math.min(getLiquidity(lender, platform, borrowToken), totalBorrowAmount);
            borrow(lender, platform, borrowToken, borrowAmount);
            totalBorrowAmount = totalBorrowAmount.sub(borrowAmount); // Math.min ensures never negative

            if (supplyToken != borrowToken) {
                // minSupplyAmount enforces max slippage, see README
                exchange(
                    exchanger,
                    borrowToken,
                    supplyToken,
                    IERC20(borrowToken).balanceOf(address(this)),
                    1,
                    exchangeData
                );
            }

            supply(lender, platform, supplyToken, IERC20(supplyToken).balanceOf(address(this)));
        }

        require(getSupplyBalance().sub(startSupply) >= minSupplyAmount, 'SPFC01');
    }

    /**
     * platform - The lender, ex. Venus Comptroller
     * supplyToken - The supplied token to platform in existing position
     * withdrawAmount - Amount of supplyToken to redeem and transferTo accountOwner
     * maxRedeemAmount - Decrease position by redeeming at most this amount of supplied token. Can be greater than supplied amount to support zero dust withdrawals
     * borrowToken - The borrowed token from platform in existing position
     * minRepayAmount - Repay debt of at least this amount of borrowToken or revert. Used to protect from unwanted slippage
     * exchangeData - ABI encoded (bytes1, address[]), for (getExchangerAdapter, swapPath). Required for swapping supplyToken to borrowToken, when not same token
     */
    function decreaseSimplePositionWithLoop(
        address platform,
        address supplyToken,
        uint256 withdrawAmount,
        uint256 maxRedeemAmount,
        address borrowToken,
        uint256 minRepayAmount,
        bytes memory exchangeData
    ) external override onlyAccountOwner {
        requireSimplePositionDetails(platform, supplyToken, borrowToken);

        address lender = getLender(platform);

        uint256 startBorrowBalance = getBorrowBalance();
        uint256 supplyCollateralFactor = getCollateralFactorForAsset(lender, platform, supplyToken);
        uint256 startPositionValue = _getPositionValue(lender, platform, supplyToken, borrowToken);

        while (maxRedeemAmount > 0 && getBorrowBalance() > 0) {
            uint256 redeemAmount = _getRedeemAmount(
                lender,
                platform,
                supplyToken,
                supplyCollateralFactor,
                maxRedeemAmount
            );
            redeemSupply(lender, platform, supplyToken, redeemAmount);
            maxRedeemAmount = maxRedeemAmount.sub(redeemAmount); // Math.min ensures never negative

            if (supplyToken != borrowToken) {
                // minRepayAmount enforces max slippage, see README
                exchange(
                    IExchangerAdapterProvider(aStore().foldingRegistry).getExchangerAdapter(exchangeData[0]),
                    supplyToken,
                    borrowToken,
                    IERC20(supplyToken).balanceOf(address(this)),
                    1,
                    exchangeData
                );
            }

            repayBorrow(
                lender,
                platform,
                borrowToken,
                Math.min(getBorrowBalance(), IERC20(borrowToken).balanceOf(address(this)))
            );
        }

        require(startBorrowBalance.sub(getBorrowBalance()) >= minRepayAmount, 'SPFC02');

        if (supplyToken != borrowToken && getBorrowBalance() == 0) {
            _swapExcessBorrowTokens(supplyToken, borrowToken, exchangeData);
        }

        if (withdrawAmount > 0) {
            _redeemAndWithdraw(lender, platform, supplyToken, withdrawAmount, startPositionValue);
        }

        if (IERC20(supplyToken).balanceOf(address(this)) > 0) {
            supply(lender, platform, supplyToken, IERC20(supplyToken).balanceOf(address(this)));
        }

        if (getBorrowBalance() == 0) {
            _claimRewards(lender, platform);
        }
    }

    /**
     * @return Encoded exchange data (bytes1, address[]) with reversed path
     */
    function reversePath(bytes memory exchangeData) public pure returns (bytes memory) {
        (bytes1 flag, address[] memory path) = abi.decode(exchangeData, (bytes1, address[]));

        uint256 length = path.length;
        address[] memory reversed = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            reversed[length - 1 - i] = path[i];
        }

        return abi.encode(flag, reversed);
    }

    function _prepareSimplePosition(
        address lender,
        address platform,
        address supplyToken,
        address borrowToken
    ) private {
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
    }

    function _getRedeemAmount(
        address lender,
        address platform,
        address supplyToken,
        uint256 supplyCollateralFactor,
        uint256 maxRedeemAmount
    ) private returns (uint256) {
        return
            Math.min(
                getLiquidity(lender, platform, supplyToken), // Max amount of supplyToken able to redeem
                maxRedeemAmount
            );
    }

    function _getPositionValue(
        address lender,
        address platform,
        address supplyToken,
        address borrowToken
    ) private returns (uint256) {
        return
            getSupplyBalance().sub(
                getBorrowBalance().mul(getReferencePrice(lender, platform, borrowToken)).div(
                    getReferencePrice(lender, platform, supplyToken)
                )
            );
    }

    function _swapExcessBorrowTokens(
        address supplyToken,
        address borrowToken,
        bytes memory exchangeData
    ) private {
        uint256 borrowTokenBalance = IERC20(borrowToken).balanceOf(address(this));
        if (borrowTokenBalance > 0) {
            bytes memory reversedExchangeData = reversePath(exchangeData);
            exchange(
                IExchangerAdapterProvider(aStore().foldingRegistry).getExchangerAdapter(reversedExchangeData[0]),
                borrowToken,
                supplyToken,
                borrowTokenBalance,
                1,
                reversedExchangeData
            );
        }
    }

    function _redeemAndWithdraw(
        address lender,
        address platform,
        address supplyToken,
        uint256 withdrawAmount,
        uint256 startPositionValue
    ) private {
        uint256 supplyTokenBalance = IERC20(supplyToken).balanceOf(address(this));
        if (withdrawAmount > supplyTokenBalance) {
            uint256 redeemAmount = withdrawAmount - supplyTokenBalance;
            if (redeemAmount > getSupplyBalance()) {
                redeemAll(lender, platform, supplyToken); // zero dust redeem
            } else {
                redeemSupply(lender, platform, supplyToken, redeemAmount);
            }
        }

        withdrawAmount = Math.min(withdrawAmount, IERC20(supplyToken).balanceOf(address(this))); // zero dust withdraw
        withdraw(withdrawAmount, startPositionValue);
    }

    function _claimRewards(address lender, address platform) private {
        (address rewardsToken, uint256 rewardsAmount) = claimRewards(lender, platform);
        if (rewardsToken != address(0)) {
            uint256 subsidy = rewardsAmount.mul(rewardsFactor).div(MANTISSA);
            if (subsidy > 0) {
                IERC20(rewardsToken).safeTransfer(holder, subsidy);
            }
            if (rewardsAmount > subsidy) {
                IERC20(rewardsToken).safeTransfer(accountOwner(), rewardsAmount - subsidy);
            }
        }
    }
}
