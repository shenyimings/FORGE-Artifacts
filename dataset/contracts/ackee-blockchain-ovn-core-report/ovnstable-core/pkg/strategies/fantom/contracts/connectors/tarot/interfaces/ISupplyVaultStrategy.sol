// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./IBorrowable.sol";
import "./ISupplyVault.sol";

interface ISupplyVaultStrategy {
    function getBorrowable(address _address) external view returns (IBorrowable);

    function getSupplyRate() external returns (uint256 supplyRate_);

    function allocate() external;

    function deallocate(uint256 _underlyingAmount) external;

    function reallocate(uint256 _underlyingAmount, bytes calldata _data) external;
}