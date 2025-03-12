// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ISDIFacet {
    function getTotalSDIDebt() external view returns (uint256);

    function getEffectiveSDIDebtUSD() external view returns (uint256);

    function getEffectiveSDIDebt() external view returns (uint256);

    function getSDICoverAmount() external view returns (uint256);

    function previewSCDPBurn(
        address _assetAddr,
        uint256 _burnAmount,
        bool _ignoreFactors
    ) external view returns (uint256 shares);

    function previewSCDPMint(
        address _assetAddr,
        uint256 _mintAmount,
        bool _ignoreFactors
    ) external view returns (uint256 shares);

    /// @notice Simply returns the total supply of SDI.
    function totalSDI() external view returns (uint256);

    /// @notice Get the price of SDI in USD, oracle precision.
    function getSDIPrice() external view returns (uint256);

    function SDICover(address _assetAddr, uint256 _amount) external returns (uint256 shares, uint256 value);

    function enableCoverAssetSDI(address _assetAddr) external;

    function disableCoverAssetSDI(address _assetAddr) external;

    function setCoverRecipientSDI(address _coverRecipient) external;

    function getCoverAssetsSDI() external view returns (address[] memory);
}
