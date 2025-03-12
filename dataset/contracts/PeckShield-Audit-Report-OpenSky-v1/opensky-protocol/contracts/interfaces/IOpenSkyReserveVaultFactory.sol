// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOpenSkyReserveVaultFactory {
    function create(
        uint256 reserveId,
        string memory name,
        string memory symbol
    ) external returns (address oTokenAddress);
}
