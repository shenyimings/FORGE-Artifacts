// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {MinterEvent} from "../../libs/Events.sol";

interface IBurnHelperFacet {
    /**
     * @notice Attempts to close all debt positions and interest
     * @notice Account must have enough of krAsset balance to burn and ennough KISS to cover interest
     * @param _account The address to close the positions for
     */
    function batchCloseKrAssetDebtPositions(address _account) external;

    /**
     * @notice Burns all Kresko asset debt and repays interest.
     * @notice Account must have enough of krAsset balance to burn and ennough KISS to cover interest
     * @param _account The address to close the position for
     * @param _kreskoAsset The address of the Kresko asset.
     */
    function closeKrAssetDebtPosition(address _account, address _kreskoAsset) external;
}
