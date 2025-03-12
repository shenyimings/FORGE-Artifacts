// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEthLeverage {
    function deposit(uint256 assets, address receiver) external payable returns (uint256 shares);

    function withdraw(uint256 assets, address receiver) external returns (uint256 shares);
}

contract ETHLeverageTest {
    address public leverage = 0x5655c442227371267c165101048E4838a762675d;

    function deposit(uint256 amount) public payable {
        IEthLeverage(leverage).deposit{value: msg.value}(amount, msg.sender);
    }
}
