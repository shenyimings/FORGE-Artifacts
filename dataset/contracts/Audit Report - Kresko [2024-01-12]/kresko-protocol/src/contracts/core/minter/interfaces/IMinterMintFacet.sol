// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IMinterMintFacet {
    /**
     * @notice Mints new Kresko assets.
     * @param _account The address to mint assets for.
     * @param _krAsset The address of the Kresko asset.
     * @param _mintAmount The amount of the Kresko asset to be minted.
     */
    function mintKreskoAsset(address _account, address _krAsset, uint256 _mintAmount) external;
}
