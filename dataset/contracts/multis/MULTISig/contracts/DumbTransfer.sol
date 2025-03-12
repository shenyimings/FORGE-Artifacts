pragma solidity 0.5.13;

contract DumbTransfer {
    function transfer(address payable _to) public payable {
        _to.transfer(msg.value);
    }
}
