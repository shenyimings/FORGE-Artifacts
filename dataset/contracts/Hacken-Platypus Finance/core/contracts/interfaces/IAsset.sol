// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.9;

interface IAsset {
    function maxSupply() external view returns (uint256);

    function pool() external view returns (address);

    function aggregateAccount() external view returns (address);

    function underlyingToken() external view returns (address);

    function decimals() external view returns (uint8);

    function underlyingTokenBalance() external view returns (uint256);

    function cash() external view returns (uint256);

    function liability() external view returns (uint256);
}
