// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./IERDBase.sol";
import "./IStabilityPool.sol";

// Common interface for the Trove Manager.
interface ITroveManagerRedemptions is IERDBase {
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

    function redeemCollateral(
        uint256 _EUSDAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFee,
        address _redeemer
    ) external;

    function updateTroves(
        address[] calldata _borrowers,
        address[] calldata _lowerHints,
        address[] calldata _upperHints
    ) external;
}
