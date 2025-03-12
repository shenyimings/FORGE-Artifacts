// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./Dependencies/ERDBase.sol";
import "./DataTypes.sol";

contract TroveManagerDataTypes is ERDBase, OwnableUpgradeable {
    // --- Events ---

    event BorrowerOperationsAddressChanged(
        address _newBorrowerOperationsAddress
    );
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event EUSDTokenAddressChanged(address _newEUSDTokenAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event DefaultPoolAddressChanged(address _defaultPoolAddress);
    event StabilityPoolAddressChanged(address _stabilityPoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event TroveManagerLiquidationsAddressChanged(address _troveManagerLiquidationsAddress);
    event TroveManagerRedemptionsAddressChanged(address _troveManagerRedemptionsAddress);
    event CollateralManagerAddressChanged(address _collateralManagerAddress);
    event TroveManagerAddressChanged(address _troveManagerAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event WETHAddressChanged(address _wethAddress);
    event TreasuryAddressChanged(address _treasuryAddress);
    event TroveDebtAddressChanged(address _troveDebtAddress);

    event CollateralAdded(address _collateral);
    event CollateralRemoved(address _collateral);

    event Liquidation(
        uint256 _liquidatedDebt,
        uint256[] _liquidatedColls,
        uint256[] _collGasCompensations,
        uint256 _EUSDGasCompensation
    );

    event Redemption(
        uint256 _attemptedEUSDAmount,
        uint256 _actualEUSDAmount,
        address[] _collaterals,
        uint256[] _collSents,
        uint256[] _collFees
    );
    event TroveUpdated(
        address indexed _borrower,
        uint256 _debt,
        address[] _colls,
        uint256[] _shares,
        DataTypes.TroveManagerOperation _operation
    );
    event TroveLiquidated(
        address indexed _borrower,
        uint256 _debt,
        address[] _collaterals,
        uint256[] _colls,
        DataTypes.TroveManagerOperation _operation
    );
    event BaseRateUpdated(uint256 _baseRate);
    event LastFeeOpTimeUpdated(uint256 _lastFeeOpTime);
    event TotalStakesUpdated(address _collateral, uint256 _newTotalStakes);
    event TotalStakesUpdated(uint256[] _newTotalStakes);
    event SystemSnapshotsUpdated(
        uint256[] _totalStakesSnapshot,
        uint256[] _totalCollateralSnapshot
    );
    event LTermsUpdated(
        address _collateral,
        uint256 _L_Coll,
        uint256 _L_EUSDDebt
    );
    event TroveSnapshotsUpdated(uint256 _unix);
    event TroveIndexUpdated(address _borrower, uint256 _newIndex);
}
