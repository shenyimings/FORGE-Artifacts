//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./modules/admin/Authorization.sol";
import "./interfaces/IBorrowLimitOracle.sol";

contract BorrowLimitOracle is IBorrowLimitOracle, Authorization {

    mapping(address => uint) public override borrowLimitOf;

    constructor(address adminRouter_) Authorization(adminRouter_) {}

    function setBorrowLimit(address account, uint256 newAmount)
        external
        override
        onlyAdmin
    {
        uint256 oldAmount = borrowLimitOf[account];
        borrowLimitOf[account] = newAmount;
        emit BorrowLimitUpdated(account, oldAmount, newAmount);
    }
  
}
