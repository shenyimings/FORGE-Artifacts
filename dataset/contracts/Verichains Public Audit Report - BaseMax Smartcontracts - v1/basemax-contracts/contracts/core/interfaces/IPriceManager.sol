// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

interface IPriceManager {
    function assets(uint256 _assetId) external view returns (
        string memory symbol,
        bytes32 pythId,
        uint256 price,
        uint256 timestamp,
        uint256 allowedStaleness,
        uint256 allowedDeviation,
        uint256 maxLeverage,
        uint256 tokenDecimals
    );
    function getLastPrice(uint256 _tokenId) external view returns (uint256);
    function getPythLastPrice(uint256 _assetId, bool _requireFreshness) external view returns (uint256);
    function pyth() external view returns (IPyth);

    function maxLeverage(uint256 _tokenId) external view returns (uint256);

    function tokenToUsd(address _token, uint256 _tokenAmount) external view returns (uint256);

    function usdToToken(address _token, uint256 _usdAmount) external view returns (uint256);
    function setPrice(uint256 _assetId, uint256 _price, uint256 _ts) external;
}
