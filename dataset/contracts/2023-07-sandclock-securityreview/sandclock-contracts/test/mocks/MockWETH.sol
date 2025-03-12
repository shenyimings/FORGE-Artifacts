// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract MockWETH is MockERC20 {
    constructor() MockERC20("Mock Wrapped Ether", "mWETH", 18) {}

    event Deposit(address indexed from, uint256 amount);

    event Withdrawal(address indexed to, uint256 amount);

    function deposit() public payable {
        _mint(msg.sender, msg.value);

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        require(amount <= address(this).balance, "MockWETH: INSUFFICIENT_ETH_BALANCE");

        _burn(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);

        payable(msg.sender).transfer(amount);
    }

    receive() external payable {
        deposit();
    }
}
