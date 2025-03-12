// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IUnitroller {
    function pendingAdmin() external view returns (address);

    function _setPendingAdmin(address newPendingAdmin) external returns (uint256);

    function comptrollerImplementation() external view returns (address);

    function _acceptImplementation() external returns (uint256);

    function pendingComptrollerImplementation() external view returns (address);

    function _setPendingImplementation(address newPendingImplementation) external returns (uint256);

    function _acceptAdmin() external returns (uint256);

    function admin() external view returns (address);
}
