// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../VaultMSData.sol";

interface IVaultStorage {
    function isSwapEnabled() external view returns (bool);
   
    // ---------- owner setting part ----------
    function setVault(address _vault) external;
    function delKey(address _account, bytes32 _key) external;
    function addKey(address _account, bytes32 _key) external;
    function userKeysLength(address _account) external view returns (uint256);
    function getUserKeys(address _account, uint256 _start, uint256 _end) external view returns (bytes32[] memory);
    function getKeys(uint256 _start, uint256 _end) external view returns (bytes32[] memory);
    function totalKeysLength( ) external view returns (uint256);

    //-- trading limit
    function maxGlobalShortSizes(address) external view returns (uint256);
    function maxGlobalLongSizes(address) external view returns (uint256);
    function getTradingLimit(address _token) external view returns (VaultMSData.TradingLimit memory);

}
