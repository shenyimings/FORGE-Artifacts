// SPDX-License-Identifier: MIT

import "../Dependencies/IERC20.sol";

pragma solidity 0.6.11;

// Common interface for the Trove Manager.
interface IBorrowerOperations {

    // --- Events ---

    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event DefaultPoolAddressChanged(address _defaultPoolAddress);
    event StabilityPoolAddressChanged(address _stabilityPoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event PriceFeedAddressChanged(address  _newPriceFeedAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event LUSDTokenAddressChanged(address _lusdTokenAddress);
    event LQTYStakingAddressChanged(address _lqtyStakingAddress);

    event TroveCreated(address indexed _borrower, uint arrayIndex);
    event TroveUpdated(address indexed _borrower, uint _debt, uint _coll, uint stake, uint8 operation);
    event LUSDBorrowingFeePaid(address indexed _borrower, uint _LUSDFee);

    function collateralToken() external view returns (IERC20);

    // --- Functions ---

    function setAddresses(
        address _troveManagerAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _priceFeedAddress,
        address _sortedTrovesAddress,
        address _lusdTokenAddress,
        address _lqtyStakingAddress,
        address _collateralStakingAddress
    ) external;

    function openTrove(address _account, uint _maxFee, uint _collateralAmount, uint _LUSDAmount, address _upperHint, address _lowerHint) external;

    function addColl(address _account, uint _collateralAmount, address _upperHint, address _lowerHint) external;

    function moveETHGainToTrove(uint _collateralAmount, address _user, address _upperHint, address _lowerHint) external;

    function withdrawColl(address _account, uint _amount, address _upperHint, address _lowerHint) external;

    function withdrawLUSD(address _account, uint _maxFee, uint _amount, address _upperHint, address _lowerHint) external;

    function repayLUSD(address _account, uint _amount, address _upperHint, address _lowerHint) external;

    function closeTrove(address _account) external;

    function adjustTrove(address _account, uint _maxFee, uint _collDeposit, uint _collWithdrawal, uint _debtChange, bool isDebtIncrease, address _upperHint, address _lowerHint) external;

    function claimCollateral(address _account) external;

    function getCompositeDebt(uint _debt) external view returns (uint);

    function minNetDebt() external view returns (uint);
}
