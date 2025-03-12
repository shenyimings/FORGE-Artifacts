//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IDepositContract {
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawalCredentials,
        bytes calldata signature,
        bytes32 depositDataRoot
    )
        external
        payable;
}
