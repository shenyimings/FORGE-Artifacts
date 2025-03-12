pragma solidity ^0.6.0;

import "./SimpleToken.sol";

contract Foo2 is SimpleToken {
    // Swap half of the incoming ether to token
    function bar() public payable returns (uint256 result) {
        uint256 amount = msg.value / 2;
        _mint(msg.sender, amount);
        msg.sender.transfer(msg.value - amount);
        return amount;
    }
}
