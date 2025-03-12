// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/CTokenInterface.sol";

contract MockCToken is CTokenInterface {
    mapping(address => uint) private _balances;
    mapping(address => uint) private _borrowBalances;
    uint private _borrowIndex;
    uint private _totalSupply;
    uint private _totalBorrows;

    function setBalance(address account, uint balance) external {
        _balances[account] = balance;
    }

    function balanceOf(address account) external override view returns (uint) {
        return _balances[account];
    }

    function setBorrowBalance(address account, uint balance) external {
        _borrowBalances[account] = balance;
    }

    function borrowBalanceStored(address account) external override view returns (uint) {
        return _borrowBalances[account];
    }

    function setBorrowIndex(uint value) external {
        _borrowIndex = value;
    }

    function borrowIndex() external override view returns (uint) {
        return _borrowIndex;
    }

    function setTotalSupply(uint value) external {
        _totalSupply = value;
    }

    function totalSupply() external override view returns (uint) {
        return _totalSupply;
    }

    function setTotalBorrows(uint value) external {
        _totalBorrows = value;
    }

    function totalBorrows() external override view returns (uint) {
        return _totalBorrows;
    }
}
