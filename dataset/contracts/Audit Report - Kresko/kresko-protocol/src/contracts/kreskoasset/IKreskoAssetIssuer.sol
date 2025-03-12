// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

/// @title KreskoAsset issuer interface
/// @author Kresko
/// @notice Contract that can issue/destroy Kresko Assets through Kresko
/// @dev This interface is used by KISS & KreskoAssetAnchor
interface IKreskoAssetIssuer {
    /**
     * @notice Mints @param _assets of krAssets for @param _to,
     * @notice Mints relative @return _shares of wkrAssets
     */
    function issue(uint256 _assets, address _to) external returns (uint256 shares);

    /**
     * @notice Burns @param _assets of krAssets from @param _from,
     * @notice Burns relative @return _shares of wkrAssets
     */
    function destroy(uint256 _assets, address _from) external returns (uint256 shares);

    /**
     * @notice Returns the total amount of anchor tokens out
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @notice Returns the total amount of krAssets out
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
}
