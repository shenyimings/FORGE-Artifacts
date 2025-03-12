// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '../libraries/types/DataTypes.sol';

interface IOpenSkyDataProvider {
    struct ReserveData {
        uint256 reserveId;
        address oTokenAddress;
        uint256 TVL;
        uint256 totalDeposits;
        uint256 totalBorrowsBalance;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 availableLiquidity;
    }

    struct LoanData {
        uint256 loanId;
        uint256 totalBorrows;
        uint256 borrowBalance;
        uint256 borrowBegin;
        uint256 borrowDuration;
        uint256 borrowOverdueTime;
        uint256 borrowRate;
        uint256 penalty;
        DataTypes.LoanStatus status;
    }

    function getReserveData(uint256 reserveId) external view returns (ReserveData memory);

    function getTVL(uint256 reserveId) external view returns (uint256);

    function getTotalBorrowBalance(uint256 reserveId) external view returns (uint256);

    function getAvailableLiquidity(uint256 reserveId) external view returns (uint256);

    function getSupplyRate(uint256 reserveId) external view returns (uint256);

    function getLoanSupplyRate(uint256 reserveId) external view returns (uint256);

    function getBorrowRate(uint256 reserveId) external view returns (uint256);

    function getMoneyMarketSupplyRateInstant(uint256 reserveId) external view returns (uint256);

    function getSupplyBalance(uint256 reserveId, address account) external view returns (uint256);

    function getLoanData(uint256 loanId) external view returns (LoanData memory);

    function getLoansByUser(address account) external view returns (uint256[] memory arr);
}
