// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IKKUB {
    event Deposit(address sender, uint amount);
    event Withdrawal(address receiver, uint amount);

    function deposit() external payable;

    function withdraw(uint256 _value) external;

    function withdrawAdmin(uint256 _value, address _addr) external;
}
