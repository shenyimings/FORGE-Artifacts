// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IFoldingAccountOwnerProvider {
    function accountOwner(address foldingAccount) external view returns (address foldingAccountOwner);
}
