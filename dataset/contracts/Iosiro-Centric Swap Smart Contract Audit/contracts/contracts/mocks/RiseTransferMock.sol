pragma solidity 0.4.25;

import './RiseMock.sol';

contract RiseTransferMock is RiseMock {
    constructor (address _mintSaver, address _cashContract)
    public
    RiseMock(_mintSaver, _cashContract) {}

    function transfer(address to, uint256 value) public returns (bool) {
        return false;
    }
}