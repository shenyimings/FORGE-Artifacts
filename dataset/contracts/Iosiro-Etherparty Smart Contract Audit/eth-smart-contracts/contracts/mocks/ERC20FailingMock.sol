pragma solidity ^0.4.24;

contract ERC20FailingMock {
    function transfer(address, uint256) public pure returns (bool) {
        return false;
    }

    function balanceOf(address) public pure returns (uint) {
        return 0;
    }
}
