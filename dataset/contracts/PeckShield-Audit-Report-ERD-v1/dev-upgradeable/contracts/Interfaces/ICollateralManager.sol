// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// import {DataTypes} from "../DataTypes.sol";
import "../DataTypes.sol";

interface ICollateralManager {
    function setAddresses(
        address _activePoolAddress,
        address _borrowerOperationsAddress,
        address _defaultPoolAddress,
        address _priceFeedAddress,
        address _troveManagerAddress,
        address _troveManagerRedemptionsAddress,
        address _wethAddress
    ) external;

    function addCollateral(
        address _collateral,
        address _oracle,
        address _eTokenAddress,
        uint256 _ratio
    ) external;

    function removeCollateral(address _collateral) external;

    function setCollateralPriority(
        address _collateral,
        uint256 _newIndex
    ) external;

    function pauseCollateral(address _collateral) external;

    function activeCollateral(address _collateral) external;

    function setOracle(address _collateral, address _oracle) external;

    function setEToken(address _collateral, address _eTokenAddress) external;

    function setRatio(address _collateral, uint256 _ratio) external;

    function priceUpdate() external;

    function getShares(
        address[] memory _collaterals,
        uint256[] memory _amounts
    ) external view returns (uint256[] memory);

    function mintEToken(
        address[] memory _collaterals,
        uint256[] memory _amounts,
        address _account,
        uint256 _price
    ) external returns (uint256[] memory, uint256);

    function applyRewards(
        address _borrower,
        uint256[] memory _pendingRewards
    ) external returns (uint256[] memory);

    function burnEToken(
        address[] memory _collaterals,
        uint256[] memory _amounts,
        address _account,
        uint256 _price
    ) external returns (uint256[] memory, uint256);

    function clearEToken(
        address _account,
        DataTypes.Status closedStatus
    ) external returns (address[] memory);

    function resetEToken(
        address _account,
        address[] memory _collaterals,
        uint256[] memory _amounts
    ) external returns (uint256[] memory);

    function getAmounts(
        address[] memory _collaterals,
        uint256[] memory _shares
    ) external view returns (uint256[] memory);

    function getTroveColls(
        address _borrower
    )
        external
        view
        returns (uint256[] memory, uint256[] memory, address[] memory);

    function getTroveColl(
        address _borrower,
        address _collateral
    ) external view returns (uint256, uint256);

    function getCollateralShares(
        address _borrower
    ) external view returns (address[] memory, uint256[] memory);

    function getEntireCollValue(
        uint256 _price
    ) external view returns (address[] memory, uint256[] memory, uint256);

    function getEntireCollValue()
        external
        view
        returns (address[] memory, uint256[] memory, uint256);

    function validAdjustment(
        address _account,
        address _collateral,
        uint256 _amount
    ) external view returns (bool);

    function adjustColls(
        uint256[] memory _initialAmounts,
        address[] memory _collsIn,
        uint256[] memory _amountsIn,
        address[] memory _collsOut,
        uint256[] memory _amountsOut
    ) external view returns (uint256[] memory newAmounts);

    function getCollateralSupport() external view returns (address[] memory);

    function getIsActive(address _collateral) external view returns (bool);

    function getIsSupport(address _collateral) external view returns (bool);

    function getCollateralOracle(
        address _collateral
    ) external view returns (address);

    function getCollateralOracles() external view returns (address[] memory);

    function getCollateralParams(
        address _collateral
    ) external view returns (DataTypes.CollateralParams memory);

    function getCollateralsAmount() external view returns (uint256);

    function getValue(
        address[] memory _collaterals,
        uint256[] memory _amounts
    ) external view returns (uint256, uint256[] memory);

    function getValue(
        address[] memory _collaterals,
        uint256[] memory _amounts,
        uint256 _price
    ) external view returns (uint256, uint256[] memory);

    function getTotalValue(
        address[] memory _collaterals,
        uint256[] memory _amounts
    ) external view returns (uint256);

    function setMCR(uint256 _mcr) external;

    function setCCR(uint256 _ccr) external;

    function setGasCompensation(uint256 _gas) external;

    function setMinDebt(uint256 _minDebt) external;

    function setBorrowingFeeFloor(uint256 _borrowingFloor) external;

    function setRedemptionFeeFloor(uint256 _redemptionFloor) external;

    function setRecoveryFee(uint256 _redemptionFloor) external;

    function setMaxBorrowingFee(uint256 _maxBorrowingFee) external;

    function setBootstrapPeriod(uint256 _period) external;

    function setFactor(uint256 _factor) external;

    function getFactor() external view returns (uint256);

    function getMCR() external view returns (uint256);

    function getCCR() external view returns (uint256);

    function getEUSDGasCompensation() external view returns (uint256);

    function getMinNetDebt() external view returns (uint256);

    function getMaxBorrowingFee() external view returns (uint256);

    function getBorrowingFeeFloor() external view returns (uint256);

    function getRedemptionFeeFloor() external view returns (uint256);

    function getRecoveryFee() external view returns (uint256);

    function getBootstrapPeriod() external view returns (uint256);

    function getIndex(address _collateral) external view returns (uint256);

    function getRatio(address _collateral) external view returns (uint256);
}
