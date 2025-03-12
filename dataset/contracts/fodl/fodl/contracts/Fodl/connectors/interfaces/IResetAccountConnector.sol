// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IResetAccountConnector {
    event OwnerChanged(address oldOwner, address newOwner);

    function resetAccount(
        address oldOwner,
        address newOwner,
        uint256 accountId
    ) external;
}
