// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './types/DataTypes.sol';
import './helpers/Errors.sol';
import './math/WadRayMath.sol';
import './math/PercentageMath.sol';
import './math/MathUtils.sol';

import '../interfaces/IOpenSkySettings.sol';
import '../interfaces/IOpenSkyReserveVaultFactory.sol';
import '../interfaces/IOpenSkyInterestRateStrategy.sol';
import '../interfaces/IOpenSkyOToken.sol';
import '../interfaces/IOpenSkyMoneymarket.sol';

/**
 * @title ReserveLogic library
 * @author OpenSky Labs
 * @notice Implements the logic to update the reserves state
 */
library ReserveLogic {
    using SafeMath for uint256;
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    /**
     * @dev Implements the deposit feature.
     * @param lender The address of lender that will receive otokens
     * @param amount The amount of deposit
     **/
    function deposit(
        DataTypes.ReserveData storage reserve,
        address lender,
        uint256 amount
    ) public {
        updateState(reserve, 0);

        updateLastMoneyMarketBalance(reserve, amount, 0);

        IOpenSkyOToken oToken = IOpenSkyOToken(reserve.oTokenAddress);
        oToken.mint(lender, amount, reserve.lastSupplyIndex);
        oToken.deposit{value: amount}(amount);
    }

    /**
     * @dev Implements the withdrawal feature.
     * @param receiver The address that will receive ETH
     * @param amount The withdrawal amount
     **/
    function withdraw(
        DataTypes.ReserveData storage reserve,
        address receiver,
        uint256 amount
    ) public {
        updateState(reserve, 0);

        updateLastMoneyMarketBalance(reserve, 0, amount);

        IOpenSkyOToken oToken = IOpenSkyOToken(reserve.oTokenAddress);
        oToken.burn(receiver, amount, reserve.lastSupplyIndex);
        oToken.withdraw(amount, receiver);
    }

    /**
     * @dev Implements the withdrawal feature.
     * @param loan the loan data
     **/
    function borrow(DataTypes.ReserveData storage reserve, DataTypes.LoanData memory loan) public {
        updateState(reserve, 0);
        updateInterestPerSecond(reserve, loan.interestPerSecond, 0);
        updateLastMoneyMarketBalance(reserve, 0, loan.amount);

        IOpenSkyOToken oToken = IOpenSkyOToken(reserve.oTokenAddress);
        oToken.withdraw(loan.amount, loan.borrower);

        reserve.totalBorrows = reserve.totalBorrows.add(loan.amount);
    }

    /**
     * @dev Implements the repay function.
     * @param loan The loan data
     * @param amount The amount that will be repaid, including penalty
     * @param borrowBalance The borrow balance
     **/
    function repay(
        DataTypes.ReserveData storage reserve,
        DataTypes.LoanData memory loan,
        uint256 amount,
        uint256 borrowBalance
    ) public {
        updateState(reserve, amount.sub(borrowBalance));
        updateInterestPerSecond(reserve, 0, loan.interestPerSecond);
        updateLastMoneyMarketBalance(reserve, amount, 0);

        IOpenSkyOToken oToken = IOpenSkyOToken(reserve.oTokenAddress);
        oToken.deposit{value: amount}(amount);

        reserve.totalBorrows = reserve.totalBorrows > borrowBalance ? reserve.totalBorrows.sub(borrowBalance) : 0;
    }

    /**
     * @dev Implements the extend feature.
     * @param oldLoan The data of old loan
     * @param newLoan The data of new loan
     * @param borrowInterestOfOldLoan The borrow interest of old loan
     * @param ethIn The amount of ETH that will be deposited
     * @param ethOut The amount of ETH that will be withdrawn
     * @param additionalIncome The additional income
     **/
    function extend(
        DataTypes.ReserveData storage reserve,
        DataTypes.LoanData memory oldLoan,
        DataTypes.LoanData memory newLoan,
        uint256 borrowInterestOfOldLoan,
        uint256 ethIn,
        uint256 ethOut,
        uint256 additionalIncome
    ) public {
        updateState(reserve, additionalIncome);
        updateInterestPerSecond(reserve, newLoan.interestPerSecond, oldLoan.interestPerSecond);
        updateLastMoneyMarketBalance(reserve, ethIn, ethOut);

        IOpenSkyOToken oToken = IOpenSkyOToken(reserve.oTokenAddress);
        if (ethIn > 0) oToken.deposit{value: ethIn}(ethIn);
        if (ethOut > 0) oToken.withdraw(ethOut, newLoan.borrower);

        uint256 sum1 = reserve.totalBorrows.add(newLoan.amount);
        uint256 sum2 = oldLoan.amount.add(borrowInterestOfOldLoan);
        reserve.totalBorrows = sum1 > sum2 ? sum1 - sum2 : 0;
    }

    /**
     * @dev Implements liquidation mechanism.
     * @param loan Loan data
     **/
    function startLiquidation(DataTypes.ReserveData storage reserve, DataTypes.LoanData memory loan) public {
        updateState(reserve, 0);
        updateLastMoneyMarketBalance(reserve, 0, 0);
        updateInterestPerSecond(reserve, 0, loan.interestPerSecond);
    }

    /**
     * @dev Implements the start liquidation feature.
     * @param inEthAmount The amount of ETH paid
     * @param borrowBalance The borrow balance of loan
     **/
    function endLiquidation(
        DataTypes.ReserveData storage reserve,
        uint256 inEthAmount,
        uint256 borrowBalance
    ) public {
        updateState(reserve, inEthAmount.sub(borrowBalance));
        updateLastMoneyMarketBalance(reserve, inEthAmount, 0);

        IOpenSkyOToken oToken = IOpenSkyOToken(reserve.oTokenAddress);
        oToken.deposit{value: inEthAmount}(inEthAmount);

        reserve.totalBorrows = reserve.totalBorrows > borrowBalance ? reserve.totalBorrows - borrowBalance : 0;
    }

    /**
     * @dev Updates the liquidity cumulative index and total borrows
     * @param reserve The reserve object
     * @param additionalIncome The additional income
     **/
    function updateState(DataTypes.ReserveData storage reserve, uint256 additionalIncome) internal {
        (
            uint256 newIndex,
            uint256 usersIncome,
            uint256 treasuryIncome,
            uint256 borrowingInterestDelta,

        ) = calculateIncome(reserve, additionalIncome);

        require(newIndex <= type(uint128).max, Errors.RESERVE_INDEX_OVERFLOW);
        reserve.lastSupplyIndex = uint128(newIndex);

        // treasury
        treasuryIncome = treasuryIncome.div(WadRayMath.ray());
        if (treasuryIncome > 0) {
            IOpenSkyOToken(reserve.oTokenAddress).mintToTreasury(treasuryIncome, reserve.lastSupplyIndex);
        }

        reserve.totalBorrows = reserve.totalBorrows.add(borrowingInterestDelta.div(WadRayMath.ray()));
        reserve.lastUpdateTimestamp = uint40(block.timestamp);
    }

    /**
     * @dev Updates the interest per second, when borrowing and repaying
     * @param reserve The reserve object
     * @param amountToAdd The amount to be added
     * @param amountToRemove The amount to be subtracted
     **/
    function updateInterestPerSecond(
        DataTypes.ReserveData storage reserve,
        uint256 amountToAdd,
        uint256 amountToRemove
    ) internal {
        reserve.borrowingInterestPerSecond = reserve.borrowingInterestPerSecond.add(amountToAdd).sub(amountToRemove);
    }

    /**
     * @dev Updates last money market balance, after updating the liquidity cumulative index.
     * @param reserve The reserve object
     * @param amountToAdd The amount to be added
     * @param amountToRemove The amount to be subtracted
     **/
    function updateLastMoneyMarketBalance(
        DataTypes.ReserveData storage reserve,
        uint256 amountToAdd,
        uint256 amountToRemove
    ) internal {
        uint256 moneyMarketBalance = getMoneyMarketBalance(reserve);
        reserve.lastMoneyMarketBalance = moneyMarketBalance.add(amountToAdd).sub(amountToRemove);
    }

    /**
     * @dev Updates last money market balance, after updating the liquidity cumulative index.
     * @param reserve The reserve object
     * @param additionalIncome The amount to be added
     * @return newIndex The new liquidity cumulative index from the last update
     * @return usersIncome The user's income from the last update
     * @return treasuryIncome The treasury income from the last update
     * @return borrowingInterestDelta The treasury income from the last update
     * @return moneyMarketDelta The money market income from the last update
     **/
    function calculateIncome(DataTypes.ReserveData memory reserve, uint256 additionalIncome)
        internal
        view
        returns (
            uint256 newIndex,
            uint256 usersIncome,
            uint256 treasuryIncome,
            uint256 borrowingInterestDelta,
            uint256 moneyMarketDelta
        )
    {
        moneyMarketDelta = getMoneyMarketDelta(reserve).mul(WadRayMath.ray());
        borrowingInterestDelta = getBorrowingInterestDelta(reserve);
        // ray
        uint256 totalIncome = additionalIncome.mul(WadRayMath.ray()).add(moneyMarketDelta).add(borrowingInterestDelta);
        treasuryIncome = totalIncome.percentMul(reserve.treasuryFactor);
        usersIncome = totalIncome.sub(treasuryIncome);

        // index
        newIndex = reserve.lastSupplyIndex;
        uint256 scaledTotalSupply = IOpenSkyOToken(reserve.oTokenAddress).scaledTotalSupply();
        if (scaledTotalSupply > 0) {
            newIndex = usersIncome.div(scaledTotalSupply).add(reserve.lastSupplyIndex);
        }

        return (newIndex, usersIncome, treasuryIncome, borrowingInterestDelta, moneyMarketDelta);
    }

    /**
     * @dev Returns the ongoing normalized income for the reserve
     * A value of 1e27 means there is no income. As time passes, the income is accrued
     * A value of 2*1e27 means for each unit of asset one unit of income has been accrued
     * @param reserve The reserve object
     * @return The normalized income. expressed in ray
     **/
    function getNormalizedIncome(DataTypes.ReserveData storage reserve) public view returns (uint256) {
        (uint256 newIndex, , , , ) = calculateIncome(reserve, 0);
        return newIndex;
    }

    /**
     * @dev Returns the available liquidity of the reserve
     * @param reserve The reserve object
     * @return The available liquidity
     **/
    function getMoneyMarketBalance(DataTypes.ReserveData memory reserve) internal view returns (uint256) {
        return IOpenSkyMoneymarket(reserve.moneyMarketAddress).getBalance(reserve.oTokenAddress);
    }

    /**
     * @dev Returns the money market income of the reserve from the last update
     * @param reserve The reserve object
     * @return The income from money market
     **/
    function getMoneyMarketDelta(DataTypes.ReserveData memory reserve) internal view returns (uint256) {
        uint256 timeDelta = uint256(block.timestamp).sub(reserve.lastUpdateTimestamp);

        if (timeDelta == 0) return 0;

        if (reserve.lastMoneyMarketBalance == 0) return 0;

        // get MoneyMarketBalance
        uint256 currentMoneyMarketBalance = getMoneyMarketBalance(reserve);
        if (currentMoneyMarketBalance < reserve.lastMoneyMarketBalance) return 0;

        return currentMoneyMarketBalance.sub(reserve.lastMoneyMarketBalance);
    }

    /**
     * @dev Returns the borrow interest income of the reserve from the last update
     * @param reserve The reserve object
     * @return The income from the NFT loan
     **/
    function getBorrowingInterestDelta(DataTypes.ReserveData memory reserve) internal view returns (uint256) {
        uint256 timeDelta = uint256(block.timestamp).sub(reserve.lastUpdateTimestamp);
        if (timeDelta == 0) return 0;
        return reserve.borrowingInterestPerSecond.mul(timeDelta);
    }

    /**
     * @dev Returns the total borrow balance of the reserve
     * @param reserve The reserve object
     * @return The total borrow balance
     **/
    function getTotalBorrowBalance(DataTypes.ReserveData memory reserve) public view returns (uint256) {
        return reserve.totalBorrows.add(getBorrowingInterestDelta(reserve).div(WadRayMath.ray()));
    }

    /**
     * @dev Returns the total value locked (TVL) of the reserve
     * @param reserve The reserve object
     * @return The total value locked (TVL)
     **/
    function getTVL(DataTypes.ReserveData memory reserve) public view returns (uint256) {
        (, , uint256 treasuryIncome, , ) = calculateIncome(reserve, 0);
        return treasuryIncome.div(WadRayMath.RAY).add(IOpenSkyOToken(reserve.oTokenAddress).totalSupply());
    }

    /**
     * @dev Returns the borrow rate of the reserve
     * @param reserve The reserve object
     * @return The borrow rate
     **/
    function getBorrowRate(DataTypes.ReserveData memory reserve) public view returns (uint256) {
        uint256 liquidity = getMoneyMarketBalance(reserve);
        uint256 totalBorrowBalance = getTotalBorrowBalance(reserve);
        return
            IOpenSkyInterestRateStrategy(reserve.interestModelAddress).getBorrowRate(
                reserve.reserveId,
                liquidity.add(totalBorrowBalance),
                totalBorrowBalance
            );
    }
}
