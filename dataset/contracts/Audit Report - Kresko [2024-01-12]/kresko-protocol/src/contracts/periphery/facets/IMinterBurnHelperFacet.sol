// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IMinterBurnHelperFacet {
    /**
     * @notice Attempts to close all debt positions and interest
     * @notice Account must have enough of krAsset balance to burn and enough KISS to cover interest
     * @param _account The address to close the positions for
     */
    function closeAllDebtPositions(address _account) external;

    /**
     * @notice Burns all Kresko asset debt and repays interest.
     * @notice Account must have enough of krAsset balance to burn and enough KISS to cover interest
     * @param _account The address to close the position for
     * @param _krAsset The address of the Kresko asset.
     */
    function closeDebtPosition(address _account, address _krAsset) external;
}
