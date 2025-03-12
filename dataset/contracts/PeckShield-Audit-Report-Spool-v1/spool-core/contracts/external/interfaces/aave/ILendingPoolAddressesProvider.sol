// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ILendingPool.sol";

interface ILendingPoolAddressesProvider {
    function getLendingPool() external view returns (ILendingPool);
}
