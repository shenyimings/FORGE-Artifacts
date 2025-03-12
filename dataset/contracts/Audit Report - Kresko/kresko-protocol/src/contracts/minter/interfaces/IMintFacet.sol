// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

interface IMintFacet {
    /**
     * @notice Mints new Kresko assets.
     * @param _account The address to mint assets for.
     * @param _kreskoAsset The address of the Kresko asset.
     * @param _mintAmount The amount of the Kresko asset to be minted.
     */
    function mintKreskoAsset(address _account, address _kreskoAsset, uint256 _mintAmount) external;
}
