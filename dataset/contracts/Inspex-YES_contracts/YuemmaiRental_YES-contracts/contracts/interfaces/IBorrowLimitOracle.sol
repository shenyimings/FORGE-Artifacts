//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

interface IBorrowLimitOracle {

    event BorrowLimitUpdated(address account, uint256 oldAmount, uint256 newAmount);

    function borrowLimitOf(address account) external view returns(uint);
    function setBorrowLimit(address account, uint256 newAmount) external;

}