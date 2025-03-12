// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Common interface for the Trove Manager.
interface IBorrowerOperations {
    struct TokenAccount {
        address collateralToken;
        address account;
    }

    // --- Functions ---
    function enableCollateral(address troveManager, address collateralToken) external;

    function openTrove(
        TokenAccount calldata tokenAccount,
        uint _maxFee,
        uint _collateralAmount,
        uint _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function addColl(
        TokenAccount calldata tokenAccount,
        uint _collateralAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function withdrawColl(
        TokenAccount calldata tokenAccount,
        uint _amount,
        address _upperHint,
        address _lowerHint
    ) external;

    function withdrawDebt(
        TokenAccount calldata tokenAccount,
        uint _maxFee,
        uint _amount,
        address _upperHint,
        address _lowerHint
    ) external;

    function repayDebt(
        TokenAccount calldata tokenAccount,
        uint _amount,
        address _upperHint,
        address _lowerHint
    ) external;

    function closeTrove(TokenAccount calldata tokenAccount) external;

    function adjustTrove(
        TokenAccount calldata tokenAccount,
        uint _maxFee,
        uint _collDeposit,
        uint _collWithdrawal,
        uint _debtChange,
        bool isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external;

    function claimCollateral(TokenAccount calldata tokenAccount) external;

    function getCompositeDebt(uint _debt) external view returns (uint);

    function minNetDebt() external view returns (uint);

    function getGlobalSystemBalances() external returns (uint256 totalPricedCollateral, uint256 totalDebt);
}
