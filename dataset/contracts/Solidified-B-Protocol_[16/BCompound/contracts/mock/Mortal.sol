pragma solidity 0.5.16;

contract Mortal {
    function () external payable {}

    function kill(address payable receiver) external {
        selfdestruct(receiver);
    }
}