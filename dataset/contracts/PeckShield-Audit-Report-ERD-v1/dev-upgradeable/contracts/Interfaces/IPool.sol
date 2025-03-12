// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// Common interface for the Pools.
interface IPool {
    // --- Events ---
    event BorrowerOperationsAddressChanged(
        address _newBorrowerOperationsAddress
    );
    event TreasuryAddressChanged(address _newTreasuryAddress);
    event LiquidityIncentiveAddressChanged(address _newLiquidityIncentiveAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event CollateralManagerAddressChanged(address _newCollateralManagerAddress);
    event TroveManagerRedemptionsAddressChanged(
        address _newTroveManagerLiquidationsAddress
    );
    event TroveManagerLiquidationsAddressChanged(
        address _newTroveManagerRedemptionsAddress
    );
    event ActivePoolAddressChanged(address _newActivePoolAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event DefaultPoolAddressChanged(address _newDefaultPoolAddress);
    event StabilityPoolAddressChanged(address _newStabilityPoolAddress);
    event EUSDTokenAddressChanged(address _newEUSDTokenAddress);
    event SortedTrovesAddressChanged(address _newSortedTrovesAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event CommunityIssuanceAddressChanged(address _newCommunityIssuanceAddress);
    event WETHAddressChanged(address _wethAddress);

    event CollateralSent(address _to, uint256[] _amount);
    event CollateralSent(address _to, address _collateral, uint256 _amount);

    // --- Functions ---

    function getTotalCollateral()
        external
        view
        returns (
            uint256,
            address[] memory,
            uint256[] memory
        );

    function getCollateralAmount(address _collateral)
        external
        view
        returns (uint256);
}
