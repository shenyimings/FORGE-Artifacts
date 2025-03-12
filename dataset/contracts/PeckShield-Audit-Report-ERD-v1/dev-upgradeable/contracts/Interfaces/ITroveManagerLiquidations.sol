// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./IERDBase.sol";
import "./IStabilityPool.sol";

// Common interface for the Trove Manager.
interface ITroveManagerLiquidations is IERDBase {
    // --- Functions ---

    function setAddresses(
        address _borrowerOperationsAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _priceFeedAddress,
        address _eusdTokenAddress,
        address _sortedTrovesAddress,
        address _troveManagerAddress,
        address _collateralManagerAddress
    ) external;

    function stabilityPool() external view returns (IStabilityPool);

    function getCollateralSupport() external view returns (address[] memory);

    function liquidateTroves(uint256 _n, address _liquidator) external;

    function batchLiquidateTroves(
        address[] calldata _troveArray,
        address _liquidator
    ) external;
}
